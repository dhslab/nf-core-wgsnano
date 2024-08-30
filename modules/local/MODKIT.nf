process MODKIT {
    label 'process_high'
    tag "${meta.sample}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/dhslab/docker-modkit' :
        'ghcr.io/dhslab/docker-modkit' }"

    input:
        tuple val(meta), path (bam_bai_files)
        path (reference_fasta)

    output:
        tuple val(meta), path ("${meta.sample}.basemods.bedmethyl.hap_1.bed")        , emit: hap1_bed
        tuple val(meta), path ("${meta.sample}.basemods.bedmethyl.hap_2.bed")        , emit: hap2_bed
        tuple val(meta), path ("${meta.sample}.basemods.bedmethyl.combined.bed")     , emit: combined_bed
        tuple val(meta), path ("${meta.sample}.basemods.bedmethyl.hap_ungrouped.bed"), emit: ungrouped_bed
        path  ("versions.yml")                                                       , emit: versions

    script:
    """
    modkit pileup \\
    --threads ${task.cpus}  \\
    --ref ${reference_fasta} \\
    --cpg \\
    --combine-strands \\
    --partition-tag HP \\
    --prefix ${meta.sample}.basemods.bedmethyl.hap \\
    ${meta.sample}.haplotagged.bam \\
    accumulated &&

    modkit pileup \\
    --threads ${task.cpus} \\
    --ref ${reference_fasta} \\
    --combine-strands \\
    --cpg \\
    ${meta.sample}.haplotagged.bam \\
    ${meta.sample}.basemods.bedmethyl.combined.bed &&

    mv accumulated/*.bed .
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modkit: \$(modkit --version | sed 's/mod_kit //g')
    END_VERSIONS
    """
}
