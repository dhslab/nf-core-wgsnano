process SAMTOOLS_INDEX {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.16.1--h6899075_1' :
        'quay.io/biocontainers/samtools:1.16.1--h6899075_1' }"

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path("${meta.sample}.haplotagged.bam")     , emit: bam
    tuple val(meta), path("${meta.sample}.haplotagged.bam.bai") , emit: bai
    path  "versions.yml"                                        , emit: versions

    script:
    """
    samtools \\
        index \\
        -@ ${task.cpus-1} \\
        $input

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

}
