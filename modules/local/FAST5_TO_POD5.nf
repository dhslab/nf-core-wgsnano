process FAST5_TO_POD5 {
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'chrisamiller/pod5-tools:0.2.4' :
        'chrisamiller/pod5-tools:0.2.4' }"

    input:

        tuple val(meta), path (fast5)

    output:
        tuple val(meta), path ("*.pod5")  , emit: pod5
        path "versions.yml"               , emit: versions

    script:
        """
        mkdir -p fast5_dir
        mv *.fast5 fast5_dir
        pod5 convert fast5 fast5_dir --output ${meta.id}.${meta.chunkNumber}.pod5

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            pod5: \$(pod5 --version | awk -F ': ' '{print \$2}')
        END_VERSIONS
        """
}
