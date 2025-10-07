#!/bin/bash -ue
dorado demux fastq_pass     --output-dir fastq_pass_Demux     --kit-name sw     --barcode-arrangement arrangement.toml     --barcode-sequences barcodes.384.fa     --emit-fastq
