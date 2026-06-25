process NANOSTAT_BASES {
   // publishDir "${params.outdir}/multiqc_custom", mode: 'copy'

    input:
    path(nanostat_files)

    output:
    path("total_bases_mqc.tsv")

    script:
    """
    echo -e "# plot_type: 'table'" > total_bases_mqc.tsv
    echo -e "# section_name: 'Total Bases per Sample'" >> total_bases_mqc.tsv
    echo -e "# description: 'Exact total bases from NanoStat per demuxed barcode'" >> total_bases_mqc.tsv
    echo -e "Sample\tTotal Bases" >> total_bases_mqc.tsv

    for f in ${nanostat_files}; do
        sample=\$(basename \$f _nanostat.txt)
        bases=\$(grep "Total bases:" \$f | awk '{gsub(/,/,""); printf "%d", \$NF}')
        echo -e "\${sample}\t\${bases}" >> total_bases_mqc.tsv
    done
    """
}