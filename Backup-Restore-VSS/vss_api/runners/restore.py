"""Restore-from-snapshot runner — called by the API server as a subprocess.

Usage (called by vss_api/server.py):
    python3 restore.py <snapshot_name> <target_host>
                       [--databases DB1,DB2]
                       [--parallel N]
                       [--with-tlog]
                       [--stopat YYYY-MM-DDTHH:MM:SS]

Outputs progress lines to stdout; the job manager captures and streams them.
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

print(f"[restore] snapshot={snap}  target={args.target}")
print(f"[restore] databases={dbs}  parallel={args.parallel}")
print(f"[restore] with_tlog={args.with_tlog}  stopat={args.stopat}")
print(f"[restore] input UNC: {out_unc}")

# ── Drop existing target DBs ──────────────────────────────────────────────────
for db in dbs:
    print(f"[restore] Dropping {db} on {args.target} if present ...")
    run_ps(args.target, textwrap.dedent(f"""
        $db='{db}'
        Invoke-Sqlcmd -ServerInstance '.' -Query @"
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

# ── Post-restore state ────────────────────────────────────────────────────────
qlist = ",".join(f"'{d}'" for d in dbs)
out, _, _ = sqlcmd(args.target,
    f"SELECT name, state_desc FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
print("[restore] Post-restore DB states:"); print(out)

# ── Optional tlog chain verify (with optional PITR stopat) ───────────────────
if args.with_tlog:
    for db in dbs:
        print(f"[restore] T-log chain verify for {db}"
              + (f"  PITR={args.stopat}" if args.stopat else "") + " ...")
        cmd = ["python3", "-u", os.path.join(REQDIR, "verify_tlog_chain.py"), db]
        if args.stopat:
            cmd += ["--stopat", args.stopat]
        r = subprocess.run(cmd, capture_output=False, text=True)
        if r.returncode != 0:
            print(f"[restore] WARNING: verify_tlog_chain FAILED for {db}")
            sys.exit(1)

print("[restore] Complete.")
