process NANOSTAT_BASES {

    input:
    path nanostat_files

    output:
    path("total_bases_mqc.tsv"), emit: bases
    path("bases_q10_mqc.tsv"),   emit: q10_bases

    script:
    """
    echo -e "# plot_type: 'table'" > total_bases_mqc.tsv
    echo -e "# section_name: 'Total Bases per Sample'" >> total_bases_mqc.tsv
    echo -e "# description: 'Exact total bases from NanoStat per demuxed barcode'" >> total_bases_mqc.tsv
    echo -e "Sample\tTotal Bases" >> total_bases_mqc.tsv

    echo -e "# plot_type: 'table'" > bases_q10_mqc.tsv
    echo -e "# section_name: 'Per-sample NanoStat Q10 Read Quality Summary'" >> bases_q10_mqc.tsv
    echo -e "# description: 'Total reads, total bases, and Q10 stats from NanoStat per demuxed barcode'" >> bases_q10_mqc.tsv
    echo -e "Sample\tTotal Reads\tTotal Bases\tReads >Q10\tPct >Q10\tMb >Q10" >> bases_q10_mqc.tsv

    ls *_nanostat.txt > file_list.txt

    while read f; do
        sample=\$(basename "\$f" _nanostat.txt)

        total_reads=\$(awk '/Number of reads:/ {gsub(/,/,"",\$NF); print \$NF}' "\$f")
        bases=\$(awk '/Total bases:/ {gsub(/,/,"",\$NF); print \$NF}' "\$f")

        q10_reads=\$(awk '/^>Q10:/ {gsub(/,/,"",\$2); print \$2}' "\$f")
        q10_pct=\$(awk '/^>Q10:/ {gsub(/[()%]/,"",\$3); print \$3}' "\$f")
        q10_mb=\$(awk '/^>Q10:/ {gsub(/Mb/,"",\$NF); print \$NF}' "\$f")

        echo -e "\${sample}\t\${bases}" >> total_bases_mqc.tsv
        echo -e "\${sample}\t\${total_reads}\t\${bases}\t\${q10_reads}\t\${q10_pct}\t\${q10_mb}" >> bases_q10_mqc.tsv
    done < file_list.txt
    """
}