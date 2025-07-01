# Xylocopa Phylogeny Project

## Project Overview

This project aims to analyze the phylogeny of the genus *Xylocopa*. The workflow includes:

- Download genetic sequences for *Xylocopa* from BOLD and NCBI.
- Clean and standardize the data (FASTA format, remove duplicates, remove empty sequences).
- Separate sequences by species.
- Generate consensus sequences for each species.
- Align sequences and build gene trees.

## BOLD FASTA Downloader

I developed a bash script that automates downloading DNA sequences from the BOLD database in FASTA format, building on the [BOLD-CLI](https://github.com/CNuge/BOLD-CLI) tool.

Note: This script was developed and tested on the UCLA Hoffman2 high-performance computing cluster. It uses environment modules (e.g., module load) and may not run as-is standard desktop systems without modification. 

### Features

- Downloads sequences in FASTA format using BOLD-CLI.
- Allows filtering by taxon, geographic location, and barcode marker.
- Cleans and formats sequences, removing duplicates and empty sequences.
- Generates a .txt file listing sequences that are empty or inaccessible.

### Usage

Run the script from the terminal with the following options:

```bash
bash BOLD_FASTA.sh -t TAXON [-l LOCATION] [-m MARKER] [-o OUTPUT]

### Options:

-t TAXON: (required) Species name or taxa list.

-l LOCATION: (optional) Geographic region to filter sequences.

-m MARKER: (optional) Barcode marker (e.g., COI-5P, matK, rbcL).

-o OUTPUT: (optional) Output FASTA filename (default: bold_data.fasta).
