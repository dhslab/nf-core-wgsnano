process PEPPER {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'mdivr/pepper:v1' :
        'mdivr/pepper:v1' }"

    input:
        tuple val(meta), path(bam_bai_files)
        path (reference_fasta)

    output:
        tuple val(meta), path("${meta.sample}*.vcf*")               , emit: vcf
        path  ("versions.yml")                                      , emit: versions

    script:
    """
        export PATH=/opt/margin_dir/build/:$PATH
        run_pepper_margin_deepvariant call_variant \\
        -b ${meta.sample}.sorted.bam \\
        -f $reference_fasta \\
        -o . \\
        -p ${meta.sample} \\
        -t ${task.cpus} \\
        --${params.nanopore_reads_type} \\
        --phased_output \\
        --skip_final_phased_bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pepper_margin_deepvariant: \$(run_pepper_margin_deepvariant --version | grep -o -P "(?<=\\VERSION:  \\b).*")
    END_VERSIONS
    """

}
