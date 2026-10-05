#!/bin/bash
# SPDX-License-Identifier: MIT
#
# jetson-capture.sh - demarre l'image d'analyse dans QEMU, y profile
# analysis-demo avec perf, rapatrie l'enregistrement par rsync et produit
# le flame graph et la heatmap.
#
# Usage :
#   jetson-capture.sh [--scale N] [--freq HZ] [--selinux-permissive] OUTDIR
#
# La VM tourne dans son propre cgroup (CPU, memoire, pas de swap), a cote
# de celui des builds. Le rootfs demarre en snapshot : l'image n'est pas
# modifiee. L'acces se fait avec la cle installee par capture-access.bbclass.
#
# Historique :
#   0.2.1  qemuboot.conf : nom Wrynose <image>-<machine>.rootfs.qemuboot.conf
#   0.2.0  --selinux-permissive : la VM de capture seule demarre avec
#          enforcing=0 (sous enforcing, la politique refuse a sshd la
#          transition vers unconfined_t pour root) ; runqemu recoit le
#          qemuboot.conf de l'image au lieu d'un parse bitbake
#   0.1.0  premiere version
#
# Maintainer: Aurelien DESBRIERES <aurelien@hackers.camp>

set -euo pipefail

VERSION="0.2.1"

WRYNOSE_DIR="${WRYNOSE_DIR:-/home/aurelien/yocto/wrynose}"
BUILD_DIR="${BUILD_DIR:-$WRYNOSE_DIR/build-qemuarm64}"
OE_INIT="$WRYNOSE_DIR/layers/openembedded-core/oe-init-build-env"
IMAGE="${IMAGE:-jetson-analysis-image}"
KEY="${KEY:-$WRYNOSE_DIR/capture/id_ed25519}"
SSH_PORT="${SSH_PORT:-2222}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-900}"
QEMU_LOG="${QEMU_LOG:-/tmp/jetson-capture-qemu.log}"
CG="/sys/fs/cgroup/yocto-capture"
CG_CPU_MAX="${CG_CPU_MAX:-400000 100000}"
CG_MEM_MAX="${CG_MEM_MAX:-3G}"
MEM_RESERVE_KB="${MEM_RESERVE_KB:-4194304}"
DEMO_MATCH="${DEMO_MATCH:-matmul,sort_values,hash_table,parse_lines}"
HERE=$(cd "$(dirname "$0")" && pwd)

scale=5
permissive=0
freq=499
qpid=""

die() { echo "jetson-capture: $*" >&2; exit 1; }

ssh_vm() {
    ssh -i "$KEY" -p "$SSH_PORT" -o BatchMode=yes -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR root@127.0.0.1 "$@"
}

stop_vm() {
    [ -n "$qpid" ] || return 0
    if kill -0 "$qpid" 2>/dev/null; then
        ssh_vm poweroff >/dev/null 2>&1 || true
        local waited=0
        while [ "$waited" -lt 120 ] && kill -0 "$qpid" 2>/dev/null; do
            sleep 2
            waited=$((waited + 2))
        done
        kill -TERM -- "-$qpid" 2>/dev/null || true
    fi
    qpid=""
}
trap stop_vm EXIT

while [ $# -gt 0 ]; do
    case "$1" in
        --version) echo "jetson-capture.sh $VERSION"; exit 0 ;;
        -h|--help) sed -n '8,9p' "$0"; exit 2 ;;
        --scale) scale=$2; shift 2 ;;
        --freq) freq=$2; shift 2 ;;
        --selinux-permissive) permissive=1; shift ;;
        -*) die "option inconnue : $1" ;;
        *) break ;;
    esac
