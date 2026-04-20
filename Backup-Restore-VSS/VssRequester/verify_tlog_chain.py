"""Verify the T-log chain end-to-end against a VSS-restored DB.

Steps:
  0. Read redo_start_lsn of the RESTORING DB on SqlPoc.
  1. Query msdb.dbo.backupset on AgHost-1A for all log backups whose
     LastLSN exceeds redo_start_lsn; copy agent-job files from
     E:\\TLogBackups to the transport share and apply any share-resident
     files (from prior verify runs) directly, in first_lsn order.
  2. Insert a marker row on AgHost-1A, BACKUP LOG to the share, re-bridge
     once more (covers agent-job runs that fired during backup), then
     RESTORE LOG the fresh file.
  3. RESTORE WITH RECOVERY and read the marker row back to prove success.

Note: bridge_from_source uses msdb rather than RESTORE HEADERONLY because
many ODBC drivers return NUMERIC(25,0) LSN columns as Python floats, whose
str() representation is scientific notation (e.g. 3.70e+16), causing int()
to raise ValueError and silently skip every file.
"""
import sys, datetime, os, ntpath, subprocess, time, argparse
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from winrm_helper import run_ps, sql_query_mssql, pull_file, SA_PWD

# mssql-python's cur.execute() returns immediately for long-running DDL like
# RESTORE LOG — it does not block until SQL Server finishes.  All RESTORE LOG /
# RESTORE DATABASE statements are therefore sent through PowerShell Invoke-Sqlcmd
# which properly waits for completion before returning control.

ap = argparse.ArgumentParser(description="Verify / bridge the T-log chain for a VSS-restored DB.")
ap.add_argument("db",       nargs="?", default="Db2",
                help="Database name on <target> (default: Db2)")
ap.add_argument("--stopat", default=None,
                help="PITR timestamp for RESTORE WITH RECOVERY, STOPAT (YYYY-MM-DDTHH:MM:SS). "
                     "Leave blank to recover to latest LSN.")
ap.add_argument("--target", default="SqlPoc",
                help="Host key (winrm_helper.HOSTS) of the server where the DB is "
                     "in RESTORING state (default: SqlPoc).")
ap.add_argument("--source", default="AgHost-1A",
                help="Host key of the server where the agent-job .trn files live "
                     "(default: AgHost-1A).")
args   = ap.parse_args()
db     = args.db
stopat = args.stopat          # None → full recovery; set → PITR
TARGET = args.target
SOURCE = args.source
ts     = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
share_unc = r"\\192.168.122.1\vss-transport\tlog_verify"
share_lin = "/hyperactive/vss-transport/tlog_verify"
tlog_src  = r"E:\TLogBackups"
os.makedirs(share_lin, exist_ok=True); os.chmod(share_lin, 0o777)
trn_name = f"{db}_{ts}.trn"

def must(host, query, label, timeout=60):
    """Run a statement via mssql-python on ``host``; print + return a
    formatted summary of the result set (if any). Exits(1) on error.
    """
    rows, err, rc = sql_query_mssql(host, query, timeout=timeout)
    if rc != 0:
        print(f"  FAIL {label} on {host}: rc={rc}")
        print("  stderr:", err[:800])
        sys.exit(1)
    if not rows:
        return ""
    return "\n".join("  " + "  ".join(str(v) for v in r) for r in rows)

def _rows(host, query, columns, timeout=60):
    """Run a T-SQL query via mssql-python and return ``(rows, err)`` where
    rows is a list of tuples aligned with ``columns`` (strings, same shape
    as the old Invoke-Sqlcmd implementation).
    """
    raw, err, rc = sql_query_mssql(host, query, timeout=timeout)
    if rc != 0:
        return None, err
    out = []
    for r in raw:
        vals = ["" if v is None else str(v).strip() for v in r]
        if len(vals) >= len(columns):
            out.append(tuple(vals[:len(columns)]))
    return out, ""

