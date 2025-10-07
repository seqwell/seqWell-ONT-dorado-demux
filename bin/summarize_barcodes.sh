#!/bin/bash
set -euo pipefail
set -x  # for debugging

# Arguments
pool_id=${1:?Missing pool_id}
error_rate=${2:?Missing error_rate}
summary_file="${pool_id}_demux_report.csv"

# Initialize
declare -A barcode_counts           # Regular barcodes
total_reads=0
unknown_reads=0
unclassified_me_tagged_reads=0      # unclassified.ME.tagged files
me_tagged_reads=0                   # Combined ME-tagged reads from barcoded files
other_barcodes_reads=0

# Count reads per barcode
for file in *.fastq.gz; do
    barcode="${file%.fastq.gz}"

    # count reads safely
    reads=$(zcat "$file" 2>/dev/null | awk 'END{print NR/4}' 2>/dev/null || echo 0)

    if [[ "$barcode" == "unknown"* ]] || [[ "$barcode" == "unclassified"* ]]; then
        # Handle all unclassified/unknown files
        if [[ "$barcode" == "unclassified.ME.tagged" ]]; then
            # Unclassified reads with ME tags
            unclassified_me_tagged_reads=$((unclassified_me_tagged_reads + reads))
        else
            # Regular unclassified/unknown reads
            unknown_reads=$((unknown_reads + reads))
        fi
    elif [[ "$barcode" == *".ME.tagged" ]]; then
        # ME-tagged barcodes: combine into single category
        me_tagged_reads=$((me_tagged_reads + reads))
    else
        # Regular barcodes (should not contain "unclassified" or "unknown")
        barcode_counts["$barcode"]=$reads
    fi
done

# Calculate total reads (ALL reads)
for count in "${barcode_counts[@]}"; do
    total_reads=$((total_reads + count))
done
total_reads=$((total_reads + unknown_reads + unclassified_me_tagged_reads + me_tagged_reads))

# Compute average reads per barcode for regular barcodes
num_barcodes=${#barcode_counts[@]}
avg_reads=0
if (( num_barcodes > 0 )); then
    sum_reads=0
    for r in "${barcode_counts[@]}"; do
        sum_reads=$((sum_reads + r))
    done
    avg_reads=$((sum_reads / num_barcodes))
fi 

# Threshold = 10% of average
threshold=$((avg_reads / 10))

# Categorize regular barcodes based on threshold
declare -A final_barcode_counts
for barcode in "${!barcode_counts[@]}"; do
    count=${barcode_counts[$barcode]}
    if (( count < threshold )); then
        other_barcodes_reads=$((other_barcodes_reads + count))
    else
        final_barcode_counts["$barcode"]=$count
    fi
done

# Calculate totals for each category
regular_barcoded_reads=0
for count in "${final_barcode_counts[@]}"; do
    regular_barcoded_reads=$((regular_barcoded_reads + count))
done

# Calculate sum of only regular barcodes (for percentage calculation in barcode table)
regular_barcodes_sum=0
for count in "${final_barcode_counts[@]}"; do
    regular_barcodes_sum=$((regular_barcodes_sum + count))
done

# Calculate percentages for summary section (using total_reads as denominator)
unknown_pct=$(awk -v u="$unknown_reads" -v t="$total_reads" 'BEGIN{printf "%.2f", (t>0)?u*100/t:0}')
unclassified_me_pct=$(awk -v m="$unclassified_me_tagged_reads" -v t="$total_reads" 'BEGIN{printf "%.2f", (t>0)?m*100/t:0}')
regular_barcoded_pct=$(awk -v r="$regular_barcoded_reads" -v t="$total_reads" 'BEGIN{printf "%.2f", (t>0)?r*100/t:0}')
me_tagged_pct=$(awk -v m="$me_tagged_reads" -v t="$total_reads" 'BEGIN{printf "%.2f", (t>0)?m*100/t:0}')
other_barcodes_pct=$(awk -v o="$other_barcodes_reads" -v t="$total_reads" 'BEGIN{printf "%.2f", (t>0)?o*100/t:0}')

# Generate CSV report
{
    echo "Total Reads:,${total_reads}"
    echo "Total Demuxed Reads:,${regular_barcoded_reads},${regular_barcoded_pct}%"
    echo "ME-tagged Reads (demuxed reads, removed):,${me_tagged_reads},${me_tagged_pct}%"
    echo "Unclassified Reads No ME-tagged:,${unknown_reads},${unknown_pct}%"
    echo "Unclassified ME-tagged Reads:,${unclassified_me_tagged_reads},${unclassified_me_pct}%"
    echo "Other Barcodes (count < 10% of avg):,${other_barcodes_reads},${other_barcodes_pct}%"
    echo ""
    echo ""
    echo "Barcode,Read_Count,Percent_of_Total"

    # Regular barcodes sorted - use regular_barcodes_sum for percentages
    for barcode in $(printf '%s\n' "${!final_barcode_counts[@]}" | sort -V); do
        count=${final_barcode_counts[$barcode]}
        pct=$(awk -v c="$count" -v t="$regular_barcodes_sum" 'BEGIN{printf "%.2f", (t>0)?c*100/t:0}')
        echo "${barcode},${count},${pct}"
    done

} > "$summary_file"

echo "Successfully generated: $summary_file"
