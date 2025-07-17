#!/bin/bash

set -euo pipefail

DEBUG=0
INPUT=""
OUTPUT_DIR=""

usage() {
cat <<EOF
Usage: $0 [options] <input.fasta>

Splits a FASTA file into one file per species and writes a species list.

- Creates a directory named after the input file (without .fasta)
- Inside that directory:
    - species_list.txt : list of unique species names and sequence counts
    - <species>.fasta  : one file per species (species name only)

Options:
  -h, --help       Show this help message and exit
  -d, --debug      Enable debug output

Arguments:
  <input.fasta>    Input FASTA file (mandatory)

Example:
  bash $0 -d sequences.fasta
EOF
}

log_debug() {
  if [[ "$DEBUG" -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--debug)
      DEBUG=1
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z "$INPUT" ]]; then
        INPUT="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "Error: input FASTA file is required." >&2
  usage
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: input file '$INPUT' not found." >&2
  exit 1
fi

BASENAME="$(basename "$INPUT" .fasta)"
OUTPUT_DIR="${BASENAME}"

mkdir -p "$OUTPUT_DIR"

log_debug "Input file: $INPUT"
log_debug "Output directory: $OUTPUT_DIR"

# Step 1: convert to 2-line fasta if needed and clean CR chars
TMP_FASTA="$OUTPUT_DIR/tmp_2line.fasta"

log_debug "Converting input fasta to 2-line fasta format and removing carriage returns..."
awk '
BEGIN {header=""; seq=""}
{
    # Remove \r here to avoid trailing carriage returns
    gsub(/\r/, "", $0)
    if ($0 ~ /^>/) {
        if (header != "") {
            print header
            print seq
        }
        header=$0
        seq=""
    } else {
        seq=seq""$0
    }
}
END {
    if (header != "") {
        print header
        print seq
    }
}' "$INPUT" > "$TMP_FASTA"

# Step 2: extract species list with counts
log_debug "Extracting species list with sequence counts..."
awk 'NR%2==1 {
    sub(/^>/,"")
    gsub(/\r/,"")
    species=""
    for (i=2; i<=NF; i++) species = (species ? species" " : "") $i
    count[species]++
}
END {
    for (s in count)
        print s "\t" count[s]
}' "$TMP_FASTA" | sort > "$OUTPUT_DIR/species_list.txt"

echo "Species list written to: $OUTPUT_DIR/species_list.txt"

# Step 3: split sequences by species
log_debug "Splitting sequences by species..."
while IFS=$'\t' read -r species count; do
    safe_name=$(echo "$species" | tr ' /()[]:,' '________')
    out_file="$OUTPUT_DIR/${safe_name}.fasta"
    log_debug "Processing species: '$species' (count: $count) -> file: $out_file"

    awk -v s="$species" '
    NR%2==1 {
        header=$0
        sub(/^>/,"",header)
        split(header, a, " ")
        sp=""
        for (i=2; i<=NF; i++) sp = (sp ? sp" " : "") a[i]
    }
    NR%2==0 {
        if (sp == s) {
            print ">"header
            print $0
        }
    }' "$TMP_FASTA" >> "$out_file"
done < "$OUTPUT_DIR/species_list.txt"

rm -f "$TMP_FASTA"

echo "Sequences split by species into: $OUTPUT_DIR/"

