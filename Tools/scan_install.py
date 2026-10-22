#!/usr/bin/env python3
"""Read-only inventory for a locally owned BO1/Plutonium T5 installation."""
import argparse
from collections import Counter
from pathlib import Path
import json

EXTENSIONS = {'.ff','.iwd','.iwi','.pak','.iwi','.csv','.gsc','.bik','.wav','.mp3','.exe','.dll','.ffm'}

def scan(root):
    root = root.expanduser().resolve()
    if not root.is_dir():
        raise NotADirectoryError(str(root))
    counts = Counter(); sizes = Counter(); entries = []
    for p in root.rglob('*'):
        if not p.is_file():
            continue
        ext = p.suffix.lower()
        counts[ext] += 1
        sizes[ext] += p.stat().st_size
        if ext in EXTENSIONS:
            entries.append({'path': str(p.relative_to(root)), 'bytes': p.stat().st_size})
    entries.sort(key=lambda o: o['path'].lower())
    return {'root': str(root), 'total_files': sum(counts.values()),
            'extensions': {k: {'files': counts[k], 'bytes': sizes[k]} for k in sorted(counts)},
            'assets': entries, 'note': 'Inventory only; no extraction or game files included.'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('game_folder', type=Path)
    ap.add_argument('--out', type=Path, default=Path('installation_inventory.json'))
    args = ap.parse_args()
    report = scan(args.game_folder)
    args.out.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Scanned {report["total_files"]} files, logged {len(report["assets"])} relevant files to {args.out}')

if __name__ == '__main__':
    main()
