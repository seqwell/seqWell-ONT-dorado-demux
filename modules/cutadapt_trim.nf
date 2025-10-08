
process CUTADAPT_TRIM {
    tag "$params.pool_ID"
    publishDir path: "${params.outdir}/demuxed_fastq", mode: 'copy', pattern: "*seqWell*"
    publishDir path: "${params.outdir}/demuxed_fastq", mode: 'copy', pattern: "unknown.fastq.gz"
    publishDir path: "${params.outdir}/other/ME_tagged_fastq", mode: 'copy', pattern: '*tag*'
  

    input:
    tuple val(pair_id), path(fq)
 

    output:
    path("*.ME.tagged.fastq.gz")
    path("{*seqWell,*.ME.tagged}.fastq.gz"),     emit: fq
    

    script:
    """
    
    # Step 1: Adapter trim #-g (5′ adapter = anchored at the start of the read)
      cutadapt \
            -g AGATGTGTATAAGAGACAG \
            -g AATGATACGGCGACCACCGAGATCTACAC \
            --minimum-length ${params.length_filter} \
            -e 0.106 \
            -O  12 \
            --report=minimal \
            -o ${pair_id}.step1.fastq.gz \
            ${fq} >  ${pair_id}.cutadapt_report.step1.txt


    # Step 2: Tag ME detection, -b (anywhere = “both ends” / internal adapter)
      cutadapt \
            -b AGATGTGTATAAGAGACAG \
            -b CTGTCTCTTATACACATCT \
            -e 0 \
            -O 19 \
            --action=none \
            --report=minimal \
            --untrimmed-output ${pair_id}.seqWell.fastq.gz \
            -o ${pair_id}.ME.tagged.fastq.gz \
            ${pair_id}.step1.fastq.gz > ${pair_id}.cutadapt_report.txt
    
    rm *step*.fastq.gz
    
    """
}
