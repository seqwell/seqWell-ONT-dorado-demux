#!/usr/bin/env nextflow

include { SPLIT_FASTQ          } from './modules/split_input.nf'
include { SPLIT_BAM            } from './modules/split_input.nf'
include { DORADO_DEMUX         } from './modules/dorado_demux.nf'
include { COMBINE_BARCODES     } from './modules/combine_barcodes.nf'
include { COMBINE_BARCODES_BAM } from './modules/combine_barcodes.nf'
include { BAM_TO_FASTQ         } from './modules/bam_to_fastq.nf'
include { EXTRACT_HEADER       } from './modules/extract_header.nf'
include { REHEADER_READS       } from './modules/reheader_reads.nf'
include { CUTADAPT_TRIM        } from './modules/cutadapt_trim.nf'
include { FILTER_BAM_BY_FASTQ  } from './modules/filter_bam_by_fastq.nf'
include { DEMUX_SUMMARIZE      } from './modules/demux_summarize.nf'
include { NANOSTAT             } from './modules/nanostat.nf'
include { MULTIQC              } from './modules/multiQC.nf'
include { READ_LENGTH          } from './modules/read_length.nf'
include { NANOSTAT_BASES       } from './modules/nanostat_bases.nf'
include { MERGE_DEMUX_BASES    } from './modules/merge_demux_bases.nf'


// Strip .bam / .fastq / .fq / .fastq.gz / .fq.gz to get the sample (or chunk) ID
def sampleIdOf(f) {
    return f.name.replaceAll(/\.(bam|fastq|fq)(\.gz)?$/, '')
}

// Normalise a process output that may be a single path or a list of paths
def asList(x) {
    return (x instanceof List) ? x : [x]
}


