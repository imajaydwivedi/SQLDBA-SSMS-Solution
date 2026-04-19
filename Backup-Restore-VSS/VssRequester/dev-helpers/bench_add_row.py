"""Insert a single pre-computed row into section 12.2 of vss-backup-kvm.md.

This is a salvage helper used when bench_runner.py was killed between the
e2e_run_multi.py run completing and the row being written (e.g., the tool
harness cancelled the wrapper shell but the inner run actually finished
against the VMs).

Usage:
  python3 bench_add_row.py "| N | `label` (flags) | dbs | backup_s | restore_s | tlog | share | notes |"
"""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.abspath(os.path.join(HERE, "..", "..", "vss-backup-kvm.md"))
if sys.argv[1] == "--row-file":
    with open(sys.argv[2], "r") as f:
        row = f.read().strip()
else:
    row = sys.argv[1]
with open(DOC, "r") as f:
    doc = f.read()
anchor = "### 12.3 How to reproduce"
pre, post = doc.split(anchor, 1)
pre = pre.rstrip() + "\n" + row + "\n\n"
with open(DOC, "w") as f:
    f.write(pre + anchor + post)
print("added:", row)
