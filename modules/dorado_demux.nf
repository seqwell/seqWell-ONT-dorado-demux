
process DORADO_DEMUX {
    tag "$sample_id"
        
   // publishDir path: "${params.outdir}/dorado_demux_from_fq/${sample_id}_dorado_out",  mode: 'copy'     

    input:
    tuple val(sample_id), path(fq)
    each path(barcode_fasta)
    each path(arrangement_toml)

    output:
    path("${sample_id}_Demux")

    container 'genomicpariscentre/dorado:1.1.1'

    script:
    """
    dorado demux $fq \
    --output-dir ${sample_id}_Demux \
    --kit-name sw \
    --barcode-arrangement $arrangement_toml \
    --barcode-sequences $barcode_fasta \
    --emit-fastq

    """
}