workflow {

    main:

    // ---------------------------------------------------------------
    // Validate data_type param
    // ---------------------------------------------------------------
    if (!params.data_type) {
        error "Please specify --data_type [bam|fastq]"
    }
    if (!['bam', 'fastq'].contains(params.data_type)) {
        error "Invalid --data_type '${params.data_type}'. Must be 'bam' or 'fastq'."
    }

    def use_bam = (params.data_type == 'bam')

    // ---------------------------------------------------------------
    // Resolve input files eagerly so we know how many there are
    //   fastq: accepts .fastq, .fq, .fastq.gz, .fq.gz
    // ---------------------------------------------------------------
    def pattern = use_bam
        ? "${params.input}/*.bam"
        : "${params.input}/*.{fastq,fq,fastq.gz,fq.gz}"

    def input_files = files(pattern)
    if (input_files.isEmpty()) {
        error "No input files found matching: ${pattern}"
    }

    def n_parts  = params.split_n as Integer
    def do_split = (input_files.size() == 1 && n_parts > 1)

    if (use_bam) {
        log.info "data_type=bam  →  BAM input: dorado demux (BAM) → BAM-to-FASTQ → cutadapt → filter demux-BAM by cutadapt-FASTQ read IDs"
    } else {
        log.info "data_type=fastq  →  FASTQ input (.fastq or .fastq.gz): extract headers → dorado demux → reheader → cutadapt → FASTQ output only (no BAM created)"
    }
    log.info "Found ${input_files.size()} input file(s)" +
             (do_split ? " → single input, splitting into ${n_parts} chunks for dorado" : " → no splitting")

    def raw_ch = channel.fromList(input_files)
                   .map { f -> tuple(sampleIdOf(f), f) }


    // ---------------------------------------------------------------
    // Step 0: If only ONE input file, split into n_parts chunks
    //   Each chunk becomes its own dorado job; COMBINE_BARCODES(_BAM)
    //   already merges multiple demux dirs back into per-barcode files.
    //   Chunk IDs look like "<sample>.part_001".
    // ---------------------------------------------------------------
    def input_ch = raw_ch
    if (do_split) {
        def chunk_out = channel.empty()
        if (use_bam) {
            SPLIT_BAM(raw_ch, n_parts)
            chunk_out = SPLIT_BAM.out.chunks
        } else {
            SPLIT_FASTQ(raw_ch, n_parts)
            chunk_out = SPLIT_FASTQ.out.chunks
        }
        input_ch = chunk_out
                     .flatMap { _id, chunks -> asList(chunks) }
                     .map { c -> tuple(sampleIdOf(c), c) }
    }

    def barcode_fasta    = file(params.barcodes)
    def arrangement_toml = file(params.arrangement_toml)


    // ---------------------------------------------------------------
    // Step 1: Demux (one job per input file, or per chunk)
    //   bam input   → dorado emits BAM dir only (--no emit-fastq)
    //   fastq input → dorado emits FASTQ dir only (--emit-fastq)
    // ---------------------------------------------------------------
    DORADO_DEMUX(input_ch, barcode_fasta, arrangement_toml)

    // Set inside whichever branch runs, consumed by the shared QC steps
    def trimmed_fq_ch = channel.empty()   // raw CUTADAPT_TRIM.out.fq
    def demuxed_ch    = channel.empty()   // tuple(sample_id, trimmed_fastq)


    // ================================================================
    //  BAM INPUT BRANCH
    // ================================================================
    if (use_bam) {

        // -----------------------------------------------------------
        // Step 2 (BAM): Combine per-sample BAM demux dirs → per-barcode BAMs
        // -----------------------------------------------------------
        COMBINE_BARCODES_BAM(DORADO_DEMUX.out.bam_dir.collect())

        def bam_barcode_ch = COMBINE_BARCODES_BAM.out.bam
                               .flatMap { bams -> asList(bams) }
                               .filter { bam -> bam.name.endsWith('.bam') }
                               .map { bam -> tuple(bam.baseName, bam) }

        // -----------------------------------------------------------
        // Step 3 (BAM): Convert each per-barcode demuxed BAM → FASTQ
        //   This FASTQ is used as input to cutadapt.
        //   No header extraction is needed for BAM input.
        // -----------------------------------------------------------
        BAM_TO_FASTQ(bam_barcode_ch)

        // -----------------------------------------------------------
        // Step 4 (BAM): Cutadapt trim on the converted FASTQ
        // -----------------------------------------------------------
        CUTADAPT_TRIM(BAM_TO_FASTQ.out.fastq)
        trimmed_fq_ch = CUTADAPT_TRIM.out.fq

        // trimmed_ch keyed by bare barcode ID
        // e.g. "barcode001.seqWell.fastq.gz" → key "barcode001"
        // This must match bam_barcode_ch which is also keyed by "barcode001"
        def base_trimmed_ch = trimmed_fq_ch
                                .flatMap { fqs -> asList(fqs) }
                                .filter { fq -> !fq.name.contains('tagged') && fq.size() > 20 }

        def trimmed_ch = base_trimmed_ch
                           .map { fq -> tuple(fq.baseName.replace('.seqWell.fastq', ''), fq) }

        def trimmed_ch_for_nanostat = base_trimmed_ch
                                        .map { fq -> tuple(fq.baseName.replace('.fastq', ''), fq) }

        // -----------------------------------------------------------
        // Step 5 (BAM): Split the demux-BAM to match cutadapt-FASTQ results
        //   Join on bare barcode ID so the keys match on both sides:
        //     bam_barcode_ch key: "barcode001"
        //     trimmed_ch key:     "barcode001"
        //   Then subset the BAM to only reads whose names appear in the FASTQ,
        //   propagating cutadapt adapter/length/ME-tag filtering onto the BAM.
        // -----------------------------------------------------------
        def bam_fastq_ch = bam_barcode_ch.join(trimmed_ch, by: 0)
                             // produces: tuple(barcode_id, bam, fastq)

        FILTER_BAM_BY_FASTQ(bam_fastq_ch)

        demuxed_ch = trimmed_ch_for_nanostat

    // ================================================================
    //  FASTQ INPUT BRANCH
    // ================================================================
    } else {

        // -----------------------------------------------------------
        // Step 2 (FASTQ): Extract FASTQ headers BEFORE demuxing
        //   awk extracts FASTQ header fields → uuid_tags.tsv
        //   Consumed by REHEADER_READS after demux to restore original headers.
        //   Runs per input file, or per chunk when the input was split.
        // -----------------------------------------------------------
        EXTRACT_HEADER(input_ch)
        def merged_tags = EXTRACT_HEADER.out.collect()

        // -----------------------------------------------------------
        // Step 3 (FASTQ): Combine per-sample FASTQ demux dirs → per-barcode FASTQs
        // -----------------------------------------------------------
        COMBINE_BARCODES(DORADO_DEMUX.out.fastq_dir.collect())

        def fastq_barcode_ch = COMBINE_BARCODES.out.fastq
                                 .flatMap { fqs -> asList(fqs) }
                                 .map { fq -> tuple(fq.baseName.replace('.fastq', ''), fq) }

        // -----------------------------------------------------------
        // Step 4 (FASTQ): Restore original header tags into demuxed FASTQs
        // -----------------------------------------------------------
        REHEADER_READS(fastq_barcode_ch, merged_tags)

        // -----------------------------------------------------------
        // Step 5 (FASTQ): Cutadapt trim — on reheadered FASTQ
        //   No BAM files are created for FASTQ input.
        // -----------------------------------------------------------
        CUTADAPT_TRIM(REHEADER_READS.out.fq)
        trimmed_fq_ch = CUTADAPT_TRIM.out.fq

        demuxed_ch = trimmed_fq_ch
                       .flatMap { fqs -> asList(fqs) }
                       .map { fq -> tuple(fq.baseName.replace('.fastq', ''), fq) }
    }


    // ---------------------------------------------------------------
    // Step 6: Downstream QC — runs on trimmed FASTQ (both branches)
    // ---------------------------------------------------------------
    DEMUX_SUMMARIZE(trimmed_fq_ch.collect())

    def valid_ids_ch = DEMUX_SUMMARIZE.out
                         .splitCsv()
                         .filter { row -> row[0].startsWith('barcode') || row[0] == 'unknown' }
                         .map { row -> tuple(row[0].trim(), true) }

    def filtered_ch = demuxed_ch
                        .join(valid_ids_ch, by: 0)
                        .map { sample_id, fq, _flag -> tuple(sample_id, fq) }

    READ_LENGTH(filtered_ch)
    NANOSTAT(filtered_ch)

    NANOSTAT_BASES(NANOSTAT.out.collect())

    def mqc_config = file("${projectDir}/assets/multiqc_config.yaml")
    MULTIQC(
        NANOSTAT.out.collect().mix(NANOSTAT_BASES.out.q10_bases).collect(),
        mqc_config
    )

    MERGE_DEMUX_BASES(DEMUX_SUMMARIZE.out, NANOSTAT_BASES.out.bases)


    // ===============================================================
    //  Completion summary — runs on success AND failure
    // ===============================================================
    onComplete:

    def ok         = workflow.success
    def stats      = workflow.stats
    def bar        = '=' * 72
    def outdir     = params.outdir ? file(params.outdir).toUriString() : "${workflow.launchDir}/results"
    def cmd        = workflow.commandLine
    def resume_cmd = cmd.contains('-resume') ? cmd : "${cmd} -resume"

    def summary = [
        '',
        bar,
        "  seqWell ONT Dorado Demux  —  ${ok ? 'COMPLETED SUCCESSFULLY ✅' : 'FAILED ❌'}",
        bar,
        "  Run name        : ${workflow.runName}",
        "  Session ID      : ${workflow.sessionId}",
        "  Pipeline rev    : ${workflow.revision ?: workflow.commitId ?: 'local / no git'}",
        "  Nextflow        : ${nextflow.version}",
        "  Profile         : ${workflow.profile}",
        "  Container       : ${workflow.containerEngine ?: 'none'}",
        '',
        "  Started         : ${workflow.start}",
        "  Finished        : ${workflow.complete}",
        "  Wall time       : ${workflow.duration}",
        "  CPU time        : ${stats.computeTimeFmt}",
        '',
        "  Tasks           : ${stats.succeededCount} succeeded, ${stats.cachedCount} cached, " +
            "${stats.failedCount} failed, ${stats.ignoredCount} ignored",
        '',
        "  Input settings",
        "    data_type     : ${params.data_type}",
        "    input         : ${params.input}",
        "    split_n       : ${params.split_n}",
        "    barcodes      : ${params.barcodes}",
        "    arrangement   : ${params.arrangement_toml}",
        '',
        "  Output dir      : ${outdir}",
        "  Work dir        : ${workflow.workDir}",
        "  Launch dir      : ${workflow.launchDir}",
        '',
        "  Command line    :",
        "    ${cmd}",
    ]

    if (!ok) {
        def report_lines = workflow.errorReport
            ? workflow.errorReport.readLines().take(15).collect { l -> "    ${l}" }
            : []
        def error_lines = workflow.errorMessage
            ? ["  Error           : ${workflow.errorMessage}"]
            : []
        summary = summary + [''] + error_lines + [
            "  Error report    :",
        ] + report_lines + [
            '',
            "  To resume from the last successful step:",
            "    ${resume_cmd}",
        ]
    }

    summary = summary + [bar, '']

    if (ok) {
        log.info summary.join('\n')
    } else {
        log.error summary.join('\n')
    }
}
