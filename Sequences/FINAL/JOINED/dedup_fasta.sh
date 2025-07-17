#!/bin/bash

# DEDUP - Compare FASTA accessions and extract shared and unique sequences
# Usage: ./dedup_fasta.sh [-o OUTPUT_BASENAME] file1.fasta file2.fasta

function show_help {
  echo "DEDUP - Compare accessions between two FASTA files, ignoring version numbers (e.g., .1, .2)"
  echo ""
  echo "Usage: $0 [-o OUTPUT_BASENAME] file1.fasta file2.fasta"
  echo ""
  echo "Options:"
  echo "  -o OUTPUT_BASENAME   Base name for output FASTA and lists (default: 'dedup_result')"
  echo "  -h, --help           Show this help message"
  echo ""
  echo "Environment:"
  echo "  DEBUG=1              Enable debug output"
  exit 0
}

OUTBASE="dedup_result"

# Parse options
while [[ "$1" =~ ^- ]]; do
  case "$1" in
    -h|--help) show_help ;;
    -o) OUTBASE="$2"; shift ;;
    *) echo "Unknown option: $1" && show_help ;;
  esac
  shift
done

# Check for required positional args
if [ "$#" -ne 2 ]; then
  echo "Error: Please provide two FASTA files to compare."
  show_help
fi

FASTA1="$1"
FASTA2="$2"

# Debug print function
debug() {
  [[ "$DEBUG" == "1" ]] && echo "[DEBUG] $*"
}

# Validate input files
for file in "$FASTA1" "$FASTA2"; do
  if [ ! -f "$file" ]; then
    echo "Error: File not found: $file"
    exit 1
  fi
done

# Extract accession numbers (strip .version)
extract_accessions() {
  grep '^>' "$1" | awk '{acc=$1; gsub(/^>/,"",acc); sub(/\..*$/, "", acc); print acc}' | sort -u
}

TMP1=$(mktemp)
TMP2=$(mktemp)

debug "Extracting accessions from $FASTA1"
extract_accessions "$FASTA1" > "$TMP1"

debug "Extracting accessions from $FASTA2"
extract_accessions "$FASTA2" > "$TMP2"

# Short base names
B1=$(basename "$FASTA1" .fasta)
B2=$(basename "$FASTA2" .fasta)

# Output list files
ONLY1="${B1}_unique.txt"
ONLY2="${B2}_unique.txt"
SHARED="${OUTBASE}_shared.txt"

# Compare and save accession sets
comm -23 "$TMP1" "$TMP2" > "$ONLY1"
comm -13 "$TMP1" "$TMP2" > "$ONLY2"
comm -12 "$TMP1" "$TMP2" > "$SHARED"

echo "Accessions only in $B1: $(wc -l < "$ONLY1")"
echo "Accessions only in $B2: $(wc -l < "$ONLY2")"
echo "Shared accessions:     $(wc -l < "$SHARED")"
echo ""
echo "Saved:"
echo "  $ONLY1"
echo "  $ONLY2"
echo "  $SHARED"

# Reusable function: extract sequences by base accession list
extract_from_fasta() {
  local fasta_file="$1"
  local id_file="$2"
  awk '
    BEGIN {
      while ((getline < "'"$id_file"'") > 0)
        ids[$1] = 1
    }
    /^>/ {
      acc = $1
      gsub(/^>/, "", acc)
      sub(/\..*$/, "", acc)
      keep = (acc in ids)
    }
    {
      if (keep) print
    }
  ' "$fasta_file"
}

# Output fasta
SHARED_FASTA="${OUTBASE}.fasta"
> "$SHARED_FASTA"

debug "Extracting sequences..."

# Extract from file1 only for shared
extract_from_fasta "$FASTA1" "$SHARED" >> "$SHARED_FASTA"

# Extract unique from their source
extract_from_fasta "$FASTA1" "$ONLY1" >> "$SHARED_FASTA"
extract_from_fasta "$FASTA2" "$ONLY2" >> "$SHARED_FASTA"

# Deduplicate by base accession (keep longest)
awk '
  function base_id(header) {
    gsub(/^>/, "", header)
    sub(/\..*$/, "", header)
    return header
  }

  /^>/ {
    if (seq != "") {
      acc = base_id(prev_header)
      if (length(seq) > length(best_seq[acc])) {
        best_seq[acc] = seq
        best_header[acc] = prev_header
      }
    }
    prev_header = $0
    seq = ""
    next
  }

  {
    seq = seq $0
  }

  END {
    if (seq != "") {
      acc = base_id(prev_header)
      if (length(seq) > length(best_seq[acc])) {
        best_seq[acc] = seq
        best_header[acc] = prev_header
      }
    }
    for (acc in best_seq) {
      print best_header[acc]
      s = best_seq[acc]
      for (i = 1; i <= length(s); i += 60)
        print substr(s, i, 60)
    }
  }
' "$SHARED_FASTA" > tmp_dedup && mv tmp_dedup "$SHARED_FASTA"

echo "Final deduplicated FASTA: $SHARED_FASTA"
