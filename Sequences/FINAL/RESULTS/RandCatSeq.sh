#!/bin/bash

# Default output file
OUTPUT="concatenated_sequences.fasta"
DEBUG=0

function show_help {
  echo "Usage: $0 [-d] [-o OUTPUT] species_list.txt dir1 [dir2 ...]"
  echo "  -d          Enable debug output"
  echo "  -o OUTPUT   Specify output filename (default: concatenated_sequences.fasta)"
  echo "  -h          Show this help message"
  exit 0
}

# Parse options
while getopts ":do:h" opt; do
  case $opt in
    d) DEBUG=1 ;;
    o) OUTPUT="$OPTARG" ;;
    h) show_help ;;
    \?) echo "Invalid option: -$OPTARG" >&2; show_help ;;
    :) echo "Option -$OPTARG requires an argument." >&2; show_help ;;
  esac
done

shift $((OPTIND -1))

# Check minimum args
if [ "$#" -lt 2 ]; then
  echo "Error: Need species list and at least one directory."
  show_help
fi

SPECIES_LIST="$1"
shift

> "$OUTPUT"

extract_random_fasta() {
  local file="$1"
  local count
  count=$(grep -c '^>' "$file")
  if [ "$count" -eq 0 ]; then
    echo "Warning: No sequences found in $file" >&2
    return 1
  fi

  local n=$(( ( RANDOM % count ) + 1 ))

  awk -v seq="$n" '
    BEGIN { printing=0; seq_count=0 }
    /^>/ {
      seq_count++
      if (seq_count == seq) {
        printing=1
        print
        next
      } else if (seq_count > seq) {
        printing=0
        exit
      }
    }
    printing { print }
  ' "$file"
}

while IFS= read -r species; do
  filename="${species// /_}.fasta"
  found=0
  concatenated_sequence=""

  for dir in "$@"; do
    filepath="$dir/$filename"
    if [ -f "$filepath" ]; then
      ((found++))
      [[ "$DEBUG" == "1" ]] && echo "Found $filename in $dir"

      # Extract random fasta sequence and strip header line
      seq=$(extract_random_fasta "$filepath" | tail -n +2 | tr -d '\n')

      concatenated_sequence+="$seq"
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "File for species '$species' not found in any directory."
  else
    # Print concatenated fasta with species name as accession
    echo ">$species" >> "$OUTPUT"
    echo "$concatenated_sequence" | fold -w 60 >> "$OUTPUT"
  fi

done < "$SPECIES_LIST"

echo "Concatenated sequences saved to $OUTPUT"
