#!/bin/bash

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 file1.txt file2.txt [file3.txt ...]"
  exit 1
fi

# Extract species names from first file, ignore lines with "sp."
common=$(awk '{$NF=""; sub(/[ \t]+$/, ""); print}' "$1" | grep -v 'sp\.' | sort -u)

for f in "${@:2}"; do
  species=$(awk '{$NF=""; sub(/[ \t]+$/, ""); print}' "$f" | grep -v 'sp\.' | sort -u)
  common=$(comm -12 <(echo "$common") <(echo "$species"))
done

echo "$common" > species_list.txt
echo "Common species saved to species_list.txt"

