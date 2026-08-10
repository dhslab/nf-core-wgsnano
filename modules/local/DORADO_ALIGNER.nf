process DORADO_ALIGNER {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/dhslab/docker-ont-dorado:latest' :
        'ghcr.io/dhslab/docker-ont-dorado:latest' }"

    input:

        tuple val(meta), path (reads_paths) 
        path (reference)

    output:
        tuple val(meta), path ("*.bam")       , emit: bam
        path "versions.yml"                   , emit: versions

    script:
        def index = reference.find { it.name =~ /.*\.fai/ }
        def args = task.ext.args ?: ''
    """        
    dorado aligner \\
            --threads ${task.cpus} \\
            ${index} \\
            ${reads_paths} \\
            > ${meta.sample}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(dorado --version 2>&1)
    END_VERSIONS
    """
}