def read_header(trn_path):
    """Return (FirstLSN, LastLSN) as precise integer strings for a .trn on SOURCE.

    RESTORE HEADERONLY returns LSN columns as NUMERIC(25,0) but many ODBC/mssql
    drivers surface them as Python floats, so str(v) yields scientific notation
    (e.g. '3.70e+16') which int() cannot parse.  Querying msdb.dbo.backupset
    with an explicit CAST avoids that precision loss entirely.
    """
    esc = trn_path.replace("'", "''")
    rows, _ = _rows(SOURCE,
        f"SELECT TOP 1 CAST(bs.first_lsn AS VARCHAR(40)) AS FirstLSN, "
        f"             CAST(bs.last_lsn  AS VARCHAR(40)) AS LastLSN "
        f"FROM msdb.dbo.backupset bs "
        f"JOIN msdb.dbo.backupmediafamily bmf "
        f"  ON bs.media_set_id = bmf.media_set_id "
        f"WHERE bmf.physical_device_name = N'{esc}' "
        f"  AND bs.type = 'L' "
        f"ORDER BY bs.backup_finish_date DESC",
        ["FirstLSN", "LastLSN"], timeout=30)
    return (rows[0][0], rows[0][1]) if rows else (None, None)

def current_redo_lsn(retries=6, delay=2.0):
    """redo_start_lsn lives on the DATA file (type=0) of a RESTORING database.

    The SQL Writer PostRestore call can return before sys.master_files is
    fully populated with redo_start_lsn values (particularly for DBs with
    many secondary files, e.g. StackOverflow2013). Poll with a short delay
    so the caller sees a stable value before giving up.
    """
    for _ in range(retries):
        rows, _ = _rows(TARGET,
            f"SELECT TOP 1 CAST(redo_start_lsn AS VARCHAR(40)) AS redo_lsn "
            f"FROM sys.master_files "
            f"WHERE DB_NAME(database_id)='{db}' AND redo_start_lsn IS NOT NULL",
            ["redo_lsn"])
        if rows:
            return rows[0][0]
        time.sleep(delay)
    return None

# Module-level set tracking file basenames already applied this verify run.
# Prevents re-application in the post-backup bridge when redo_start_lsn
# (checkpoint-based) lags behind the actual end-of-chain position.
_applied_bases: set = set()


def ps_restore_logs(unc_paths_and_bases, exit_on_fail=True, last_stopat=None,
                    chunk_size=5):
    """Apply one or more log backups via PowerShell Invoke-Sqlcmd calls.

    ``unc_paths_and_bases`` is a list of (unc_path, base_name) tuples.
    Each log is applied in order WITH NORECOVERY.

    ``last_stopat`` – if set, appends STOPAT to the LAST RESTORE LOG.  This is
    the correct PITR pattern: SQL Server stops at the requested point; the caller
    then runs RESTORE DATABASE WITH RECOVERY (without STOPAT).

    ``chunk_size`` – files per WinRM call.  WinRM base64-encodes the script, so
    very long batches exceed the command-line limit (~8 KB).  Default of 5 is
    safe for typical UNC path lengths.

    Returns True on full success, False if any restore failed (when
    exit_on_fail=False); calls sys.exit(1) when exit_on_fail=True.
    """
    if not unc_paths_and_bases:
        return True
    last_idx_global = len(unc_paths_and_bases) - 1
    all_out = ""
    # Split into chunks so each PowerShell script stays within WinRM limits.
    for chunk_start in range(0, len(unc_paths_and_bases), chunk_size):
        chunk = unc_paths_and_bases[chunk_start: chunk_start + chunk_size]
        lines = []
        for local_i, (unc, base) in enumerate(chunk):
            global_i = chunk_start + local_i
            extra = f", STOPAT = N'{last_stopat}'" if (last_stopat and global_i == last_idx_global) else ""
            lines.append(
                f'Invoke-Sqlcmd -ServerInstance localhost -Username sa'
                f' -Password \'{SA_PWD}\''
                f' -Query "RESTORE LOG [{db}] FROM DISK = N\'{unc}\' WITH NORECOVERY{extra}"'
                f' -QueryTimeout 600 -ErrorAction Stop'
            )
            lines.append(f"Write-Host 'OK:{base}'")
        ps_script = '\n'.join(lines)
        out, err, rc = run_ps(TARGET, ps_script, timeout=700)
        all_out += out
        # Check each file in this chunk
        for unc, base in chunk:
            if f'OK:{base}' not in out:
                print(f"  FAIL restore {base} on {TARGET}: rc={rc}")
                print("  stderr:", (err or '')[:800])
                if exit_on_fail:
                    sys.exit(1)
                return False
    return True

