#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""jetson-follow - live view of a bitbake build started without a terminal.

Without a terminal, bitbake writes to its log only when a task starts and
ends: an hour of compilation leaves no trace there. The progress is in
each task's own log (tmp/work/.../temp/log.do_*.<pid>). This tool shows
the bitbake logs given as arguments, then every task log being written,
prefixed with the recipe and the task, following new tasks as they start.

Usage:
  jetson-follow.py --build BUILDDIR [--build BUILDDIR ...] [--pid PID] [LOG ...]

With --pid, the tool stops once process PID has exited (a zombie counts
as exited): it shows what the logs still hold, then exits 0 if the bitbake
logs report all tasks succeeded and no ERROR line, 1 otherwise. This is
the criterion jetson-build.sh --after uses. Without --pid, it runs until
interrupted.

History:
  0.2.0  --pid: stop when the build process exits, status from the logs;
         comments in English
  0.1.0  first version
"""

import argparse
import glob
import os
import sys
import time

VERSION = "0.2.0"


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


def alive(pid):
    """True while pid exists and is not a zombie."""
    try:
        with open('/proc/%d/stat' % pid) as f:
            stat = f.read()
    except OSError:
        return False
    state = stat[stat.rfind(')') + 2:].split(' ', 1)[0]
    return state != 'Z'


def succeeded(logs):
    """Same criterion as jetson-build.sh --after."""
    ok = False
    for p in logs:
        try:
            with open(p, 'rb') as f:
                text = f.read().decode('utf-8', 'replace')
        except OSError:
            continue
        if any(line.startswith('ERROR') for line in text.split('\n')):
            return False
        if 'all succeeded' in text:
            ok = True
    return ok


def poll(args, offsets, followed):
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


def main():
    ap = argparse.ArgumentParser(description='Live view of a detached bitbake build')
    ap.add_argument('logs', nargs='*', help='bitbake logs to show in full, then follow')
    ap.add_argument('--build', action='append', default=[], help='bitbake build directory')
    ap.add_argument('--pid', type=int, default=None,
                    help='stop once this process (the build) has exited')
    ap.add_argument('--window', type=int, default=180,
                    help='maximum age (s) of a task log to start following it')
    ap.add_argument('--version', action='version', version='%(prog)s ' + VERSION)
    args = ap.parse_args()

    offsets = {}
    followed = set()
    while True:
        running = args.pid is None or alive(args.pid)
        poll(args, offsets, followed)
        if not running:
            ok = succeeded(args.logs)
            sys.stdout.write('jetson-follow: process %d has exited, build %s\n'
                             % (args.pid, 'succeeded' if ok else 'FAILED'))
            sys.stdout.flush()
            return 0 if ok else 1
        time.sleep(2)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
