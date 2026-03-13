#!/usr/bin/env bash
# name-generator.sh — Generate creative agent names from themed pools
#
# Usage: ./scripts/name-generator.sh [N] [--theme THEME]
#        ./scripts/name-generator.sh --list-themes

set -euo pipefail

# --- Theme pools (all lowercase, hyphen-safe, no spaces) ---

THEME_callsigns=(
    maverick viper jester phoenix bandit ghost rebel cipher
    nomad sentinel falcon spectre raven hex storm vector
)

THEME_scientists=(
    euler gauss turing lovelace curie feynman dijkstra knuth
    shannon hopper babbage noether ramanujan erdos von-neumann
    hamilton rosalind ada
)

THEME_mythology=(
    prometheus athena hermes apollo icarus midas cassandra phoenix
    odysseus minerva loki freya anubis thoth valkyrie odin
)

THEME_heist=(
    safecracker lookout wheelman forger fixer ghost mastermind
    grifter hacker sleeper cleaner shadow inside-man torch
)

THEME_lab=(
    catalyst reagent crucible bunsen litmus pipette centrifuge
    spectrometer isotope oxidizer solvent distiller filament
    electrode prism
)

THEME_perf=(
    scheduler pipeline vectorizer unroller prefetch cache
    register allocator spiller fuser reorder eliminator
    inliner sinking hoister tiler partitioner balancer
)

ALL_THEMES=(callsigns scientists mythology heist lab perf)
DEFAULT_THEME="callsigns"

# --- Argument parsing ---

N=3
THEME="$DEFAULT_THEME"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list-themes)
            for t in "${ALL_THEMES[@]}"; do
                # Get the array for this theme
                ref="THEME_${t}[@]"
                names=("${!ref}")
                echo "$t (${#names[@]} names)"
            done
            exit 0
            ;;
        --theme)
            THEME="${2:?Missing theme name}"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [N] [--theme THEME]" >&2
            echo "       $0 --list-themes" >&2
            exit 1
            ;;
        *)
            N="$1"
            shift
            ;;
    esac
done

# --- Validate theme ---

ref="THEME_${THEME}[@]"
if ! declare -p "THEME_${THEME}" &>/dev/null; then
    echo "Error: Unknown theme '$THEME'" >&2
    echo "Available themes: ${ALL_THEMES[*]}" >&2
    exit 1
fi

pool=("${!ref}")

if (( N > ${#pool[@]} )); then
    echo "Error: Requested $N names but theme '$THEME' only has ${#pool[@]}" >&2
    exit 1
fi

if (( N < 1 )); then
    echo "Error: N must be at least 1" >&2
    exit 1
fi

# --- Shuffle and pick N names (without replacement) ---

# Use shuf if available, otherwise fall back to sort -R
if command -v shuf &>/dev/null; then
    printf '%s\n' "${pool[@]}" | shuf -n "$N"
else
    printf '%s\n' "${pool[@]}" | sort -R | head -n "$N"
fi
