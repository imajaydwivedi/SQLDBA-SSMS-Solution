"""Verify the T-log chain end-to-end against a VSS-restored DB.

Steps:
  0. Read redo_start_lsn of the RESTORING DB on SqlPoc.
  1. Enumerate E:\\TLogBackups\\{db}_*.trn on AgHost-1A and inspect
     RESTORE HEADERONLY to obtain FirstLSN/LastLSN for each file.
  2. Copy any files whose LastLSN > redo_start_lsn to the transport share
     and RESTORE LOG them WITH NORECOVERY so the DB catches up with the
     agent-job-driven 15-min log chain.
  3. Insert a marker row on AgHost-1A, BACKUP LOG to the share, re-bridge
     once more (covers agent-job runs that fired during backup), then
     RESTORE LOG the fresh file.
  4. RESTORE WITH RECOVERY and read the marker row back to prove success.
"""
import sys, datetime, os, ntpath, subprocess, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from winrm_helper import run_ps, sqlcmd, pull_file, SA_PWD

db = sys.argv[1] if len(sys.argv) > 1 else "Db2"
ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
share_unc = r"\\192.168.122.1\vss-transport\tlog_verify"
share_lin = "/hyperactive/vss-transport/tlog_verify"
tlog_src  = r"E:\TLogBackups"
os.makedirs(share_lin, exist_ok=True); os.chmod(share_lin, 0o777)
trn_name = f"{db}_{ts}.trn"

def must(host, query, label, timeout=60):
    out, err, rc = sqlcmd(host, query, timeout=timeout)
    if rc != 0:
        print(f"  FAIL {label} on {host}: rc={rc}")
        print("  stderr:", err[:800])
        sys.exit(1)
    return out

def _rows(host, query, columns, timeout=60):
    """Run a T-SQL query via Invoke-Sqlcmd and return a list of tuples for
    ``columns``. Uses ForEach-Object to emit one delimiter-joined scalar per
    row (instead of parsing Format-Table output, which is whitespace-brittle).
    """
    sep = "|~|"
    join_expr = (" + '" + sep + "' + ").join(
        [f"[string]$_.{c}" for c in columns])
    ps = (
        f"$r = Invoke-Sqlcmd -ServerInstance '.' -Username 'sa' -Password '{SA_PWD}' "
        f"-Database 'master' "
        f"-Query @'\nSET NOCOUNT ON;\n{query}\n'@ -QueryTimeout {timeout} -ErrorAction Stop; "
        f"if ($r) {{ $r | ForEach-Object {{ {join_expr} }} | Out-String }}"
    )
    out, err, rc = run_ps(host, ps, timeout=max(timeout, 30))
    if rc != 0:
        return None, err
    rows = []
    for line in out.splitlines():
        line = line.strip()
        if not line: continue
        parts = line.split(sep)
        if len(parts) == len(columns):
            rows.append(tuple(p.strip() for p in parts))
    return rows, ""