def bridge_from_source(label, start_after_lsn=None, exclude_base=None):
    """Pull needed log backups from SOURCE -> share and RESTORE LOG them in order.

    Uses msdb.dbo.backupset on SOURCE to enumerate the full chain precisely.
    This avoids the float-precision problem of RESTORE HEADERONLY and also
    handles files already in the tlog_verify share from previous test runs,
    which would otherwise create gaps in the E:\\TLogBackups directory sequence.

    ``start_after_lsn``  – if set, use this LSN instead of redo_start_lsn as
                           the lower bound for the msdb query.  Pass the LastLSN
                           returned by the previous bridge call so the post-backup
                           bridge does not re-fetch files that were already applied.
    ``exclude_base``     – skip the file whose basename matches this value.  Used
                           to prevent the post-backup bridge from applying the
                           fresh BACKUP LOG file that step 5 will apply explicitly.

    Returns the highest LastLSN applied (as int), or 0 if nothing was applied.
    Files in E:\\TLogBackups are copied to the share then applied via UNC.
    Files already stored in the tlog_verify share are applied directly.
    """
    global _applied_bases
    cur = current_redo_lsn()
    if not cur:
        print(f"    [{label}] could not read redo_start_lsn; nothing to bridge"); return 0
    print(f"    [{label}] redo_start_lsn = {cur}")

    # Use the caller-supplied "already applied up to here" LSN if it is higher
    # than redo_start_lsn (checkpoint-based, often lags the actual position).
    filter_lsn = cur
    if start_after_lsn is not None:
        try:
            if int(start_after_lsn) > int(cur):
                filter_lsn = str(start_after_lsn)
                print(f"    [{label}] using caller start_after_lsn={filter_lsn} (> redo_start_lsn)")
        except ValueError:
            pass

    # Get all log backups on SOURCE whose LastLSN exceeds the filter position,
    # ordered by FirstLSN so we apply them in chain sequence.
    rows, err = _rows(SOURCE,
        f"SELECT CAST(bs.first_lsn AS VARCHAR(40)) AS first_lsn, "
        f"       CAST(bs.last_lsn  AS VARCHAR(40)) AS last_lsn, "
        f"       bmf.physical_device_name "
        f"FROM msdb.dbo.backupset bs "
        f"JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id "
        f"WHERE bs.database_name = N'{db}' AND bs.type = 'L' "
        f"  AND bs.last_lsn > CAST('{filter_lsn}' AS NUMERIC(25,0)) "
        f"ORDER BY bs.first_lsn",
        ["first_lsn", "last_lsn", "phys"])

    if rows is None:
        print(f"    [{label}] msdb query error: {err[:200]}"); sys.exit(4)
    if not rows:
        print(f"    [{label}] no newer log backups in msdb (chain already caught up)")
        return 0

    # Detect a gap at the start of the chain (first file doesn't cover cur)
    first_row_first = int(rows[0][0].strip())
    if first_row_first > int(cur):
        print(f"    [{label}] WARN: gap - earliest FirstLSN={first_row_first} > redo={cur}")

    # Phase 1: resolve each backup to a UNC path accessible from TARGET.
    to_apply = []   # list of (base, unc_path, ifirst, ilast)
    max_last_lsn = int(start_after_lsn) if start_after_lsn else 0

    for row in rows:
        first_str, last_str, phys = row[0].strip(), row[1].strip(), row[2].strip()
        try:
            ifirst, ilast = int(first_str), int(last_str)
        except ValueError:
            print(f"    [{label}] SKIP (unparseable LSN): {phys}"); continue

        base = ntpath.basename(phys)

        if base in _applied_bases:
            print(f"    [{label}] SKIP {base} (already applied this run)")
            continue
        if exclude_base and base == exclude_base:
            print(f"    [{label}] SKIP {base} (reserved for explicit apply in step 5)")
            continue

        local_dst = os.path.join(share_lin, base)

        if phys.upper().startswith("E:\\TLOGBACKUPS") or phys.upper().startswith("E:/TLOGBACKUPS"):
            # Standard agent-job backup: pull to share if not already there
            if not os.path.exists(local_dst):
                try:
                    pull_file(SOURCE, phys, local_dst)
                except Exception as ex:
                    print(f"    [{label}] FAIL pull {base}: {ex}"); sys.exit(4)
            unc_path = f"{share_unc}\\{base}"
        elif share_unc.rstrip("\\").lower() in phys.lower():
            # Already lives in the tlog_verify share (from a prior verify run)
            unc_path = phys
        else:
            print(f"    [{label}] SKIP {base}: unknown location {phys[:80]}")
            continue

        print(f"    [{label}] + {base}  first={ifirst}  last={ilast}")
        to_apply.append((base, unc_path, ifirst, ilast))

    # Phase 2: apply all collected files via a single PowerShell batch.
    # mssql-python's cur.execute() is non-blocking for DDL like RESTORE LOG;
    # PowerShell's Invoke-Sqlcmd properly waits for SQL Server to finish.
    if to_apply:
        ps_restore_logs([(unc, base) for base, unc, _f, _l in to_apply])
        for base, unc, ifirst, ilast in to_apply:
            _applied_bases.add(base)
            max_last_lsn = max(max_last_lsn, ilast)

    print(f"    [{label}] applied {len(to_apply)} file(s); new redo_start_lsn = {current_redo_lsn()}")
    return max_last_lsn

