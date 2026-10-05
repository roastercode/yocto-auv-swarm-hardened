#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""jetson-heatmap - heatmap temps x fonction a partir de `perf script`.

Chaque echantillon perf est range dans une ligne (une fonction) et une
colonne (une tranche de temps). La couleur dit combien d'echantillons
sont tombes dans la case. Sur un programme qui enchaine des phases, on
voit ou passe le temps, et quand.

Usage :
  perf script -i perf.data > perf.script
  jetson-heatmap.py perf.script -o heatmap.svg [--comm NOM]
      [--match f1,f2,...] [--rows N] [--bin-ms MS]
      [--title T] [--subtitle S]

Sans --match, les lignes sont les N fonctions feuilles les plus
echantillonnees. Avec --match, chaque echantillon va a la premiere
fonction de la liste presente dans sa pile.

Historique :
  0.1.0  premiere version
"""

import argparse
import html
import re
import sys
from collections import Counter, defaultdict

VERSION = "0.1.0"

HEADER = re.compile(
    r'^\s*(?P<comm>.+?)\s+(?P<pid>\d+)(?:/\d+)?\s+(?:\[\d+\]\s+)?(?P<ts>\d+\.\d+):')
FRAME = re.compile(r'^\s+[0-9a-f]+\s+(?P<sym>.+?)\s+\((?P<dso>[^)]*)\)\s*$')
OFFSET = re.compile(r'\+0x[0-9a-f]+$')

COLOURS = [(255, 247, 236), (253, 212, 158), (252, 141, 89),
           (215, 48, 31), (127, 0, 0)]


def display(sym):
    s = OFFSET.sub('', sym).replace('(anonymous namespace)::', '')
    i = s.find('(')
    if i > 0:
        s = s[:i]
    return s if len(s) <= 48 else s[:45] + '...'


def parse(stream, comm):
    samples = []
    cur = None
    for raw in stream:
        line = raw.rstrip('\n')
        if not line.strip():
            if cur is not None:
                samples.append(cur)
                cur = None
            continue
        if line.startswith('\t'):
            if cur is not None:
                m = FRAME.match(line)
                if m:
                    cur[1].append(display(m.group('sym')))
            continue
        if cur is not None:
            samples.append(cur)
        m = HEADER.match(line)
        if m and (comm is None or m.group('comm').strip() == comm):
            cur = (float(m.group('ts')), [])
        else:
            cur = None
    if cur is not None:
        samples.append(cur)
    return samples


def colour(t):
    t = max(0.0, min(1.0, t))
    pos = t * (len(COLOURS) - 1)
    i = min(int(pos), len(COLOURS) - 2)
    f = pos - i
    a, b = COLOURS[i], COLOURS[i + 1]
    return '#%02x%02x%02x' % tuple(int(round(a[k] + (b[k] - a[k]) * f)) for k in range(3))


def main():
    ap = argparse.ArgumentParser(description='Heatmap temps x fonction depuis perf script')
    ap.add_argument('input', help='sortie de perf script, ou - pour stdin')
    ap.add_argument('-o', '--output', required=True, help='fichier SVG produit')
    ap.add_argument('--comm', help='ne garder que ce processus')
    ap.add_argument('--match', help='fonctions a suivre, separees par des virgules')
    ap.add_argument('--rows', type=int, default=12, help='nombre de lignes sans --match')
    ap.add_argument('--bin-ms', type=int, default=100, help='largeur d\'une colonne en ms')
    ap.add_argument('--title', default='CPU time by function')
    ap.add_argument('--subtitle', default='')
    ap.add_argument('--version', action='version', version='%(prog)s ' + VERSION)
    args = ap.parse_args()

    stream = sys.stdin if args.input == '-' else open(args.input, encoding='utf-8', errors='replace')
    samples = [s for s in parse(stream, args.comm) if s[1]]
    if not samples:
        sys.exit('jetson-heatmap: aucun echantillon avec pile dans l\'entree')

    if args.match:
        pats = [p for p in args.match.split(',') if p]

        def row_of(frames):
            for p in pats:
                if any(p in f for f in frames):
                    return p
            return 'other'
        order = pats + ['other']
    else:
        leaves = Counter(fr[0] for _, fr in samples)
        top = [n for n, _ in leaves.most_common(args.rows)]
        topset = set(top)

        def row_of(frames):
            return frames[0] if frames[0] in topset else 'other'
        order = top + ['other']

    t0 = min(ts for ts, _ in samples)
    grid = defaultdict(int)
    totals = Counter()
    ncols = 1
    for ts, frames in samples:
        r = row_of(frames)
        c = int((ts - t0) * 1000.0 // args.bin_ms)
        grid[(r, c)] += 1
        totals[r] += 1
        ncols = max(ncols, c + 1)
    order = [r for r in order if totals[r] > 0]
    vmax = max(grid.values())
    n = len(samples)

    label_w, right_w, top, cell_h = 250, 150, 78, 24
    cell_w = max(2.0, min(24.0, 900.0 / ncols))
    plot_w = cell_w * ncols
    width = int(label_w + plot_w + right_w)
    height = int(top + cell_h * len(order) + 90)
    dur_s = ncols * args.bin_ms / 1000.0
    step = 1 if dur_s <= 20 else 5 if dur_s <= 100 else 10

    out = []
    w = out.append
    w('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
      'font-family="DejaVu Sans, Verdana, sans-serif" font-size="12">' % (width, height))
    w('<rect width="100%" height="100%" fill="white"/>')
    w('<text x="%d" y="26" font-size="17" font-weight="bold">%s</text>'
      % (label_w, html.escape(args.title)))
    if args.subtitle:
        w('<text x="%d" y="46" fill="#555">%s</text>' % (label_w, html.escape(args.subtitle)))
    w('<text x="%d" y="64" fill="#555">%d samples, %d ms per column</text>'
      % (label_w, n, args.bin_ms))
    for i, r in enumerate(order):
        y = top + i * cell_h
        w('<rect x="%d" y="%d" width="%.1f" height="%d" fill="#f7f7f7"/>'
          % (label_w, y, plot_w, cell_h - 2))
        w('<text x="%d" y="%d" text-anchor="end">%s</text>'
          % (label_w - 8, y + cell_h - 8, html.escape(r)))
        w('<text x="%.1f" y="%d" fill="#333">%d (%.1f%%)</text>'
          % (label_w + plot_w + 10, y + cell_h - 8, totals[r], 100.0 * totals[r] / n))
        for c in range(ncols):
            v = grid.get((r, c), 0)
            if not v:
                continue
            x = label_w + c * cell_w
            w('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s">'
              '<title>%s, %.1f-%.1f s: %d samples</title></rect>'
              % (x, y, cell_w, cell_h - 2, colour(v / vmax), html.escape(r),
                 c * args.bin_ms / 1000.0, (c + 1) * args.bin_ms / 1000.0, v))
    ay = top + cell_h * len(order) + 6
    w('<line x1="%d" y1="%d" x2="%.1f" y2="%d" stroke="#333"/>' % (label_w, ay, label_w + plot_w, ay))
    s = 0
    while s <= dur_s + 1e-9:
        x = label_w + s * 1000.0 / args.bin_ms * cell_w
        w('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#333"/>' % (x, ay, x, ay + 5))
        w('<text x="%.1f" y="%d" text-anchor="middle">%d</text>' % (x, ay + 18, s))
        s += step
    w('<text x="%.1f" y="%d" text-anchor="middle" fill="#555">time (s)</text>'
      % (label_w + plot_w / 2, ay + 36))
    ly = ay + 52
    for k in range(50):
        w('<rect x="%.1f" y="%d" width="4" height="10" fill="%s"/>'
          % (label_w + k * 4, ly, colour((k + 1) / 50.0)))
    w('<text x="%d" y="%d" fill="#555">1</text>' % (label_w - 12, ly + 9))
    w('<text x="%d" y="%d" fill="#555">%d samples per cell</text>' % (label_w + 206, ly + 9, vmax))
    w('</svg>')

    with open(args.output, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out) + '\n')

    print('jetson-heatmap %s : %d echantillons, %d colonnes de %d ms, %s'
          % (VERSION, n, ncols, args.bin_ms, args.output), file=sys.stderr)
    for r in order:
        print('  %-48s %7d  %5.1f %%' % (r, totals[r], 100.0 * totals[r] / n), file=sys.stderr)


if __name__ == '__main__':
    main()
