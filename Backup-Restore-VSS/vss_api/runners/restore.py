"""Restore-from-snapshot runner — called by the API server as a subprocess.

Usage (called by vss_api/server.py):
    python3 restore.py <snapshot_name> <target_host>
                       [--databases DB1,DB2]
                       [--rename orig1=new1,orig2=new2]
                       [--move-data orig1=E:\\NewData\\,...]
                       [--move-log  orig1=F:\\NewLog\\,...]
                       [--overwrite]
                       [--source SOURCE_HOST]      (for tlog bridging)
                       [--parallel N]
                       [--with-tlog]
                       [--stopat YYYY-MM-DDTHH:MM:SS]

--move-data / --move-log are forwarded to VssRestore.exe and applied via
AddNewTarget so SQL Writer registers the DB at the new paths on PostRestore.
--rename is applied here after the DB is ONLINE via ALTER DATABASE MODIFY
NAME (the requester deliberately does not call SetRestoreName — it caused
PreRestore to lock the MDF path and break the Copy phase).

Side-by-side mode: when a DB has BOTH a rename entry AND a move-data or
move-log entry, the writer flow is bypassed entirely for that DB. VssRestore
is called with --attach-only <db>, which only stages the snapshot files at
the move paths; this script then runs CREATE DATABASE [new_name] ... FOR
ATTACH so the new DB appears next to the still-live original.

Outputs progress lines to stdout; the job manager captures and streams them.
Exit codes:  0=ok  1=usage/snapshot error  2=name conflict (no --overwrite)
             3=VssRestore failed  4=tlog verify failed  5=rename/attach failed
"""
import argparse, os, sys, subprocess, textwrap, time

HERE     = os.path.dirname(os.path.abspath(__file__))
VSS_ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, VSS_ROOT)

from winrm_helper import run_ps, sql_query_mssql, sql_exec_mssql, load_config

_cfg      = load_config()
SHARE_UNC = _cfg.get("SHARE_UNC", r"\\192.168.122.1\vss-transport")
TRANSPORT = _cfg.get("SHARE_LINUX_PATH", "/hyperactive/vss-transport")
REQDIR    = os.path.join(VSS_ROOT, "VssRequester")

ap = argparse.ArgumentParser()
ap.add_argument("snapshot")
ap.add_argument("target")
ap.add_argument("--databases", default=None)
ap.add_argument("--rename",    default=None,
                help="Comma list of orig=new pairs. Unlisted DBs keep original name.")
ap.add_argument("--move-data", default=None, dest="move_data",
                help="Comma list of orig=dir pairs; relocate each DB's data "
                     "files (.mdf/.ndf) to the given directory on target.")
ap.add_argument("--move-log",  default=None, dest="move_log",
                help="Comma list of orig=dir pairs; relocate each DB's log "
                     "file (.ldf) to the given directory on target.")
ap.add_argument("--overwrite", action="store_true",
                help="Drop any existing DB on target that conflicts with the "
                     "original or renamed names before restoring.")
ap.add_argument("--source",    default="AgHost-1A",
                help="Host key of the server that owns the agent-job .trn files "
                     "(passed to verify_tlog_chain.py; default: AgHost-1A).")
ap.add_argument("--parallel",  type=int, default=1)
ap.add_argument("--with-tlog", action="store_true")
ap.add_argument("--stopat",    default=None,
                help="PITR timestamp: YYYY-MM-DDTHH:MM:SS")
args = ap.parse_args()

snap     = args.snapshot
lin_path = os.path.join(TRANSPORT, snap)
out_unc  = rf"{SHARE_UNC}\{snap}"

# Determine databases: explicit list or auto-discover from snapshot folder
if args.databases:
    dbs = [d.strip() for d in args.databases.split(",") if d.strip()]
elif os.path.isdir(lin_path):
    dbs = sorted(d for d in os.listdir(lin_path)
                 if os.path.isdir(os.path.join(lin_path, d)))
else:
    print(f"[restore] ERROR: snapshot folder not found: {lin_path}")
    sys.exit(1)