def read_header(trn_path):
    """Return (FirstLSN, LastLSN) strings for a .trn file on AgHost-1A."""
    esc = trn_path.replace("'", "''")
    rows, _ = _rows("AgHost-1A",
        f"RESTORE HEADERONLY FROM DISK = N'{esc}'",
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
        rows, _ = _rows("SqlPoc",
            f"SELECT TOP 1 CAST(redo_start_lsn AS VARCHAR(40)) AS redo_lsn "
            f"FROM sys.master_files "
            f"WHERE DB_NAME(database_id)='{db}' AND redo_start_lsn IS NOT NULL",
            ["redo_lsn"])
        if rows:
            return rows[0][0]
        time.sleep(delay)
    return None

def bridge_from_source(label):
    """Pull any .trn files from AgHost-1A whose LastLSN exceeds the DB's
    current redo_start_lsn and RESTORE LOG them on SqlPoc in order.
    Returns list of applied file names.
    """
    cur = current_redo_lsn()
    if not cur:
        print(f"    [{label}] could not read redo_start_lsn; nothing to bridge"); return []
    print(f"    [{label}] redo_start_lsn = {cur}")
    out, _, _ = run_ps("AgHost-1A",
        f"Get-ChildItem '{tlog_src}' -Filter '{db}_*.trn' -EA SilentlyContinue "
        f"| Sort Name | Select -ExpandProperty FullName")
    files = [l.strip() for l in out.splitlines() if l.strip().lower().endswith(".trn")]
    pending = []
    for f in files:
        first, last = read_header(f)
        if not (first and last): continue
        try:
            ifirst, ilast = int(first), int(last)
        except ValueError:
            continue
        if ilast > int(cur):
            pending.append((ifirst, ilast, f))
    pending.sort()
    if not pending:
        print(f"    [{label}] no newer .trn files in {tlog_src} (chain already caught up)")
        return []
    if pending[0][0] > int(cur):
        print(f"    [{label}] WARN: gap - earliest FirstLSN={pending[0][0]} > redo={cur}")
    applied = []
    for first, last, f in pending:
        base = ntpath.basename(f)
        local_dst = os.path.join(share_lin, base)
        try:
            pull_file("AgHost-1A", f, local_dst)
        except Exception as ex:
            print(f"    [{label}] FAIL pull {base}: {ex}"); sys.exit(4)
        print(f"    [{label}] + {base}  first={first}  last={last}")
        must("SqlPoc",
            f"RESTORE LOG [{db}] FROM DISK = N'{share_unc}\\{base}' WITH NORECOVERY;",
            f"restore {base}", timeout=600)
        applied.append(base)
    print(f"    [{label}] applied {len(applied)} bridge file(s); new redo_start_lsn = {current_redo_lsn()}")
    return applied

print(f"--- 0. Pre-state on SqlPoc for [{db}] ---")
print(must("SqlPoc",
    f"SELECT name, state_desc FROM sys.databases WHERE name='{db}';", "pre-state"))

print(f"--- 1. Bridge agent-job .trn files from AgHost-1A -> SqlPoc ---")
bridge_from_source("pre-marker")

print(f"--- 2. Insert marker row on AgHost-1A ---")
print(must("AgHost-1A",
    f"USE [{db}]; "
    f"IF OBJECT_ID('dbo._vss_marker','U') IS NULL "
    f"  CREATE TABLE dbo._vss_marker(ts DATETIME2 DEFAULT SYSUTCDATETIME(), note NVARCHAR(128)); "
    f"INSERT dbo._vss_marker(note) VALUES ('tlog_verify {ts}'); "
    f"SELECT COUNT(*) AS rows_in_marker FROM dbo._vss_marker;", "marker insert"))

print(f"--- 3. Fresh BACKUP LOG on AgHost-1A to {share_unc} ---")
print(must("AgHost-1A",
    f"BACKUP LOG [{db}] TO DISK = N'{share_unc}\\{trn_name}' "
    f"WITH INIT, FORMAT, COMPRESSION, NAME = N'vss_verify {ts}';",
    "BACKUP LOG", timeout=180))
print(subprocess.run(["ls","-la",share_lin], capture_output=True, text=True).stdout)

print(f"--- 4. Re-bridge (covers any agent-job runs during backup) ---")
bridge_from_source("post-backup")

print(f"--- 5. RESTORE LOG fresh file WITH NORECOVERY ---")
print(must("SqlPoc",
    f"RESTORE LOG [{db}] FROM DISK = N'{share_unc}\\{trn_name}' "
    f"WITH NORECOVERY, STATS = 10;",
    "final RESTORE LOG NORECOVERY", timeout=180))

print(f"--- 6. WITH RECOVERY -> ONLINE, then read marker row ---")
print(must("SqlPoc", f"RESTORE DATABASE [{db}] WITH RECOVERY;", "WITH RECOVERY", timeout=60))
print(must("SqlPoc",
    f"SELECT name, state_desc FROM sys.databases WHERE name='{db}';", "online state"))
print(must("SqlPoc", f"SELECT note, ts FROM [{db}].dbo._vss_marker ORDER BY ts DESC;",
    "marker read"))
print("*** PURE-VSS T-LOG CHAIN VERIFIED ***")