done
[ $# -eq 1 ] || die "usage : jetson-capture.sh [--scale N] [--freq HZ] [--selinux-permissive] OUTDIR"
out=$1
mkdir -p "$out"
[ -r "$KEY" ] || die "cle $KEY illisible"

echo "jetson-capture.sh $VERSION"
avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
need=$(( $(numfmt --from=iec "$CG_MEM_MAX") / 1024 + MEM_RESERVE_KB ))
echo "MemAvailable $avail kB, requis $need kB (memory.max + reserve VM)"
[ "$avail" -ge "$need" ] || die "memoire insuffisante, capture non lancee"

sudo mkdir -p "$CG" || die "creation $CG"
printf '%s\n' "$CG_CPU_MAX" | sudo tee "$CG/cpu.max" >/dev/null
numfmt --from=iec "$CG_MEM_MAX" | sudo tee "$CG/memory.max" >/dev/null
printf '0\n' | sudo tee "$CG/memory.swap.max" >/dev/null
echo $$ | sudo tee "$CG/cgroup.procs" >/dev/null || die "deplacement dans $CG"
grep -qx '0::/yocto-capture' "/proc/$$/cgroup" || die "processus hors de $CG"
echo "cgroup : $(cat /proc/$$/cgroup), cpu.max $(cat "$CG/cpu.max"), memory.max $(cat "$CG/memory.max")"

set +eu
# shellcheck disable=SC1090
. "$OE_INIT" "$BUILD_DIR" >/dev/null
rc=$?
set -eu
[ "$rc" -eq 0 ] || die "oe-init-build-env ($rc)"

echo "demarrage de la VM (console : $QEMU_LOG)"
deploy="$BUILD_DIR/tmp/deploy/images/qemuarm64"
# Wrynose nomme le fichier <image>-<machine>.rootfs.qemuboot.conf.
qbconf="$deploy/$IMAGE-qemuarm64.rootfs.qemuboot.conf"
[ -f "$qbconf" ] || qbconf="$deploy/$IMAGE-qemuarm64.qemuboot.conf"
[ -f "$qbconf" ] || die "aucun qemuboot.conf pour $IMAGE dans $deploy : image non construite"
qargs=(nographic slirp snapshot)
selinux_note="SELinux enforcing"
if [ "$permissive" -eq 1 ]; then
    qargs+=("bootparams=enforcing=0")
    selinux_note="SELinux permissive (enforcing=0, capture VM only)"
fi
echo "runqemu $qbconf ${qargs[*]}"
setsid runqemu "$qbconf" "${qargs[@]}" > "$QEMU_LOG" 2>&1 < /dev/null &
qpid=$!

t=0
until ssh_vm true 2>/dev/null; do
    kill -0 "$qpid" 2>/dev/null || die "QEMU s'est arrete, voir $QEMU_LOG"
    [ "$t" -lt "$BOOT_TIMEOUT" ] || die "pas de SSH apres $BOOT_TIMEOUT s, voir $QEMU_LOG"
    sleep 10
    t=$((t + 10))
done
echo "SSH disponible apres $t s"

kver=$(ssh_vm uname -r)
echo "profilage : analysis-demo $scale, perf cpu-clock a $freq Hz"
# shellcheck disable=SC2029
ssh_vm "set -e
    { uname -a; nproc; perf --version; echo \"selinux enforce: \$(cat /sys/fs/selinux/enforce 2>/dev/null || echo absent)\"; } > /tmp/demo.system
    perf record -F $freq -g -e cpu-clock -o /tmp/demo.perf.data -- analysis-demo $scale \
        > /tmp/demo.stdout 2> /tmp/demo.perf-record.log
    perf script -i /tmp/demo.perf.data > /tmp/demo.perf.script 2> /tmp/demo.perf-script.log" \
    || die "profilage dans la VM"

rsync -a -e "ssh -i $KEY -p $SSH_PORT -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR" \
    'root@127.0.0.1:/tmp/demo.*' "$out/" || die "rsync"
stop_vm

echo "--- systeme de capture"
cat "$out/demo.system"
echo "--- sortie de analysis-demo"
cat "$out/demo.stdout"
echo "--- perf record"
cat "$out/demo.perf-record.log"

RENDER_TITLE="analysis-demo: CPU flame graph" \
RENDER_SUBTITLE="qemuarm64 under QEMU TCG emulation, linux-yocto $kver, perf cpu-clock at $freq Hz, $selinux_note" \
    "$HERE/jetson-render.sh" "$out/demo.perf.script" "$out" \
    --comm analysis-demo --match "$DEMO_MATCH" || die "rendu"
