process MODKIT {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/dhslab/docker-modkit' :
        'ghcr.io/dhslab/docker-modkit' }"

    input:
        tuple val(meta), path (haplotagged_bam)
        tuple val(meta), path (haplotagged_bam_index)
        path (reference_fasta)

    output:
        tuple val(meta), path ("*.bed.gz")    , emit: bed
        path  ("versions.yml")             , emit: versions

    script:
    """
    modkit pileup \\
    --threads ${task.cpus}  \\
    --ref ${reference_fasta} \\
    --cpg \\
    --combine-strands \\
    --only-tabs \\
    --partition-tag HP \\
    --prefix ${meta.sample}.basemods.bedmethyl.hap \\
    ${haplotagged_bam} \\
    accumulated

    modkit pileup \\
    --threads ${task.cpus} \\
    --ref ${reference_fasta} \\
    --combine-strands \\
    --cpg \\
    --only-tabs \\
    ${haplotagged_bam} \\
    ${meta.sample}.basemods.bedmethyl.combined.bed

    mv accumulated/*.bed .

    gzip -c ${meta.sample}.basemods.bedmethyl.hap_1.bed > ${meta.sample}.basemods.bedmethyl.hap_1.bed.gz
    gzip -c ${meta.sample}.basemods.bedmethyl.hap_2.bed > ${meta.sample}.basemods.bedmethyl.hap_2.bed.gz
    gzip -c ${meta.sample}.basemods.bedmethyl.hap_ungrouped.bed > ${meta.sample}.basemods.bedmethyl.hap_ungrouped.bed.gz
    gzip -c ${meta.sample}.basemods.bedmethyl.combined.bed > ${meta.sample}.basemods.bedmethyl.combined.bed.gz


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modki: \$(modkit --version | sed 's/mod_kit //g')
    END_VERSIONS
    """


}
