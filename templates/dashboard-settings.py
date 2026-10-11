#!/usr/bin/env python3
"""Write the local dashboard override using PHP literal escaping."""
import sys
from pathlib import Path

def write_settings(path, name, callhome):
    if not name or len(name) > 60 or any(ord(c) < 32 for c in name):
        raise ValueError('Extended name must contain 1–60 printable characters')
    if callhome not in ('Y', 'N'):
        raise ValueError('Call-home must be Y or N')
    escaped = name.replace('\\', '\\\\').replace("'", "\\'")
    Path(path).write_text("<?php\n$CallingHome['Active'] = " + ('true' if callhome == 'Y' else 'false') + ";\n$PageOptions['CustomTXT'] = '" + escaped + "';\n", encoding='utf-8')

if __name__ == '__main__':
    write_settings(*sys.argv[1:])
