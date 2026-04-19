"""Backup-only runner — called by the API server as a subprocess.

Usage (called by vss_api/server.py):
    python3 backup.py <label> <source_host> <db1,db2,...>
                      [--compress] [--parallel N] [--with-tlog]

Outputs progress lines to stdout; the job manager captures and streams them.
"""
import argparse, os, sys, subprocess, textwrap, time, datetime

HERE     = os.path.dirname(os.path.abspath(__file__))
VSS_ROOT = os.path.dirname(os.path.dirname(HERE))   # Backup-Restore-VSS/
sys.path.insert(0, VSS_ROOT)

from winrm_helper import run_ps, sqlcmd, load_config

_cfg          = load_config()
SHARE_UNC     = _cfg.get("SHARE_UNC", r"\\192.168.122.1\vss-transport")
TRANSPORT     = _cfg.get("SHARE_LINUX_PATH", "/hyperactive/vss-transport")
REQDIR        = os.path.join(VSS_ROOT, "VssRequester")

ap = argparse.ArgumentParser()
ap.add_argument("label")
ap.add_argument("source")
ap.add_argument("databases")
ap.add_argument("--compress",   action="store_true")
ap.add_argument("--parallel",   type=int, default=1)
ap.add_argument("--with-tlog",  action="store_true")
args = ap.parse_args()

ts      = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
label   = args.label
dbs     = [d.strip() for d in args.databases.split(",") if d.strip()]
out_unc = rf"{SHARE_UNC}\{label}_{ts}"
out_lin = os.path.join(TRANSPORT, f"{label}_{ts}")

os.makedirs(out_lin, exist_ok=True)
subprocess.run(["chmod", "777", out_lin], check=False)

print(f"[backup] label={label}  source={args.source}  dbs={dbs}")
print(f"[backup] compress={args.compress}  parallel={args.parallel}")
print(f"[backup] output UNC : {out_unc}")
print(f"[backup] output path: {out_lin}")

# ── Source DB state ───────────────────────────────────────────────────────────
qlist = ",".join(f"'{d}'" for d in dbs)
out, _, _ = sqlcmd(args.source,
    f"SELECT name, state_desc, recovery_model_desc "
    f"FROM sys.databases WHERE name IN ({qlist}) ORDER BY name")
print("[backup] Source DB states:"); print(out)

# ── VssBackup.exe ─────────────────────────────────────────────────────────────
extra = []
if args.compress:    extra += ["'--compress'"]
if args.parallel > 1: extra += ["'--parallel'", f"'{args.parallel}'"]
extra_s = (", " + ", ".join(extra)) if extra else ""

print(f"[backup] Starting VssBackup.exe ...")
script = textwrap.dedent(f"""
$out = 'C:\\Scripts\\VssBackup_{label}_out.txt'
$err = 'C:\\Scripts\\VssBackup_{label}_err.txt'
Remove-Item $out,$err -EA SilentlyContinue
$t0 = Get-Date
$p  = Start-Process 'C:\\Scripts\\VssBackup\\VssBackup.exe' `
      -ArgumentList '--databases','{",".join(dbs)}','--output','{out_unc}'{extra_s} `
      -NoNewWindow -Wait -PassThru `
      -RedirectStandardOutput $out -RedirectStandardError $err
$dt = (Get-Date) - $t0
"duration_seconds=$([int]$dt.TotalSeconds)"
"exit_code=$($p.ExitCode)"
'--- STDOUT ---'; Get-Content $out
'--- STDERR ---'; Get-Content $err
""")
t0 = time.time()
out, err, rc = run_ps(args.source, script, timeout=7200)
print(f"[backup] VssBackup wall={time.time()-t0:.1f}s  rc={rc}")
print(out)
if err.strip(): print("WINRM ERR:", err[:400])

# ── Share listing ─────────────────────────────────────────────────────────────
print("[backup] Share contents:")
r = subprocess.run(["ls", "-lah", out_lin], capture_output=True, text=True)
print(r.stdout)
for db in dbs:
    p = os.path.join(out_lin, db)
    if os.path.isdir(p):
        r = subprocess.run(["du", "-sh", p], capture_output=True, text=True)
        print(r.stdout.strip())

# ── Optional tlog chain verify ────────────────────────────────────────────────
if args.with_tlog:
    for db in dbs:
        print(f"[backup] T-log chain verify for {db} ...")
        r = subprocess.run(
            ["python3", "-u", os.path.join(REQDIR, "verify_tlog_chain.py"), db],
            capture_output=False, text=True)
        if r.returncode != 0:
            print(f"[backup] ERROR: verify_tlog_chain failed for {db}")
            sys.exit(1)

print(f"[backup] Done.  Snapshot folder: {label}_{ts}")
