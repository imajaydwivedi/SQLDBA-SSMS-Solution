#!/usr/bin/env python3
"""One-shot utility: replace decorative Unicode chars with ASCII in PS1 files."""
import os
FILES = [
    'Apply-TLogs.ps1',
    'Restore-FromVSSSnapshot.ps1',
    'Backup-Database-PreSnapshot.ps1',
]
REPL = {
    '\u2014': '-',   '\u2013': '-',
    '\u2500': '-',   '\u2501': '-',
    '\u2022': '*',
    '\u2192': '->',  '\u2190': '<-',
    '\u00a0': ' ',
    '\u201c': '"',   '\u201d': '"',
    '\u2018': "'",   '\u2019': "'",
}
here = os.path.dirname(os.path.abspath(__file__))
for fn in FILES:
    p = os.path.join(here, fn)
    with open(p, 'rb') as f:
        data = f.read()
    txt = data.decode('utf-8', errors='replace')
    # Strip any existing BOM so push_file adds a clean one
    if txt.startswith('\ufeff'):
        txt = txt[1:]
    for k, v in REPL.items():
        txt = txt.replace(k, v)
    with open(p, 'wb') as f:
        f.write(txt.encode('utf-8'))
    non_ascii = sum(1 for c in txt if ord(c) > 127)
    print(f"{fn}: {len(txt)} chars, non-ASCII remaining={non_ascii}")
