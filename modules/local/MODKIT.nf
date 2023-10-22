process MODKIT {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'mdivr/modkit:v2' :
        'mdivr/modkit:v2' }"

    input:
        tuple val(meta), path (haplotagged_bam)
        tuple val(meta), path (haplotagged_bam_index)
        path (reference_fasta)

    output:
        tuple val(meta), path ("**/*.bed")    , emit: bam
        path  ("versions.yml")             , emit: versions

    script:
    """
    modkit pileup \\
    --threads ${task.cpus}  \\
    --ref ${reference_fasta} \\
    --cpg \\
    --combine-strands \\
    --only-tabs \\
    --partition-tag HP \\
    --prefix ${meta.sample}_accumulated_haplotype \\
    ${haplotagged_bam} \\
    accumulated

    modkit pileup \\
    --threads ${task.cpus} \\
    --ref ${reference_fasta} \\
    --cpg \\
    --only-tabs \\
    --partition-tag HP \\
    --prefix ${meta.sample}_stranded_haplotype \\
    ${haplotagged_bam} \\
    stranded

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modki: \$(modkit --version | sed 's/mod_kit //g')
    END_VERSIONS
    """


}
