#!/bin/bash
# SPDX-License-Identifier: MIT
#
# jetson-build.sh - lance bitbake (yocto-jetson-tegra-hardened) dans un cgroup v2
# borne, pour ne pas perturber les campagnes beamfs (BX) qui tournent sur
# la meme station.
#
# Mesure de reference (spartian, BX en cours) : les VM prennent 4 a 5 des
# 20 CPU et 16 Go des 31 ; le swap partage le NVMe des disques des VM
# (nvme1n1). PSI est desactive au boot, d'ou le cgroup plutot que
# BB_PRESSURE_MAX_*.
#
# Usage :
#   jetson-build.sh [--dry-run] <arguments bitbake>
#   jetson-build.sh --after PID LOG <arguments bitbake>
#   jetson-build.sh status
#   jetson-build.sh scan
#   jetson-build.sh --version
#
# Le budget memoire se calcule au lancement : MemAvailable moins une
# reserve laissee aux VM, plafonne a CG_MEM_CEIL. Sous CG_MEM_FLOOR, le
# build n'est pas lance. Le parallelisme bitbake suit ce budget, sauf si
# BB_NUMBER_THREADS ou PARALLEL_MAKE sont imposes par l'environnement.
# Toutes les limites se surchargent par l'environnement.
#
# Historique :
#   0.6.0  plafond 12 Go, 1,5 Go par compilateur (llvm thrashait a 1 Go)
#   0.5.0  scan : recettes laissees avec des objets vides par une
#          compilation coupee
#   0.4.1  reserve VM 2 Go, plancher 3 Go : la memoire des VM est deja
#          allouee et hors de MemAvailable
#   0.4.0  parallelisme : un compilateur par Go de budget (0.3.0 en
#          lancait 28 pour 8 Go et le cgroup thrashait)
#   0.3.0  --after PID LOG : attend la fin d'un build, n'enchaine que
#          s'il a reussi
#   0.2.1  en-tete au nom du projet yocto-jetson-tegra-hardened
#   0.2.0  budget memoire adaptatif, parallelisme derive du budget
#   0.1.0  cgroup a limites fixes
#
# Maintainer: Aurelien DESBRIERES <aurelien@hackers.camp>

set -euo pipefail

VERSION="0.6.0"

WRYNOSE_DIR="${WRYNOSE_DIR:-/home/aurelien/yocto/wrynose}"
BUILD_DIR="${BUILD_DIR:-$WRYNOSE_DIR/build-agx-orin}"
OE_INIT="$WRYNOSE_DIR/layers/openembedded-core/oe-init-build-env"
CG="/sys/fs/cgroup/yocto-build"

CG_CPU_MAX="${CG_CPU_MAX:-1000000 100000}"
CG_CPU_WEIGHT="${CG_CPU_WEIGHT:-50}"
CG_MEM_CEIL="${CG_MEM_CEIL:-12G}"
CG_MEM_FLOOR="${CG_MEM_FLOOR:-3G}"
CG_SWAP_MAX="${CG_SWAP_MAX:-0}"
CG_IO_MAX="${CG_IO_MAX:-259:6 rbps=209715200 wbps=52428800}"
MEM_RESERVE_KB="${MEM_RESERVE_KB:-2097152}"
export BB_LOADFACTOR_MAX="${BB_LOADFACTOR_MAX:-0.75}"

GIB_KB=1048576
mem_max_kb=0
mem_high_kb=0

die() { echo "jetson-build: $*" >&2; exit 1; }

usage() {
    sed -n '13,18p' "$0"
    exit 2
}

clamp() {
    local v=$1 lo=$2 hi=$3
    [ "$v" -lt "$lo" ] && v=$lo
    [ "$v" -gt "$hi" ] && v=$hi
    echo "$v"
}

host_state() {
    echo "loadavg        : $(cat /proc/loadavg)"
    echo "MemAvailable   : $(awk '/^MemAvailable:/{print $2}' /proc/meminfo) kB"
    echo "SwapFree       : $(awk '/^SwapFree:/{print $2}' /proc/meminfo) kB"
    echo "VM en marche   : $(virsh -c qemu:///system list --name 2>/dev/null | grep -c . || true)"
}

budget() {
    local avail ceil floor b mem_g
    avail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    ceil=$(( $(numfmt --from=iec "$CG_MEM_CEIL") / 1024 ))
    floor=$(( $(numfmt --from=iec "$CG_MEM_FLOOR") / 1024 ))
    b=$(( avail - MEM_RESERVE_KB ))
    [ "$b" -gt "$ceil" ] && b=$ceil
    host_state
    echo "budget         : $b kB (disponible - reserve $MEM_RESERVE_KB, plafond $ceil, plancher $floor)"
    [ "$b" -ge "$floor" ] || die "budget memoire sous le plancher ($b < $floor kB), build non lance"
    mem_max_kb=$b
    mem_high_kb=$(( b - GIB_KB ))
    mem_g=$(( b / GIB_KB ))
    # Une unite C++ (icu, llvm, clang) tient souvent 0,5 a 1 Go. Au-dela
    # d'environ un compilateur par Go de budget, le cgroup reste colle a
    # memory.high et passe son temps a recuperer des pages au lieu de
    # compiler. Mesure : 28 compilateurs pour 8 Go, 2 millions
    # d'evenements high par minute, des unites a 2 h 30.
    local total threads jobs
    # llvm a corrige la regle d'un compilateur par Go : une unite cc1plus
    # y tient 1,5 Go, et llvm-tblgen et le serveur bitbake pesent dans le
    # meme cgroup. On compte 1,5 Go par compilateur.
    total=$(clamp $(( mem_g * 2 / 3 )) 2 16)
    threads=$(clamp $(( total / 4 )) 1 3)
    jobs=$(clamp $(( total / threads )) 2 8)
    export BB_NUMBER_THREADS="${BB_NUMBER_THREADS:-$threads}"
    export PARALLEL_MAKE="${PARALLEL_MAKE:--j $jobs}"
    export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS:-} BB_NUMBER_THREADS PARALLEL_MAKE BB_LOADFACTOR_MAX"
}

