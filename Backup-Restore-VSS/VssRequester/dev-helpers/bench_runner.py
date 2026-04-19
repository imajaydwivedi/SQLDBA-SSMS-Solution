"""Run one e2e_run_multi.py scenario and append a results row to
vss-backup-kvm.md section 12.2.

Usage:
  python3 bench_runner.py <num> <label> <dbs> <with-tlog|no-tlog> [compress] [parallel=N]

Example:
  python3 bench_runner.py 1 b1_small_base    CDCDemo,Db2        no-tlog
  python3 bench_runner.py 6 b6_small_gzpar   CDCDemo,Db2       with-tlog compress parallel=2
"""
import sys, os, re, subprocess, datetime, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REQ  = os.path.dirname(HERE)
ROOT = os.path.dirname(REQ)
DOC  = os.path.join(ROOT, "vss-backup-kvm.md")
LOGDIR = "/tmp/bench"
os.makedirs(LOGDIR, exist_ok=True)

num      = sys.argv[1]
label    = sys.argv[2]
dbs_csv  = sys.argv[3]
tlog_tok = sys.argv[4]
extras_raw = sys.argv[5:]

# Normalize extras: accept both `compress`/`parallel=N` and `--compress`/`--parallel=N`
extras = []
for x in extras_raw:
    xl = x.lower().lstrip("-")
    if xl == "compress":
        extras.append("compress")
    elif xl.startswith("parallel="):
        extras.append(xl)
    else:
        extras.append(x)

log_path = os.path.join(LOGDIR, f"{num}_{label}.log")
cmd = ["python3", "-u", os.path.join(REQ, "e2e_run_multi.py"),
       label, dbs_csv, tlog_tok] + extras

print(f"=== bench {num} {label} :: {' '.join(cmd[2:])} ===")
t0 = datetime.datetime.now()
with open(log_path, "w") as lf:
    rc = subprocess.call(cmd, stdout=lf, stderr=subprocess.STDOUT)
dt = (datetime.datetime.now() - t0).total_seconds()
print(f"bench exit rc={rc}  wall={dt:.1f}s  log={log_path}")

with open(log_path, "r", errors="replace") as lf:
    text = lf.read()

def _find_duration(section_hdr):
    """Find the VssBackup/VssRestore 'duration_seconds=N' emitted after
    the given section header in the e2e_run_multi.py output."""
    m = re.search(rf"{re.escape(section_hdr)}.*?duration_seconds=(\d+)", text, re.S)
    return int(m.group(1)) if m else None

backup_s  = _find_duration("2. VssBackup.exe")
restore_s = _find_duration("4. VssRestore.exe")

compress = any(x == "compress" for x in extras)
par_tok = [x for x in extras if x.startswith("parallel=")]
parallel = int(par_tok[0].split("=", 1)[1]) if par_tok else 1
with_tlog = tlog_tok.lower() == "with-tlog"

tlog_ok = None
if with_tlog:
    dbs = [d.strip() for d in dbs_csv.split(",") if d.strip()]
    verified = re.findall(r"\*\*\* PURE-VSS T-LOG CHAIN VERIFIED \*\*\*", text)
    failed   = re.findall(r"FAIL [^\n]+", text)
    tlog_ok = "✅" if len(verified) == len(dbs) else (
              "—" if len(verified) == 0 else
              f"partial ({len(verified)}/{len(dbs)})")
else:
    tlog_ok = "—"

share_re = re.search(r"linux\s*:\s*(\S+)", text)
share_bytes = None
if share_re and os.path.isdir(share_re.group(1)):
    share_path = share_re.group(1)
    try:
        r = subprocess.run(["du", "-sb", share_path], capture_output=True, text=True)
        share_bytes = int(r.stdout.split()[0]) if r.returncode == 0 else None
    except Exception:
        pass

def fmt_bytes(n):
    if n is None: return "—"
    if n >= 1024**3: return f"{n/1024**3:.1f} G"
    if n >= 1024**2: return f"{n/1024**2:.0f} M"
    return f"{n} B"

flags = []
if parallel > 1: flags.append(f"P={parallel}")
if compress:     flags.append("Z")
if with_tlog:    flags.append("tlog")
flag_s = " ".join(flags) if flags else "base"

row = (
    f"| {num} | `{label}` ({flag_s}) | {dbs_csv} | "
    f"{backup_s if backup_s is not None else '—'} | "
    f"{restore_s if restore_s is not None else '—'} | "
    f"{tlog_ok} | {fmt_bytes(share_bytes)} | "
    f"exit={rc} |\n"
)
print("ROW:", row.strip())

with open(DOC, "r") as f:
    doc = f.read()
placeholder = "| _(runs populated as they complete — see git log for exact commit of each row)_ |"
if placeholder in doc:
    doc = doc.replace(placeholder, row.rstrip("\n"))
else:
    anchor = "### 12.3 How to reproduce"
    doc = doc.replace(anchor, row + "\n" + anchor)

with open(DOC, "w") as f:
    f.write(doc)

print(f"Appended row to {DOC}")
sys.exit(0 if rc == 0 else 1)
