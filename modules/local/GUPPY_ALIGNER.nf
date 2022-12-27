process GUPPY_ALIGNER {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'dhspence/docker-guppy' :
        'dhspence/docker-guppy' }"

    input:

        tuple val(meta), path (unaligned_bams_paths) // unaligned_bams_paths not necessarily to be referred to in the script. However we know this input will dump bam files paths which start with "basecall_*" and will be available in the working directory
        path (reference_fasta)

    output:
        tuple val(meta), path ("alignment/*.bam") , emit: bams
        tuple val(meta), path ("alignment/*.bai") , emit: bais
        path ("versions.yml")                     , emit: versions

    script:
        """
        mkdir inputBams
        mv basecall_*/*.bam inputBams
        guppy_aligner -i inputBams -t ${task.cpus} --bam_out --index -a $reference_fasta -s alignment
        rm -rf basecall_*/
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            guppy_aligner: \$(guppy_aligner --version | grep -o -P "(?<=\\Oxford Nanopore Technologies plc. Version \\b).*")
            minimap2: \$(guppy_basecaller --version | grep -o -P "(?<=\\minimap2 version \\b).*")
        END_VERSIONS
        """
}