# Parse rename map ("orig1=new1,orig2=new2"). Entries where new==orig are
# treated as no-op. Renames for DBs not in the selected list are ignored.
rename_map: dict[str, str] = {}
if args.rename:
    for pair in args.rename.split(","):
        pair = pair.strip()
        if not pair: continue
        if "=" not in pair:
            print(f"[restore] ERROR: bad --rename entry: {pair!r} (expected orig=new)")
            sys.exit(1)
        k, v = [s.strip() for s in pair.split("=", 1)]
        if k and v and k != v and k in dbs:
            rename_map[k] = v

# effective_name[orig] → final DB name after rename (same as orig if no rename)
effective = {db: rename_map.get(db, db) for db in dbs}

def _parse_dir_map(arg: str | None) -> dict[str, str]:
    """Parse "Db2=E:\\Data\\,CDCDemo=F:\\Data\\" into {Db2:E:\\Data, CDCDemo:F:\\Data}.
    Trailing slashes are stripped so VssRestore.exe sees a uniform form.
    Entries for DBs not in the selected list are dropped."""
    m: dict[str, str] = {}
    if not arg: return m
    for pair in arg.split(","):
        pair = pair.strip()
        if not pair or "=" not in pair: continue
        k, v = [s.strip() for s in pair.split("=", 1)]
        if not k or not v or k not in dbs: continue
        m[k] = v.rstrip("\\/")
    return m

move_data = _parse_dir_map(args.move_data)
move_log  = _parse_dir_map(args.move_log)

print(f"[restore] snapshot={snap}  target={args.target}  source={args.source}")
print(f"[restore] databases={dbs}  parallel={args.parallel}")
print(f"[restore] with_tlog={args.with_tlog}  stopat={args.stopat}")
print(f"[restore] rename_map={rename_map}  overwrite={args.overwrite}")
print(f"[restore] move_data={move_data}  move_log={move_log}")
print(f"[restore] input UNC: {out_unc}")

# ── Pre-flight: detect name conflicts on target ───────────────────────────────
# For a plain restore, both the ORIGINAL name (VssRestore registers under the
# original name before the rename fallback) and any RENAMED target must be free.
# For a SIDE-BY-SIDE restore — a DB that has BOTH --rename and a file-move — the
# SQL Writer emits the new name at the new physical paths via SetRestoreName +
# AddNewTarget, so the live original DB can stay up; only the NEW name must be
# free. Any DB that has a rename but no move is still a logical-rename-only
# restore and needs its original name cleared.
sidebyside = {db for db in dbs
              if db in rename_map and (db in move_data or db in move_log)}
names_to_clear = sorted({*(d for d in dbs if d not in sidebyside),
                         *effective.values()})
if sidebyside:
    print(f"[restore] side-by-side DBs (originals preserved): {sorted(sidebyside)}")
