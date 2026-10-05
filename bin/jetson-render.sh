#!/bin/bash
# SPDX-License-Identifier: MIT
#
# jetson-render.sh - flame graph et heatmap a partir d'un `perf script`.
#
# Usage :
#   jetson-render.sh PERF_SCRIPT OUTDIR [options de jetson-heatmap.py]
#
# Produit dans OUTDIR : stacks.folded, flamegraph.svg, heatmap.svg.
# RENDER_TITLE et RENDER_SUBTITLE titrent les deux images.
# FlameGraph (Brendan Gregg, CDDL-1.0) est epingle sur FLAMEGRAPH_REV.
#
# Historique :
#   0.1.1  "(anonymous namespace)" reecrit avant repliement :
#          stackcollapse-perf coupe au premier "(" et vidait ces frames
#   0.1.0  premiere version
#
# Maintainer: Aurelien DESBRIERES <aurelien@hackers.camp>

set -euo pipefail

VERSION="0.1.1"
FLAMEGRAPH_REV="${FLAMEGRAPH_REV:-41fee1f99f9276008b7cd112fca19dc3ea84ac32}"
FG_DIR="${FG_DIR:-/tmp/flamegraph-$FLAMEGRAPH_REV}"
RENDER_TITLE="${RENDER_TITLE:-CPU flame graph}"
RENDER_SUBTITLE="${RENDER_SUBTITLE:-}"
HERE=$(cd "$(dirname "$0")" && pwd)

die() { echo "jetson-render: $*" >&2; exit 1; }

case "${1:-}" in
    --version) echo "jetson-render.sh $VERSION"; exit 0 ;;
    -h|--help|"") sed -n '6,12p' "$0"; exit 2 ;;
esac
[ $# -ge 2 ] || die "usage : jetson-render.sh PERF_SCRIPT OUTDIR [options]"
in=$1
out=$2
shift 2
[ -r "$in" ] || die "$in illisible"
mkdir -p "$out"

if [ ! -d "$FG_DIR/.git" ]; then
    git clone --quiet https://github.com/brendangregg/FlameGraph.git "$FG_DIR" || die "clone FlameGraph"
fi
git -C "$FG_DIR" checkout --quiet "$FLAMEGRAPH_REV" || die "FlameGraph $FLAMEGRAPH_REV introuvable"

# stackcollapse-perf coupe les noms au premier "(" : une fonction en
# espace de noms anonyme y perd tout son nom et disparait du graphe.
sed 's/(anonymous namespace)/{anonymous}/g' "$in" \
    | "$FG_DIR/stackcollapse-perf.pl" > "$out/stacks.folded"
"$FG_DIR/flamegraph.pl" --title "$RENDER_TITLE" --subtitle "$RENDER_SUBTITLE" \
    --width 1200 --colors java "$out/stacks.folded" > "$out/flamegraph.svg"
"$HERE/jetson-heatmap.py" "$in" -o "$out/heatmap.svg" \
    --title "CPU time by function" --subtitle "$RENDER_SUBTITLE" "$@"

echo "jetson-render.sh $VERSION : $out/flamegraph.svg $out/heatmap.svg"