cg_write() {
    printf '%s\n' "$2" | sudo tee "$CG/$1" >/dev/null || die "ecriture $CG/$1"
    echo "  $1 = $(cat "$CG/$1")"
}

cg_setup() {
    sudo mkdir -p "$CG" || die "creation $CG"
    cg_write cpu.max "$CG_CPU_MAX"
    cg_write cpu.weight "$CG_CPU_WEIGHT"
    cg_write memory.high "$(( mem_high_kb * 1024 ))"
    cg_write memory.max "$(( mem_max_kb * 1024 ))"
    cg_write memory.swap.max "$CG_SWAP_MAX"
    cg_write io.max "$CG_IO_MAX"
}

status() {
    host_state
    [ -d "$CG" ] || { echo "cgroup $CG absent"; return 0; }
    local f
    for f in cpu.max cpu.weight memory.high memory.max memory.swap.max io.max \
             memory.current memory.peak memory.events cpu.stat io.stat cgroup.procs; do
        echo "--- $f"
        cat "$CG/$f"
    done
}

scan() {
    # Un objet de taille nulle est le reste d'une compilation coupee net
    # (cgroup.kill, OOM) : make le croit a jour et seule l'edition de liens
    # echoue, des heures plus tard, en milliers de references indefinies.
    # Il est sans effet si la compilation de la recette s'est terminee
    # apres lui ; sinon la recette est a nettoyer. Une compilation en cours
    # apparait aussi comme suspecte.
    local work="$BUILD_DIR/tmp/work" stamps="$BUILD_DIR/tmp/stamps" rel pn n newest st
    [ -d "$work" ] || die "$work absent"
    find "$work" -name '*.o' -size 0 -printf '%h\n' 2>/dev/null \
        | awk -F/ -v w="$work/" '{sub(w, ""); split($0, p, "/"); print p[1] "/" p[2] "/" p[3]}' \
        | sort -u | while read -r rel; do
        pn=$(echo "$rel" | awk -F/ '{print $2}')
        n=$(find "$work/$rel" -name '*.o' -size 0 | wc -l)
        newest=$(find "$work/$rel" -name '*.o' -size 0 -printf '%T@\n' | sort -n | awk 'END{print int($1)}')
        st=$(find "$stamps/$(dirname "$rel")" -maxdepth 1 -name "$(basename "$rel").do_compile.*" \
                 ! -name '*sigdata*' -printf '%T@\n' 2>/dev/null | sort -n | awk 'END{print int($1)}')
        if [ -n "$st" ] && [ "$st" -ge "$newest" ]; then
            printf '%-50s %4d objets vides  sans effet (compilation terminee apres)\n' "$rel" "$n"
        else
            printf '%-50s %4d objets vides  SUSPECT : jetson-build.sh -c clean %s\n' "$rel" "$n" "$pn"
        fi
    done
}

dry=0
if [ "${1:-}" = "--after" ]; then
    [ $# -ge 4 ] || usage
    after_pid=$2
    after_log=$3
    shift 3
    echo "attente de la fin du processus $after_pid"
    while kill -0 "$after_pid" 2>/dev/null; do sleep 60; done
    grep -q '^ERROR' "$after_log" && die "le build precedent a echoue ($after_log), rien n'est enchaine"
    grep -q 'all succeeded' "$after_log" || die "le build precedent n'a pas termine avec succes ($after_log)"
    echo "build precedent reussi, demarrage"
fi
case "${1:-}" in
    --version) echo "jetson-build.sh $VERSION"; exit 0 ;;
    status) status; exit 0 ;;
    scan) scan; exit 0 ;;
    --dry-run) dry=1; shift ;;
    -h|--help|"") usage ;;
esac
[ $# -ge 1 ] || usage

echo "jetson-build.sh $VERSION"
budget
echo "BB_NUMBER_THREADS=$BB_NUMBER_THREADS PARALLEL_MAKE=$PARALLEL_MAKE BB_LOADFACTOR_MAX=$BB_LOADFACTOR_MAX"
if [ "$dry" -eq 1 ]; then
    echo "cgroup $CG : cpu.max=$CG_CPU_MAX cpu.weight=$CG_CPU_WEIGHT memory.high=${mem_high_kb}k memory.max=${mem_max_kb}k memory.swap.max=$CG_SWAP_MAX io.max=$CG_IO_MAX"
    echo "commande : nice -n 19 bitbake $*  (dans $BUILD_DIR)"
    exit 0
fi

cg_setup
echo $$ | sudo tee "$CG/cgroup.procs" >/dev/null || die "deplacement dans $CG"
grep -qx '0::/yocto-build' "/proc/$$/cgroup" || die "processus hors de $CG : $(cat /proc/$$/cgroup)"
echo "cgroup : $(cat /proc/$$/cgroup)"

set +eu
# shellcheck disable=SC1090
. "$OE_INIT" "$BUILD_DIR" >/dev/null
rc=$?
set -eu
[ "$rc" -eq 0 ] || die "oe-init-build-env ($rc)"

# Un serveur bitbake deja lance a pu naitre hors du cgroup : on l'arrete
# pour que le suivant demarre dedans.
if [ -S "$BUILD_DIR/bitbake.sock" ]; then
    bitbake -m >/dev/null 2>&1 || true
fi

exec nice -n 19 bitbake "$@"
