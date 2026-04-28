#!/bin/bash

outdir=fastq_output_20260424
input=s3://seqwell-ont/20260424/fastq_pass/
pool_ID=20260424
data_type=fastq   # 'bam' or 'fastq'

/software/nextflow-align/nextflow run \
main.nf \
--pool_ID $pool_ID \
--input $input \
--outdir $outdir \
--data_type $data_type \
-resume -bg
