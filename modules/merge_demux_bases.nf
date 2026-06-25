process MERGE_DEMUX_BASES {
    tag "${params.pool_ID}"

    publishDir "${params.outdir}/demux_summary", mode: 'copy'

    input:
    path(demux_csv)
    path(bases_tsv)

    output:
    path "${params.pool_ID}_demux_summary_report.csv", emit: merged_csv

    script:
    """
    merge_demux_bases.sh ${demux_csv} ${bases_tsv} ${params.pool_ID}_demux_summary_report.csv
    """
}
