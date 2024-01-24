// Function to determine the label
def determineLabel() {
    return params.use_gpu ? 'process_gpu_long' : 'process_high'
}

process DORADO_BASECALLER {
    label determineLabel()

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'mdivr/dorado:v1' :
        'mdivr/dorado:v1' }"

    input:

        tuple val(meta), path (pod5)

    output:
        tuple val(meta), path ("*.bam")       , emit: bam
        path "versions.yml"                   , emit: versions

    script:
        def args = task.ext.args ?: ''
        def device = params.use_gpu ? "cuda:all": "cpu"
        def chunksize = params.dorado_reads_chunksize ?: 1000
        def mod_model = params.dorado_modifications_model ? "--modified-bases ${params.dorado_modifications_model}" : ''

        """
        export LANG="C"
        export LC_ALL="C"

        mkdir -p pod5
        mv *.pod5 pod5
        
        dorado basecaller /opt/dorado/models/${params.dorado_model} \\
                pod5/ \\
                --device ${device} \\
                ${mod_model} \\
                --chunksize ${chunksize} \\
                > ${meta.id}.${meta.chunkNumber}.bam
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            dorado: \$(dorado --version 2>&1)
        END_VERSIONS
        """

    stub:
        """
        cp ${launchDir}/test/data/stub/dorado/${meta.id}.${meta.chunkNumber}.bam .
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            dorado: \$(dorado --version 2>&1)
        END_VERSIONS

        """
}
