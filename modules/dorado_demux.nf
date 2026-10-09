process DORADO_DEMUX {
    tag "$sample_id"

    // publishDir path: "${params.outdir}/dorado_demux/${sample_id}_dorado_out", mode: 'copy'

    input:
    tuple val(sample_id), path(input_file)
    each path(barcode_fasta)
    each path(arrangement_toml)

    output:
    path("${sample_id}_Demux_bam"),   emit: bam_dir,   optional: true
    path("${sample_id}_Demux_fastq"), emit: fastq_dir, optional: true


    script:
    if (params.data_type == 'bam')
    """
    # BAM input: demux to BAM only (preserves original aux tags MM/ML methylation, RG, etc.)
    # FASTQ conversion is performed separately via BAM_TO_FASTQ after demux
    # --threads pinned to task.cpus: dorado's default (0) uses ALL host cores,
    # which oversubscribes when Batch packs several jobs on one instance
    dorado demux ${input_file} \\
        --threads ${task.cpus} \\
        --output-dir ${sample_id}_Demux_bam \\
        --kit-name sw \\
        --barcode-arrangement ${arrangement_toml} \\
        --barcode-sequences ${barcode_fasta}
    """

    else
    """
    # FASTQ input (.fastq or .fastq.gz): emit plain FASTQ only (no BAM branch for FASTQ input)
    dorado demux ${input_file} \\
        --threads ${task.cpus} \\
        --output-dir ${sample_id}_Demux_fastq \\
        --kit-name sw \\
        --barcode-arrangement ${arrangement_toml} \\
        --barcode-sequences ${barcode_fasta} \\
        --emit-fastq

    """
}
