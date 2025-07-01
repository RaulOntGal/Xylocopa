#!/bin/bash

BOLD_CLI="$HOME/go/bin/BOLD-CLI"
OUTFILE="bold_data.fasta"

# Help message
function show_help {
    echo "BOLD FASTA sequence downloader"
    echo ""
    echo "Usage: $0 -t TAXON [-l LOCATION] [-m MARKER] [-o OUTPUT]"
    echo ""
    echo "Options:"
    echo "  -t     TAXON     Species name or taxa list (required)"
    echo "  -l     LOCATION  Geographic region (optional)"
    echo "  -m     MARKER    Barcode marker like COI-5P, matK, rbcL (optional)"
    echo "  -o     OUTPUT    Output filename (default: bold_data.fasta)"
    echo "  -h, --help       Show this help message"
    exit 1
}

# Parse arguments
while getopts "t:l:m:o:h" opt; do
  case $opt in
    t) TAXON="$OPTARG" ;;
    l) GEO="$OPTARG" ;;
    m) MARKER="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
    h) show_help ;;
    *) show_help ;;
  esac
done

if [ -z "$TAXON" ]; then
    echo "Error: -t TAXON is required."
    show_help
fi

# Debug
echo "DEBUG:"
echo "TAXON: $TAXON"
echo "GEO: $GEO"
echo "MARKER: $MARKER"
echo "OUTFILE: $OUTFILE"
echo ""

# Build command
CMD_ARGS=(-taxon "$TAXON" -output "$OUTFILE")
[ -n "$GEO" ] && CMD_ARGS+=(-geo "$GEO")
[ -n "$MARKER" ] && CMD_ARGS+=(-marker "$MARKER")

echo "Downloading ${GEO:-all locations} ${MARKER:-all markers} $TAXON sequences from BOLD..."
"$BOLD_CLI" "${CMD_ARGS[@]}"

# Convert to .fasta
cat "$OUTFILE" | cut -f2,20,22,72 | \
awk -F'\t' '{
  header = ">" $1;
  species = ($3 == "" || $3 == "-") ? $2 ".sp" : $3;
  seq = $4;
  print header " " species;
  for (i=1; i<=length(seq); i+=60) {
    print substr(seq, i, 60);
  }
}' | tail -n +3 > tmp_fasta

#Remove empty sequences
awk '
  BEGIN { skipped=0; kept=0; }
  /^>/ {
    if (seq_length > 0) {
      print header; print seq; kept++;
    } else if (NR != 1) {
      skipped++; skipped_headers = skipped_headers ? skipped_headers "\n" header : header;
    }
    header=$0; seq=""; seq_length=0; next;
  }
  {
    seq = seq $0; seq_length += length($0);
  }
  END {
    if (seq_length > 0) {
      print header; print seq; kept++;
    } else {
      skipped++; skipped_headers = skipped_headers ? skipped_headers "\n" header : header;
    }
    print "Sequences kept: " kept > "/dev/stderr";
    print "Sequences skipped (empty seq): " skipped > "/dev/stderr";
    if (skipped > 0) {
      print "Skipped sequence headers:" > "/dev/stderr";
      print skipped_headers > "/dev/stderr";
      print skipped_headers > "skipped_sequences.txt";
    }
  }
' tmp_fasta > $OUTFILE

rm tmp_fasta

echo "Final cleaned FASTA is saved as $OUTFILE"

