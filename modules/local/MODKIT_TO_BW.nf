process MODKIT_TO_BW {
    label 'process_low'
    container 'ghcr.io/dhslab/docker-baseimage:latest'
    stageInMode 'copy'

    input:
        tuple val(meta), path (hap_1_bed), path (hap_2_bed), path (combined_bed)
        path fasta_index

    output:
        tuple val(meta), path("*.bedmethyl.gz"), emit: gzipped
        tuple val(meta), path("*.bw"), emit: bw
        path  ("versions.yml")       , emit: versions

    script:
    def args = params.modifications ? "-m ${params.modifications}": "" 
    """
    gzip -c $hap_1_bed > ${meta.sample}.hap1.basemods.bedmethyl.gz
    gzip -c $hap_2_bed > ${meta.sample}.hap2.basemods.bedmethyl.gz
    gzip -c $combined_bed > ${meta.sample}.combined.basemods.bedmethyl.gz

    bedmethyl2bw.py -b ${meta.sample}.hap1.basemods.bedmethyl.gz -c $fasta_index $args -o ${meta.sample}.hap1.basemods.bedmethyl.bw
    bedmethyl2bw.py -b ${meta.sample}.hap2.basemods.bedmethyl.gz -c $fasta_index $args -o ${meta.sample}.hap2.basemods.bedmethyl.bw
    bedmethyl2bw.py -b ${meta.sample}.combined.basemods.bedmethyl.gz -c $fasta_index $args -o ${meta.sample}.combined.basemods.bedmethyl.bw

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}