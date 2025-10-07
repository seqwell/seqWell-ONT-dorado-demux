#!/bin/bash

outdir=demux_output
input=test_data/*.fastq.gz
pool_ID=384_test

nextflow run \
main.nf \
--pool_ID $pool_ID \
--input $input \
--outdir $outdir \
-resume -bg
