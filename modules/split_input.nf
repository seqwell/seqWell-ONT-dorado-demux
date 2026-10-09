// Split a single FASTQ (.fastq or .fastq.gz) into n_parts roughly equal chunks.
// seqkit reads plain or gzipped input directly; --extension .gz forces gzipped chunks.
// Output: chunks/<sample_id>.part_001.fastq.gz ...
// Container: quay.io/biocontainers/seqkit
process SPLIT_FASTQ {
    tag "${sample_id}"
    cpus 4

    input:
    tuple val(sample_id), path(fq)
    val n_parts

    output:
    tuple val(sample_id), path("chunks/*.part_*.gz"), emit: chunks

    script:
    """
    seqkit split2 \\
        --by-part ${n_parts} \\
        --threads ${task.cpus} \\
        --extension .gz \\
        --out-dir chunks \\
        ${fq}
    """
}


// Split a single unaligned BAM into n_parts chunks, round-robin by record,
// each chunk carrying the full header (RG, PG, etc.). Aux tags (MM/ML) preserved.
// One pass, no read counting; each chunk is written by its own samtools process.
// Output: chunks/<sample_id>.part_000.bam ...
// Container: quay.io/biocontainers/samtools:1.21 (busybox base: uses awk, not GNU split)
process SPLIT_BAM {
    tag "${sample_id}"
    cpus 4

    input:
    tuple val(sample_id), path(bam)
    val n_parts

    output:
    tuple val(sample_id), path("chunks/*.part_*.bam"), emit: chunks

    script:
    """
    mkdir -p chunks
    samtools view -H ${bam} > header.sam

    samtools view -@ 2 ${bam} \\
        | awk -v n=${n_parts} -v pre="chunks/${sample_id}.part_" '
            {
                r = (NR - 1) % n
                if (!(r in cmd)) cmd[r] = sprintf("cat header.sam - | samtools view -b -o %s%03d.bam -", pre, r)
                print | cmd[r]
            }
            END { for (r in cmd) close(cmd[r]) }'
    """
}
