#!/bin/bash
set -euo pipefail

demux_csv=${1:?Missing demux_csv}
bases_tsv=${2:?Missing bases_tsv}
output_csv=${3:-merged_demux_report.csv}

declare -A barcode_bases

# load bases TSV, skip # comment lines and header
while IFS=$'\t' read -r sample bases; do
    [[ "$sample" == \#* ]] && continue
    [[ "$sample" == "Sample" ]] && continue
    barcode_bases["$sample"]="$bases"
done < "$bases_tsv"

# find the barcode data section in the demux csv and merge
{
    in_barcode_section=0
    while IFS= read -r line; do
        if [[ "$line" == "Barcode,Read_Count,Percent_of_Total" ]]; then
            in_barcode_section=1
            echo "Barcode,Read_Count,Percent_of_Total,Total_Bases"
            continue
        fi
        if (( in_barcode_section == 0 )); then
            echo "$line"
            continue
        fi
        # inner join on barcode (first field)
        barcode="${line%%,*}"
        [[ -v barcode_bases["$barcode"] ]] || continue
        echo "${line},${barcode_bases[$barcode]}"
    done < "$demux_csv"
} > "$output_csv"

echo "Successfully generated: $output_csv"
