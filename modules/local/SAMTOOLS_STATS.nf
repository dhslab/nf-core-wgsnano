process SAMTOOLS_STATS {
    label 'process_high'

    container 'ghcr.io/dhslab/docker-baseimage:latest'

    input:
        tuple val(meta), path(haplotagged_bam)

    output:
        tuple val(meta), path("${meta.sample}.combined.stats.txt"), emit: combined_stats
        tuple val(meta), path("${meta.sample}.hap1.stats.txt")    , emit: hap1_stats
        tuple val(meta), path("${meta.sample}.hap2.stats.txt")    , emit: hap2_stats
        path  ("versions.yml")                                    , emit: versions

    script:
    """
    samtools stats -@ 15 $haplotagged_bam > ${meta.sample}.combined.stats.txt
    samtools view -@ 7 -h -d HP:1 -u $haplotagged_bam | samtools stats -@ 7 - > ${meta.sample}.hap1.stats.txt
    samtools view -@ 7 -h -d HP:2 -u $haplotagged_bam | samtools stats -@ 7 - > ${meta.sample}.hap2.stats.txt


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

}
