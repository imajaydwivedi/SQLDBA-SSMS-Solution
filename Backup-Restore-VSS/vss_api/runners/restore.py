"""Restore-from-snapshot runner — called by the API server as a subprocess.

Usage (called by vss_api/server.py):
    python3 restore.py <snapshot_name> <target_host>
                       [--databases DB1,DB2]
                       [--rename orig1=new1,orig2=new2]
                       [--overwrite]
                       [--source SOURCE_HOST]      (for tlog bridging)
                       [--parallel N]
                       [--with-tlog]
                       [--stopat YYYY-MM-DDTHH:MM:SS]

Outputs progress lines to stdout; the job manager captures and streams them.
Exit codes:  0=ok  1=usage/snapshot error  2=name conflict (no --overwrite)
             3=VssRestore failed  4=tlog verify failed  5=rename failed
"""
import argparse, os, sys, subprocess, textwrap, time

HERE     = os.path.dirname(os.path.abspath(__file__))
VSS_ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, VSS_ROOT)

from winrm_helper import run_ps, sqlcmd, load_config

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

print(f"[restore] snapshot={snap}  target={args.target}  source={args.source}")
print(f"[restore] databases={dbs}  parallel={args.parallel}")
print(f"[restore] with_tlog={args.with_tlog}  stopat={args.stopat}")
print(f"[restore] rename_map={rename_map}  overwrite={args.overwrite}")
print(f"[restore] input UNC: {out_unc}")

# ── Pre-flight: detect name conflicts on target ───────────────────────────────
# We need every ORIGINAL name (VssRestore registers by original name) AND every
# RENAMED target name to be absent before we begin; if any already exist, require
# --overwrite to drop them.
names_to_clear = sorted({*dbs, *effective.values()})
qlist = ",".join(f"'{d}'" for d in names_to_clear)
out, err, rc = sqlcmd(args.target,
    f"SELECT name FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
existing = [l.strip() for l in out.splitlines()
            if l.strip() and l.strip() not in ("name", "----")
            and not set(l.strip()) <= {"-"}]
# Best-effort filter of Format-Table artefacts (dashes/headers already excluded above).
existing = [n for n in existing if n in names_to_clear]
if existing:
    print(f"[restore] Pre-flight: these names already exist on {args.target}: {existing}")
    if not args.overwrite:
        print(f"[restore] ERROR: name conflict. Re-run with --overwrite to drop them, "
              f"or rename the target databases to avoid collisions.")
        sys.exit(2)
    print(f"[restore] --overwrite set; will drop conflicting DBs.")

# ── Drop DBs that would conflict (originals + rename targets) ─────────────────
for name in names_to_clear:
    print(f"[restore] Dropping {name} on {args.target} if present ...")
    run_ps(args.target, textwrap.dedent(f"""
        $db='{name}'
        Invoke-Sqlcmd -ServerInstance '.' -Database 'master' -Query @"
        IF DB_ID('$db') IS NOT NULL BEGIN
            DECLARE @s SYSNAME = (SELECT state_desc FROM sys.databases WHERE name='$db');
            IF @s=N'ONLINE' ALTER DATABASE [$db] SET OFFLINE WITH ROLLBACK IMMEDIATE;
            DROP DATABASE [$db];
        END
"@
    """))

# ── VssRestore.exe ────────────────────────────────────────────────────────────
extra = []
if args.parallel > 1: extra += ["'--parallel'", f"'{args.parallel}'"]
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

# ── Post-restore state (DBs registered under ORIGINAL names, RESTORING) ───────
qlist = ",".join(f"'{d}'" for d in dbs)
out, _, _ = sqlcmd(args.target,
    f"SELECT name, state_desc FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
print("[restore] Post-restore DB states:"); print(out)

# ── Optional tlog chain verify (with optional PITR stopat) ────────────────────
# verify_tlog_chain.py brings each DB ONLINE (WITH RECOVERY) at the end.
if args.with_tlog:
    for db in dbs:
        print(f"[restore] T-log chain verify for {db}"
              + (f"  PITR={args.stopat}" if args.stopat else "") + " ...")
        cmd = ["python3", "-u", os.path.join(REQDIR, "verify_tlog_chain.py"), db,
               "--target", args.target, "--source", args.source]
        if args.stopat:
            cmd += ["--stopat", args.stopat]
        r = subprocess.run(cmd, capture_output=False, text=True)
        if r.returncode != 0:
            print(f"[restore] ERROR: verify_tlog_chain FAILED for {db}")
            sys.exit(4)

# ── Bring any still-RESTORING rename candidates ONLINE so we can rename ───────
# If the user skipped with_tlog but asked for a rename, the DB is still in
# RESTORING state; ALTER DATABASE MODIFY NAME requires the DB to be ONLINE, so
# apply RESTORE WITH RECOVERY for the DBs that need renaming.
if rename_map and not args.with_tlog:
    for orig in rename_map:
        print(f"[restore] RESTORE DATABASE [{orig}] WITH RECOVERY (pre-rename) ...")
        o, e, rc2 = sqlcmd(args.target,
            f"RESTORE DATABASE [{orig}] WITH RECOVERY;", timeout=120)
        if rc2 != 0:
            print(f"[restore] ERROR: could not recover {orig} for rename: {e[:400]}")
            sys.exit(5)

# ── Rename step (ALTER DATABASE ... MODIFY NAME) ──────────────────────────────
if rename_map:
    print(f"[restore] Renaming databases on {args.target}: {rename_map}")
    for orig, new in rename_map.items():
        print(f"[restore] ALTER DATABASE [{orig}] MODIFY NAME = [{new}]")
        o, e, rc3 = sqlcmd(args.target,
            f"ALTER DATABASE [{orig}] MODIFY NAME = [{new}];", timeout=60)
        if rc3 != 0:
            print(f"[restore] ERROR: rename {orig} -> {new} failed: {e[:400]}")
            sys.exit(5)
    # Show the final state using the effective names.
    qlist2 = ",".join(f"'{d}'" for d in effective.values())
    out, _, _ = sqlcmd(args.target,
        f"SELECT name, state_desc FROM sys.databases WHERE name IN ({qlist2}) ORDER BY name")
    print("[restore] Final DB states after rename:"); print(out)

print("[restore] Complete.")
