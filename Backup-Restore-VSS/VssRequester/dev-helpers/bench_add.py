"""Add a benchmark row by constructing it from named args (no backticks
need to be passed through the shell).

Usage:
  python3 bench_add.py --num 8 --label b8_med_gzpar --flags "P=2 Z" \
      --dbs DBA,Facebook --backup 698 --restore 42 --tlog - \
      --share "5.5 G" --notes "exit=0, high-entropy DB hurts gzip"
"""
import argparse, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.abspath(os.path.join(HERE, "..", "..", "vss-backup-kvm.md"))

p = argparse.ArgumentParser()
p.add_argument("--num", required=True)
p.add_argument("--label", required=True)
p.add_argument("--flags", default="base")
p.add_argument("--dbs", required=True)
p.add_argument("--backup", required=True)
p.add_argument("--restore", required=True)
p.add_argument("--tlog", required=True, help="-, OK, or partial string")
p.add_argument("--share", required=True)
p.add_argument("--notes", default="")
args = p.parse_args()

tlog_map = {"-": "—", "OK": "✅"}
tlog = tlog_map.get(args.tlog, args.tlog)

label_md = "`" + args.label + "`"
row = f"| {args.num} | {label_md} ({args.flags}) | {args.dbs} | {args.backup} | {args.restore} | {tlog} | {args.share} | {args.notes} |"

with open(DOC, "r") as f:
    doc = f.read()
anchor = "### 12.3 How to reproduce"
pre, post = doc.split(anchor, 1)
pre = pre.rstrip() + "\n" + row + "\n\n"
with open(DOC, "w") as f:
    f.write(pre + anchor + post)
print("added:", row)
