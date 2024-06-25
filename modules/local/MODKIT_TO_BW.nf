process MODKIT_TO_BW {
    label 'process_low'

    container 'ghcr.io/dhslab/docker-baseimage:latest'

    input:
        tuple val(meta), path(bed_file)
        path fasta_index

    output:
        tuple val(meta), path("*.bw"), emit: bw
        path  ("versions.yml")       , emit: versions

    script:
    def args = params.modifications ? "-m ${params.modifications}": "" 
    """
    basename=$bed_file
    output_file=\${basename/.bed.gz/.bw}
    bedmethyl2bw.py -b $bed_file -c $fasta_index $args -o \$output_file

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}