#!/bin/bash

# --- Usage Info ---
usage() {
  echo "Usage: $0 -t <taxon> [-l <location>] [-m <marker>] [-o <output_file>]"
  echo "  -t  Taxon (required)"
  echo "  -l  Geographic location (optional)"
  echo "  -m  Marker/gene name (optional)"
  echo "  -o  Output file name (optional)"
  exit 1
}

# --- Default values ---
OUTPUT="ncbi_data.fasta"

# --- Parse command-line arguments ---
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -t) TAXON="$2"; shift ;;
    -l) LOCATION="$2"; shift ;;
    -m) MARKER="$2"; shift ;;
    -o) OUTPUT="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
  shift
done

# --- Check required argument ---
if [ -z "$TAXON" ]; then
  echo "Error: Taxon (-t) is required."
  usage
fi

# --- Build query string ---
QUERY=""
if [ -n "$MARKER" ]; then
  QUERY="${MARKER}[GENE]"
fi

if [ -n "$QUERY" ]; then
  QUERY="${QUERY} AND ${TAXON}[ORGN]"
else
  QUERY="${TAXON}[ORGN]"
fi

# --- Show debug info (always) ---
echo "===================="
echo "NCBI Query Debug Info"
echo "--------------------"
echo "Taxon     : $TAXON"
echo "Marker    : ${MARKER:-N/A}"
echo "Location  : ${LOCATION:-N/A}"
echo "Output    : $OUTPUT"
echo "Query     : $QUERY"
echo "Database  : nuccore"
echo "===================="
echo "Fetching sequences..."

# --- Temporary files ---
TMP_GB="tmp_sequences.gb"
TMP_FILTERED_GB="tmp_filtered.gb"

# --- Run search and fetch ---
esearch -db nuccore -query "$QUERY" | \
  efetch -format gb > "$TMP_GB"

# --- Filter GenBank by Location ---
awk -v RS="//\n" -v IGNORECASE=1 -v location="$LOCATION" '
    $0 ~ "/country=\"" location || $0 ~ "/geo_loc_name=\"" location { print $0 "//" }
' "$TMP_GB" > "$TMP_FILTERED_GB"

# --- Convert filtered GenBank to FASTA ---
grep "^ACCESSION" "$TMP_FILTERED_GB" | awk '{print $2}' > filtered_ids.txt
efetch -db nuccore -format fasta -id $(paste -sd, filtered_ids.txt) > "$OUTPUT"

# --- Count sequences ---
COUNT=$(grep -c "^>" "$OUTPUT")

# --- Report ---
echo "Download complete. $COUNT sequences matched."
echo "Saved to: $OUTPUT"

# --- Eliminate Temporal Files ---
rm "$TMP_GB"
rm "$TMP_FILTERED_GB"
rm filtered_ids.txt
