process MERGE_BASECALL {
    label 'process_high'

    conda "bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.16.1--h6899075_1' :
        'quay.io/biocontainers/samtools:1.16.1--h6899075_1' }"

    input:
        tuple val(meta), path(input_bams)

    output:
        tuple val(meta), path("${meta.id ?: meta.sample}.unaligned.bam")    , emit: merged_bam
        path  ("versions.yml")                     , emit: versions

    script:
    def prefix = meta.id ?: meta.sample

    """
    samtools merge -@ ${task.cpus} ${prefix}.unaligned.bam $input_bams

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