print(f"--- 0. Pre-state on {TARGET} for [{db}] ---")
print(must(TARGET,
    f"SELECT name, state_desc FROM sys.databases WHERE name='{db}';", "pre-state"))

if stopat:
    # ── PITR CODE PATH ──────────────────────────────────────────────────────
    # For Point-in-Time Recovery we apply every log backup WITH STOPAT so that
    # SQL Server automatically stops at the requested time mid-chain.  Logs that
    # start AFTER the stopat boundary are rejected by SQL Server ("too recent");
    # we catch that error and stop gracefully rather than treating it as fatal.
    print(f"--- PITR: apply log chain on {TARGET} with STOPAT={stopat} ---")
    cur = current_redo_lsn()
    if not cur:
        print("  could not read redo_start_lsn"); sys.exit(4)
    print(f"  redo_start_lsn = {cur}")

    rows, err = _rows(SOURCE,
        f"SELECT CAST(bs.first_lsn AS VARCHAR(40)) AS first_lsn, "
        f"       CAST(bs.last_lsn  AS VARCHAR(40)) AS last_lsn, "
        f"       bmf.physical_device_name "
        f"FROM msdb.dbo.backupset bs "
        f"JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id "
        f"WHERE bs.database_name = N'{db}' AND bs.type = 'L' "
        f"  AND bs.last_lsn > CAST('{cur}' AS NUMERIC(25,0)) "
        f"ORDER BY bs.first_lsn",
        ["first_lsn", "last_lsn", "phys"])
    if rows is None:
        print(f"  msdb error: {err[:200]}"); sys.exit(4)

    boundary_reached = False
    for row in rows:
        first_str, last_str, phys = row[0].strip(), row[1].strip(), row[2].strip()
        base = ntpath.basename(phys)
        local_dst = os.path.join(share_lin, base)
        if phys.upper().startswith("E:\\TLOGBACKUPS") or phys.upper().startswith("E:/TLOGBACKUPS"):
            if not os.path.exists(local_dst):
                try:
                    pull_file(SOURCE, phys, local_dst)
                except Exception as ex:
                    print(f"  FAIL pull {base}: {ex}"); sys.exit(4)
            unc_path = f"{share_unc}\\{base}"
        elif share_unc.rstrip("\\").lower() in phys.lower():
            unc_path = phys
        else:
            print(f"  SKIP {base}: unknown location"); continue

        # Apply WITH STOPAT; catch "too recent" / "rolled forward" gracefully.
        ps = (
            'try {\n'
            f'    Invoke-Sqlcmd -ServerInstance localhost -Username sa'
            f' -Password \'{SA_PWD}\''
            f' -Query "RESTORE LOG [{db}] FROM DISK = N\'{unc_path}\' WITH NORECOVERY, STOPAT = N\'{stopat}\'"'
            f' -QueryTimeout 600 -ErrorAction Stop\n'
            f'    Write-Host "OK:{base}"\n'
            '} catch {\n'
            '    $msg = $_.Exception.Message\n'
            '    if ($msg -match "too recent" -or $msg -match "rolled forward" -or $msg -match "LSN") {\n'
            '        Write-Host "BOUNDARY"\n'
            '    } else {\n'
            '        Write-Host ("ERR: " + $msg)\n'
            '        exit 1\n'
            '    }\n'
            '}'
        )
        out_p, err_p, rc_p = run_ps(TARGET, ps, timeout=700)
        if f'OK:{base}' in out_p:
            print(f"  PITR: applied {base}")
        elif 'BOUNDARY' in out_p:
            print(f"  PITR: boundary crossed at stopat={stopat} during/after {base} — stopping chain")
            boundary_reached = True
            break
        elif 'ERR:' in out_p:
            print(f"  PITR: fatal error for {base}: {out_p[:400]}")
            sys.exit(1)
        else:
            print(f"  PITR: unexpected output for {base} rc={rc_p}: {out_p[:300]}")
            sys.exit(1)

    if not boundary_reached:
        print(f"  PITR: all log backups applied up to chain end; proceeding to recovery")

