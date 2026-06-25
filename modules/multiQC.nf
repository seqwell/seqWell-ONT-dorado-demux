process MULTIQC {

    publishDir path: "${params.outdir}/multiQC", mode: 'copy'

    input:
    path(nanoplot_dirs)
    path(mqc_config)

    output:
    path "*multiqc_report.html"

    script:
    """
    multiqc . --config ${mqc_config} -o multiqc_report
    sed -i 's/Total Bases()/Total Bases(bp)/g' \
        multiqc_report/multiqc_report.html
    mv multiqc_report/multiqc_report.html ${params.pool_ID}_ONT_multiqc_report.html
    """
}