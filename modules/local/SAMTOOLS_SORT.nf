process SAMTOOLS_SORT {
    label 'process_high'

    conda "bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.16.1--h6899075_1' :
        'quay.io/biocontainers/samtools:1.16.1--h6899075_1' }"

    input:
        tuple val(meta), path(aligned_bams)

    output:
        tuple val(meta), path("${meta.sample}.sorted.bam")    , emit: bam
        tuple val(meta), path("${meta.sample}.sorted.bam.bai"), emit: bai
        path  ("versions.yml")                                , emit: versions

    script:
    """
    samtools sort -@ ${task.cpus} -o ${meta.sample}.sorted.bam ${aligned_bams} &&
    samtools index -@ ${task.cpus} ${meta.sample}.sorted.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

}
