process WHATSHAP {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/dhslab/docker-whatshap:latest' :
        'ghcr.io/dhslab/docker-whatshap:latest' }"

    input:
        tuple val(meta), path(bam_bai_vcf_files)
        path(reference_fasta)
        path(index)

    output:
        tuple val(meta), path("${meta.sample}*.haplotagged.bam")     , emit: bam
        tuple val(meta), path("${meta.sample}*.haplotagged.bam.bai") , emit: bai
        path  ("versions.yml")                                       , emit: versions

    script:
    """
        whatshap haplotag --tag-supplementary --ignore-read-groups --output-threads=${task.cpus} \\
        -o ${meta.sample}.haplotagged.bam --reference ${reference_fasta} ${meta.sample}.phased.vcf.gz ${meta.sample}.sorted.bam && \\
        samtools index ${meta.sample}.haplotagged.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        whatshap: \$(whatshap --version)")
    END_VERSIONS
    """

}
