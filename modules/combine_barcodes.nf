process COMBINE_BARCODES {
tag "combine_barcodes"
container 'ubuntu:22.04'

//publishDir "${params.outdir}/merged_fastq", mode: 'copy'

input:
path dummy  // placeholder to trigger process once

output:
path ("{barcode*,unclassified}.fastq.gz")

script:
"""
#!/bin/bash
set -euo pipefail
shopt -s nullglob

# Detect all directories ending with _Demux in the current folder
dirs=( *_Demux )

if (( \${#dirs[@]} == 0 )); then
    echo "No Demux directories found, exiting."
    exit 1
fi

echo "Found Demux directories: \${dirs[@]}"

# Loop over barcodes 001–096
for i in \$(seq -w 001 384); do
    out="barcode\${i}.fastq.gz"
    files=()

    for d in "\${dirs[@]}"; do
        for f in "\$d"/*_sw_barcode\${i}.fastq; do
            files+=("\$f")
        done
    done

    if (( \${#files[@]} )); then
        echo "Combining \${#files[@]} files for barcode\${i} → \$out"
        cat "\${files[@]}" | gzip > "\$out"
    fi
done

# Combine unclassified reads
files=()
for d in "\${dirs[@]}"; do
    for f in "\$d"/*_unclassified.fastq; do
        files+=("\$f")
    done
done

if (( \${#files[@]} )); then
    echo "Combining \${#files[@]} unclassified files → unclassified.fastq.gz"
    cat "\${files[@]}" | gzip > "unclassified.fastq.gz"
fi
"""


}

