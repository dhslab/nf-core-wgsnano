process DORADO_BASECALL_SUMMARY {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/dhslab/docker-dorado:latest' :
        'ghcr.io/dhslab/docker-dorado:latest' }"

    input:

        tuple val(meta), path (input_bam)

    output:
        tuple val(meta), path ("sequencing_summary_${meta.id}.txt")    , emit: summary
        path "versions.yml"                                             , emit: versions

    script:
        def args = task.ext.args ?: ''
        """
        dorado summary ${input_bam} > sequencing_summary_${meta.id}.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            dorado: \$(dorado --version 2>&1)
        END_VERSIONS
        """

}
