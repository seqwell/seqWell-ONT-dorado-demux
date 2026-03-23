process EXTRACT_HEADER {
    tag "$sample_id"
    //publishDir "${params.outdir}/header_tags", mode: 'copy'

    input:
    tuple val(sample_id), path(fastq)

    output:
    path "${sample_id}.uuid_tags.tsv"

    script:
    """
    zcat ${fastq} | awk 'NR%4==1 {
        uuid = substr(\$1, 2)
        tags = ""
        for (i=2; i<=NF; i++) tags = tags " " \$i
        print uuid "\\t" tags
    }' > ${sample_id}.uuid_tags.tsv
    """
}