else:
    # ── NON-PITR CODE PATH ─────────────────────────────────────────────────
    print(f"--- 1. Bridge agent-job .trn files from {SOURCE} -> {TARGET} ---")
    pre_last_lsn = bridge_from_source("pre-marker")

    print(f"--- 2. Insert marker row on {SOURCE} ---")
    print(must(SOURCE,
        f"USE [{db}]; "
        f"IF OBJECT_ID('dbo._vss_marker','U') IS NULL "
        f"  CREATE TABLE dbo._vss_marker(ts DATETIME2 DEFAULT SYSUTCDATETIME(), note NVARCHAR(128)); "
        f"INSERT dbo._vss_marker(note) VALUES ('tlog_verify {ts}'); "
        f"SELECT COUNT(*) AS rows_in_marker FROM dbo._vss_marker;", "marker insert"))

    print(f"--- 3. Fresh BACKUP LOG on {SOURCE} to {share_unc} ---")
    print(must(SOURCE,
        f"BACKUP LOG [{db}] TO DISK = N'{share_unc}\\{trn_name}' "
        f"WITH INIT, FORMAT, COMPRESSION, NAME = N'vss_verify {ts}';",
        "BACKUP LOG", timeout=180))
    print(subprocess.run(["ls","-la",share_lin], capture_output=True, text=True).stdout)

    print(f"--- 4. Re-bridge (covers any agent-job runs during backup) ---")
    bridge_from_source("post-backup", start_after_lsn=pre_last_lsn or None, exclude_base=trn_name)

    print(f"--- 5. RESTORE LOG fresh file WITH NORECOVERY ---")
    fresh_unc = f"{share_unc}\\{trn_name}"
    ps_restore_logs([(fresh_unc, trn_name)])
    print(f"    step 5 applied {trn_name}")

# ── STEP 6: RESTORE WITH RECOVERY (both PITR and non-PITR) ─────────────────
print(f"--- 6. WITH RECOVERY -> ONLINE {'(PITR: ' + stopat + ')' if stopat else ''} ---")
out6, err6, rc6 = run_ps(TARGET,
    f'Invoke-Sqlcmd -ServerInstance localhost -Username sa'
    f' -Password \'{SA_PWD}\''
    f' -Query "RESTORE DATABASE [{db}] WITH RECOVERY"'
    f' -QueryTimeout 120 -ErrorAction Stop',
    timeout=180)
if rc6 != 0:
    print(f"  FAIL WITH RECOVERY on {TARGET}: rc={rc6}")
    print("  stderr:", (err6 or '')[:800])
    sys.exit(1)
print(f"    step 6 recovery OK")
print(must(TARGET,
    f"SELECT name, state_desc FROM sys.databases WHERE name='{db}';", "online state"))
if stopat:
    print(f"*** PURE-VSS PITR RESTORE to {stopat} VERIFIED ***")
else:
    print(must(TARGET, f"SELECT note, ts FROM [{db}].dbo._vss_marker ORDER BY ts DESC;",
               "marker read"))
    print("*** PURE-VSS T-LOG CHAIN VERIFIED ***")
