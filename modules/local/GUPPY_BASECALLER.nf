process GUPPY_BASECALLER {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'dhspence/docker-guppy' :
        'dhspence/docker-guppy' }"

    input:

        tuple val(meta), path (fast5_path)

    output:
        tuple val(meta), path ("basecall_${meta.id}_summary/sequencing_summary.txt")  , emit: summary
        tuple val(meta), path ("basecall_${meta.id}_bams")       , emit: basecall_bams_path
        tuple val(meta), path ("*.fastq.gz")    , emit: fastq
        path "versions.yml"                           , emit: versions

    script:
        """
        guppy_basecaller -i $fast5_path --bam_out -s unaligned_bam -c /opt/ont/guppy/data/${params.basecall_config} --num_callers ${task.cpus}

        cat unaligned_bam/pass/*.fastq > ${meta.id}.fastq
        gzip ${meta.id}.fastq
        mkdir basecall_${meta.id}_summary && mv unaligned_bam/sequencing_* basecall_${meta.id}_summary
        mkdir basecall_${meta.id}_bams && mv unaligned_bam/pass/*.bam basecall_${meta.id}_bams
        rm -rf unaligned_bam

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            guppy_basecaller: \$(guppy_basecaller --version | grep -o -P "(?<=\\Oxford Nanopore Technologies plc. Version \\b).*(?=\\, \\b)")
        END_VERSIONS
        """

    stub:
        """
        mkdir basecall_${meta.id}_summary && cp ${workflow.launchDir}/stub-test/stubs/sequencing_summary.txt basecall_${meta.id}_summary
        mkdir basecall_${meta.id}_bams && cp ${workflow.launchDir}/stub-test/stubs/${meta.id}/basecall_${meta.id}/bams/*.bam basecall_${meta.id}_bams
        cp ${workflow.launchDir}/stub-test/stubs/${meta.id}/basecall_${meta.id}/fastq/${meta.id}.fastq.gz ${meta.id}.fastq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            guppy_basecaller: \$(guppy_basecaller --version | grep -o -P "(?<=\\Oxford Nanopore Technologies plc. Version \\b).*(?=\\, \\b)")
        END_VERSIONS
        """
}
