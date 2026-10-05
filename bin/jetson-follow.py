#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""jetson-follow - suivi en direct d'un build bitbake lance sans terminal.

Sans terminal, bitbake n'ecrit dans son journal qu'au debut et a la fin
de chaque tache : une compilation d'une heure n'y laisse aucune trace. La
progression est dans le journal propre de chaque tache
(tmp/work/.../temp/log.do_*.<pid>). Cet outil affiche les journaux de
bitbake donnes en argument, puis chaque journal de tache en cours
d'ecriture, prefixe par la recette et la tache, en suivant les nouvelles
taches au fur et a mesure.

Usage :
  jetson-follow.py --build BUILDDIR [--build BUILDDIR ...] [LOG ...]

Historique :
  0.1.0  premiere version
"""

import argparse
import glob
import os
import sys
import time

VERSION = "0.1.0"


def label(path):
    parts = path.split(os.sep)
    try:
        i = parts.index('temp')
        pn = parts[i - 2]
        task = parts[i + 1].split('.')[1]
    except (ValueError, IndexError):
        return os.path.basename(path)
    return '%s %s' % (pn, task)


def emit(path, offsets, prefix):
    try:
        size = os.path.getsize(path)
    except OSError:
        return
    off = offsets.get(path, 0)
    if size < off:
        off = 0
    if size == off:
        offsets[path] = off
        return
    with open(path, 'rb') as f:
        f.seek(off)
        data = f.read(size - off)
    cut = data.rfind(b'\n')
    if cut < 0:
        return
    for line in data[:cut].decode('utf-8', 'replace').split('\n'):
        sys.stdout.write(prefix + line + '\n')
    offsets[path] = off + cut + 1
    sys.stdout.flush()


def main():
    ap = argparse.ArgumentParser(description='Suivi en direct d\'un build bitbake detache')
    ap.add_argument('logs', nargs='*', help='journaux bitbake a afficher en entier puis suivre')
    ap.add_argument('--build', action='append', default=[], help='repertoire de build bitbake')
    ap.add_argument('--window', type=int, default=180,
                    help='age maximal (s) d\'un journal de tache pour commencer a le suivre')
    ap.add_argument('--version', action='version', version='%(prog)s ' + VERSION)
    args = ap.parse_args()

    offsets = {}
    followed = set()
    while True:
        for p in args.logs:
            emit(p, offsets, '')
        now = time.time()
        for b in args.build:
            for p in glob.glob(os.path.join(b, 'tmp', 'work', '*', '*', '*', 'temp', 'log.do_*.*')):
                if os.path.islink(p):
                    continue
                if p not in followed:
                    try:
                        if now - os.path.getmtime(p) > args.window:
                            continue
                    except OSError:
                        continue
                    followed.add(p)
                emit(p, offsets, '[%s] ' % label(p))
        time.sleep(2)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
