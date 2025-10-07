process READ_LENGTH {
    tag "$pair_id"
    publishDir "${params.outdir}/read_length", pattern: '*weighted*',  mode: 'copy'  
    publishDir "${params.outdir}/read_length", pattern: '*.read_length_plot.png', mode: 'copy'  
   
 
    input:
    tuple val(pair_id), path(fq)

    output:
    tuple val(pair_id), path("${pair_id}.read_length_matrix.txt"), path("${pair_id}.read_length_plot.png")
    path( "${pair_id}.read_length_matrix.txt" ),  emit: matrix    
    path( "*bin_table.txt" ),  emit: bin
    path( "*weighted*"), emit: weighted_plot 

    

    script:
    """
    # extract read lengths
    zcat ${fq} | awk 'NR%4==2 {print length(\$0)}' > ${pair_id}.read_lengths.txt
    
    sort -n ${pair_id}.read_lengths.txt | uniq -c | awk '{print \$1"\\t"\$2}' > ${pair_id}.read_length_counts.txt
    # 2. Count occurrences of each length
    sort -n ${pair_id}.read_lengths.txt | uniq -c | awk '{print \$2"\\t"\$1}' > counts.tmp

    # 3. Generate full matrix from 1 to 16000 (fill missing with 0)
    awk 'BEGIN{for(i=1;i<=16000;i++) c[i]=0} {c[\$1]=\$2} END{for(i=1;i<=16000;i++) print i"\\t"c[i]}' counts.tmp > ${pair_id}.read_length_matrix.txt

  

    # call external Python script from bin/
    read_length.py ${pair_id}.read_lengths.txt ${pair_id}.read_length_plot.png
    """
}

