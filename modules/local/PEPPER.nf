process PEPPER {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'kishwars/pepper_deepvariant:r0.8' :
        'kishwars/pepper_deepvariant:r0.8' }"

    input:
        tuple val(meta), path(aligned_merged_bam)
        tuple val(meta), path(aligned_merged_bam_index)
        path (reference_fasta)

    output:
        tuple val(meta), path("${meta.sample}.haplotagged.bam")    , emit: bam
        tuple val(meta), path("${meta.sample}*.vcf*")               , emit:vcf
        path  ("versions.yml")                                                      , emit: versions

    script:
    """
        export PATH=/opt/margin_dir/build/:$PATH
        run_pepper_margin_deepvariant call_variant \\
        -b $aligned_merged_bam \\
        -f $reference_fasta \\
        -o . \\
        -p ${meta.sample} \\
        -t ${task.cpus} \\
        --${params.nanopore_reads_type} \\
        --phased_output \\
        --keep_intermediate_bam_files \\
        --pepper_include_supplementary


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pepper_margin_deepvariant: \$(run_pepper_margin_deepvariant --version | grep -o -P "(?<=\\VERSION:  \\b).*")
    END_VERSIONS
    """

    stub: // make links for older runs to run stubs for dry runs
    """
    cp -r ${workflow.launchDir}/stub-test/stubs/pepper_out pepper_out
    mv pepper_out/* .
    mv aml476081.haplotagged.bam ${meta.sample}.haplotagged.bam
    mv aml476081.phased.vcf.gz ${meta.sample}.phased.vcf.gz
    mv aml476081.phased.vcf.gz.tbi ${meta.sample}.phased.vcf.gz.tbi
    mv aml476081.vcf.gz ${meta.sample}.vcf.gz
    mv aml476081.vcf.gz.tbi ${meta.sample}.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pepper_margin_deepvariant: \$(run_pepper_margin_deepvariant --version | grep -o -P "(?<=\\VERSION:  \\b).*")
    END_VERSIONS

    """

}