qlist = ",".join(f"'{d}'" for d in names_to_clear)
rows, err, rc = sql_query_mssql(args.target,
    f"SELECT name FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
if rc != 0:
    print(f"[restore] ERROR: could not read sys.databases on {args.target}: {err[:400]}")
    sys.exit(1)
existing = [r[0] for r in rows if r[0] in names_to_clear]
if existing:
    print(f"[restore] Pre-flight: these names already exist on {args.target}: {existing}")
    if not args.overwrite:
        print(f"[restore] ERROR: name conflict. Re-run with --overwrite to drop them, "
              f"or rename the target databases to avoid collisions.")
        sys.exit(2)
    print(f"[restore] --overwrite set; will drop conflicting DBs.")

# ── Drop DBs that would conflict (originals + rename targets) ─────────────────
# Direct mssql-python call — no PowerShell/Invoke-Sqlcmd hop.
for name in names_to_clear:
    if name not in existing:
        continue                          # nothing to drop
    print(f"[restore] Dropping {name} on {args.target} ...")
    err, rc = sql_exec_mssql(args.target,
        f"IF DB_ID('{name}') IS NOT NULL BEGIN "
        f"  IF (SELECT state_desc FROM sys.databases WHERE name='{name}')=N'ONLINE' "
        f"    ALTER DATABASE [{name}] SET OFFLINE WITH ROLLBACK IMMEDIATE; "
        f"  DROP DATABASE [{name}]; "
        f"END", timeout=180)
    if rc != 0:
        print(f"[restore] ERROR: DROP DATABASE [{name}] failed: {err[:400]}")
        sys.exit(5)

# ── Drop DBs holding same file paths (rename-orphan cleanup) ─────────────────
# A previous rename-restore (T5) may leave a database like DBA_Copy that still
# owns DBA.mdf at the original path.  VssRestore would fail to overwrite it.
# When --overwrite is set, detect any DB whose MDF matches {db}.mdf for any db
# in our restore list, and drop it even if the name doesn't match.
if args.overwrite:
    like_clauses = " OR ".join(
        f"mf.physical_name LIKE N'%\\{db}.mdf'" for db in dbs)
    quoted_dbs   = ",".join(f"N'{d}'" for d in dbs)
    rows_fp, _e_fp, _rc_fp = sql_query_mssql(args.target,
        f"SELECT DISTINCT d.name FROM sys.databases d "
        f"JOIN sys.master_files mf ON d.database_id = mf.database_id "
        f"WHERE ({like_clauses}) AND d.name NOT IN ({quoted_dbs})")
    for fp_row in (rows_fp or []):
        fp_name = fp_row[0]
        print(f"[restore] File-path conflict: dropping [{fp_name}] on {args.target} "
              f"(holds a .mdf used by one of {dbs})")
        err_fp, rc_fp = sql_exec_mssql(args.target,
            f"IF DB_ID(N'{fp_name}') IS NOT NULL BEGIN "
            f"  IF (SELECT state_desc FROM sys.databases WHERE name=N'{fp_name}')=N'ONLINE' "
            f"    ALTER DATABASE [{fp_name}] SET OFFLINE WITH ROLLBACK IMMEDIATE; "
            f"  DROP DATABASE [{fp_name}]; "
            f"END", timeout=180)
        if rc_fp != 0:
            print(f"[restore] WARN: DROP [{fp_name}] failed: {err_fp[:200]}")

# ── VssRestore.exe ────────────────────────────────────────────────────────────
# Build the arg list for VssRestore.exe. Each token is single-quoted for the
# PowerShell -ArgumentList array. Rename / move maps are serialized back into
# their "orig=new" comma form so the requester can parse them identically.
# Side-by-side DBs are passed via --attach-only so the writer flow skips them
# entirely (the live original is preserved); their files are staged at the
# --move-data/--move-log paths and attached by this script afterward, so
# --rename does not need to include them (the attach uses the new name).
rename_for_exe = {o: n for o, n in rename_map.items() if o not in sidebyside}
extra = []
if args.parallel > 1:
    extra += ["'--parallel'", f"'{args.parallel}'"]
if rename_for_exe:
    pairs = ",".join(f"{k}={v}" for k, v in rename_for_exe.items())
    extra += ["'--rename'", f"'{pairs}'"]
if move_data:
    pairs = ",".join(f"{k}={v}" for k, v in move_data.items())
    extra += ["'--move-data'", f"'{pairs}'"]
if move_log:
    pairs = ",".join(f"{k}={v}" for k, v in move_log.items())
    extra += ["'--move-log'", f"'{pairs}'"]
if sidebyside:
    extra += ["'--attach-only'", f"'{','.join(sorted(sidebyside))}'"]
if dbs:
    extra += ["'--databases'", f"'{','.join(dbs)}'"]
extra_s = (", " + ", ".join(extra)) if extra else ""

print(f"[restore] Starting VssRestore.exe ...")
script = textwrap.dedent(f"""
$out = 'C:\\Scripts\\VssRestore_gui_out.txt'
$err = 'C:\\Scripts\\VssRestore_gui_err.txt'
Remove-Item $out,$err -EA SilentlyContinue
$t0 = Get-Date
$p  = Start-Process 'C:\\Scripts\\VssRestore\\VssRestore.exe' `
      -ArgumentList '--input','{out_unc}'{extra_s} `
      -NoNewWindow -Wait -PassThru `
      -RedirectStandardOutput $out -RedirectStandardError $err
$dt = (Get-Date) - $t0
"duration_seconds=$([int]$dt.TotalSeconds)"
"exit_code=$($p.ExitCode)"
'--- STDOUT ---'; Get-Content $out
'--- STDERR ---'; Get-Content $err
""")
t0 = time.time()
out, err, rc = run_ps(args.target, script, timeout=7200)
print(f"[restore] VssRestore wall={time.time()-t0:.1f}s  rc={rc}")
print(out)
if err.strip(): print("WINRM ERR:", err[:400])

# Parse VssRestore.exe exit code out of the wrapper's stdout. The WinRM rc
# reflects whether the PS script ran, not whether VssRestore succeeded.
_vss_ec = None
for _ln in out.splitlines():
    if _ln.startswith("exit_code="):
        try: _vss_ec = int(_ln.split("=",1)[1])
        except ValueError: pass
        break
if rc != 0 or (_vss_ec is not None and _vss_ec != 0):
    print(f"[restore] ERROR: VssRestore.exe failed (winrm_rc={rc} exe_ec={_vss_ec})")
    sys.exit(3)

# ── Post-restore state (check both original and effective names) ──────────────
# SetRestoreName may or may not have been honored by SQL Writer. Inspect what
# actually landed so the subsequent recovery / rename steps key off the real
# on-target names.
probe_names = sorted({*dbs, *effective.values()})
qlist = ",".join(f"'{d}'" for d in probe_names)
rows, _err, _rc = sql_query_mssql(args.target,
    f"SELECT name, state_desc FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
print("[restore] Post-restore DB states:")
for r in rows:
    print(f"  {str(r[0]):<28} {r[1]}")

# Map each selected DB to the actual name it landed under on the target. Prefer
# the effective (renamed) name if it shows up; fall back to the original.
state_tokens = {r[0] for r in rows}
landed: dict[str, str] = {}
for db in dbs:
    eff = effective[db]
    if eff != db and eff in state_tokens:
        landed[db] = eff          # SetRestoreName honored (true side-by-side)
    elif db in state_tokens:
        landed[db] = db           # Arrived under original name
    else:
        landed[db] = db           # Assume original; later steps will surface errors
print(f"[restore] landed names: {landed}")

# ── Side-by-side attach fallback ──────────────────────────────────────────────
# When the original DB is still ONLINE on the target, SQL Writer silently
# skips PostRestore for the renamed component: the requester's Copy phase
# writes the .mdf/.ldf files to the AddNewTarget paths, but no catalog entry
# is created for the new name. Attach those files explicitly so the new DB
# appears side-by-side with the untouched original.
if sidebyside:
    for db in sorted(sidebyside):
        new_name = effective[db]
        if new_name in state_tokens:
            print(f"[restore] {new_name} already registered by SQL Writer; "
                  f"skipping attach fallback.")
            continue
        snap_db_dir = os.path.join(lin_path, db)
        if not os.path.isdir(snap_db_dir):
            print(f"[restore] ERROR: snapshot folder for {db} not found at {snap_db_dir}")
            sys.exit(5)
        data_dir = move_data.get(db)
        log_dir  = move_log.get(db)
        filenames: list[str] = []
        for f in sorted(os.listdir(snap_db_dir)):
            lf = f.lower()
            if lf.endswith((".mdf", ".ndf")):
                tgt_dir = data_dir
            elif lf.endswith(".ldf"):
                tgt_dir = log_dir
            else:
                continue
            if not tgt_dir:
                print(f"[restore] ERROR: no move dir configured for {db}/{f}; "
                      f"cannot attach side-by-side.")
                sys.exit(5)
            filenames.append(tgt_dir.rstrip("\\/") + "\\" + f)
        if not filenames:
            print(f"[restore] ERROR: no data/log files found for {db} in {snap_db_dir}")
            sys.exit(5)
        files_sql = ",\n    ".join(f"(FILENAME = N'{p}')" for p in filenames)
        qry = f"CREATE DATABASE [{new_name}] ON\n    {files_sql}\nFOR ATTACH;"
        print(f"[restore] Attaching side-by-side: [{new_name}]")
        for p in filenames:
            print(f"           FILENAME = {p}")
        e, rc4 = sql_exec_mssql(args.target, qry, timeout=600)
        if rc4 != 0:
            print(f"[restore] ERROR: attach failed for {new_name}: {e[:600]}")
            sys.exit(5)
        landed[db] = new_name
        print(f"[restore] {new_name} attached ONLINE.")

# ── Optional tlog chain verify (with optional PITR stopat) ────────────────────
# verify_tlog_chain.py brings each DB ONLINE (WITH RECOVERY) at the end; it
# operates on whatever name the DB actually arrived under. Skip side-by-side
# DBs — they are already ONLINE via attach and have no RESTORING tail.
if args.with_tlog:
    for db in dbs:
        if db in sidebyside:
            print(f"[restore] skipping t-log verify for side-by-side DB {effective[db]} "
                  f"(attached ONLINE; log chain not applicable).")
            continue
        name = landed[db]
        print(f"[restore] T-log chain verify for {name}"
              + (f"  PITR={args.stopat}" if args.stopat else "") + " ...")
        cmd = ["python3", "-u", os.path.join(REQDIR, "verify_tlog_chain.py"), name,
               "--target", args.target, "--source", args.source]
        if args.stopat:
            cmd += ["--stopat", args.stopat]
        r = subprocess.run(cmd, capture_output=False, text=True)
        if r.returncode != 0:
            print(f"[restore] ERROR: verify_tlog_chain FAILED for {name}")
            sys.exit(4)

# ── Finalize recovery: bring every still-RESTORING DB ONLINE ──────────────────
# VSS PostRestore leaves DBs in RESTORING state. We now finalize:
#   - side-by-side DBs are already ONLINE via attach fallback → skip
#   - with_tlog DBs were finalized inside verify_tlog_chain.py → skip
#   - everything else gets RESTORE DATABASE ... WITH RECOVERY on the landed
#     name (original if SetRestoreName was not honored, else the renamed name).
# This covers plain restore, overwrite, move-data / move-log without tlog,
# and the rename-without-tlog pre-rename recovery step.
if not args.with_tlog:
    # Re-query live states so we don't issue RECOVERY against an already-ONLINE DB
    probe2 = sorted({landed[d] for d in dbs if d not in sidebyside})
    if probe2:
        qlist3 = ",".join(f"'{d}'" for d in probe2)
        rows3, _e3, _rc3 = sql_query_mssql(args.target,
            f"SELECT name, state_desc FROM sys.databases WHERE name IN ({qlist3})")
        live = {r[0]: r[1] for r in rows3}
        for name in probe2:
            if live.get(name) != "RESTORING":
                continue
            print(f"[restore] RESTORE DATABASE [{name}] WITH RECOVERY ...")
            e, rc2 = sql_exec_mssql(args.target,
                f"RESTORE DATABASE [{name}] WITH RECOVERY;", timeout=1800)
            if rc2 != 0:
                print(f"[restore] ERROR: could not recover {name}: {e[:400]}")
                sys.exit(5)

# ── Rename fallback (ALTER DATABASE ... MODIFY NAME) ─────────────────────────
# Only needed when SetRestoreName was not honored (landed==orig != effective).
if rename_map:
    pending = {o: n for o, n in rename_map.items() if landed[o] != n}
    if pending:
        print(f"[restore] Renaming (fallback) on {args.target}: {pending}")
        for orig, new in pending.items():
            print(f"[restore] ALTER DATABASE [{orig}] MODIFY NAME = [{new}]")
            e, rc3 = sql_exec_mssql(args.target,
                f"ALTER DATABASE [{orig}] MODIFY NAME = [{new}];", timeout=60)
            if rc3 != 0:
                print(f"[restore] ERROR: rename {orig} -> {new} failed: {e[:400]}")
                sys.exit(5)
    else:
        print(f"[restore] SetRestoreName already applied on-target; no ALTER needed.")
    # Show the final state using the effective names.
    qlist2 = ",".join(f"'{d}'" for d in effective.values())
    rows, _err, _rc = sql_query_mssql(args.target,
        f"SELECT name, state_desc FROM sys.databases WHERE name IN ({qlist2}) ORDER BY name")
    print("[restore] Final DB states after rename:")
    for r in rows:
        print(f"  {str(r[0]):<28} {r[1]}")

print("[restore] Complete.")
