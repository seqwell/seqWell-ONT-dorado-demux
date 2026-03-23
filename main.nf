nextflow.enable.dsl = 2


include { DORADO_DEMUX } from './modules/dorado_demux.nf'
include { COMBINE_BARCODES } from './modules/combine_barcodes.nf'
include { EXTRACT_HEADER   } from './modules/extract_header.nf'
include { REHEADER_READS   } from './modules/reheader_reads.nf'
include { CUTADAPT_TRIM } from './modules/cutadapt_trim.nf'
include { DEMUX_SUMMARIZE } from './modules/demux_summarize.nf'
include { NANOSTAT } from './modules/nanostat.nf'
include { MULTIQC } from './modules/multiQC.nf'
include { READ_LENGTH }  from './modules/read_length.nf'


workflow {

    fq_ch = Channel.fromPath(params.input + "/*.fastq.gz")
              .map { it -> tuple(it.baseName.replace(".fastq", ""), it) }

    barcode_fasta    = file(params.barcodes)
    arrangement_toml = file(params.arrangement_toml)

    
    EXTRACT_HEADER(fq_ch)
    merged_tags = EXTRACT_HEADER.out.collect()

    
    DORADO_DEMUX(fq_ch, barcode_fasta, arrangement_toml)
    combined_fq_ch = COMBINE_BARCODES(DORADO_DEMUX.out.collect())

    
    barcode_fq_ch = combined_fq_ch.flatten()
                      .map { fq -> tuple(fq.baseName.replace(".fastq", ""), fq) }

    REHEADER_READS(barcode_fq_ch, merged_tags)

    
    CUTADAPT_TRIM(REHEADER_READS.out.fq)

    DEMUX_SUMMARIZE (CUTADAPT_TRIM.out.fq.collect())

    demuxed_fq_ch = CUTADAPT_TRIM.out.fq
                   .flatten()
                   .map { fq -> tuple(fq.baseName.replace(".fastq",""), fq) }


    // Read in the demux summary report and create individual valid ID tuples, only do nanostat on those apprered in the report
    valid_ids_ch = DEMUX_SUMMARIZE.out
                  .splitCsv()
                  .filter { row -> 
                         row[0].startsWith("barcode") || row[0] == "unknown"
                        }
                   .map { row -> tuple(row[0].trim(), true) } 


     filtered_fq_ch = demuxed_fq_ch
                     .join(valid_ids_ch, by: 0)  
                     .map { sample_id, fastq_file, flag -> tuple(sample_id, fastq_file) }
                             


      READ_LENGTH (filtered_fq_ch)
      NANOSTAT(filtered_fq_ch)
      MULTIQC(NANOSTAT.out.collect())
}

