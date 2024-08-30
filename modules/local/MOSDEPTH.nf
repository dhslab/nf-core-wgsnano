process MOSDEPTH {
    label 'process_medium'

    conda "bioconda::mosdepth=0.3.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mosdepth:0.3.3--hdfd78af_1' :
        'quay.io/biocontainers/mosdepth:0.3.3--hdfd78af_1'}"

    input:
    tuple val(meta), path(bam_bai_files)

    output:
    tuple val(meta), path('*.global.dist.txt')      , emit: global_txt
    tuple val(meta), path('*.summary.txt')          , emit: summary_txt
    tuple val(meta), path('*.region.dist.txt')      , emit: regions_txt
    tuple val(meta), path('*.regions.bed.gz')       , emit: regions_bed
    tuple val(meta), path('*.regions.bed.gz.csi')   , emit: regions_csi
    tuple val(meta), path('*.quantized.bed.gz')     , emit: quantized_bed
    tuple val(meta), path('*.quantized.bed.gz.csi') , emit: quantized_csi
    path  "versions.yml"                            , emit: versions

    script:

    """
    export MOSDEPTH_Q0=NO_COVERAGE   # 0 -- defined by the arguments to --quantize
    export MOSDEPTH_Q1=LOW_COVERAGE  # 1..4
    export MOSDEPTH_Q2=CALLABLE      # 5..149
    export MOSDEPTH_Q3=HIGH_COVERAGE # 150 ...

    mosdepth -t ${task.cpus} -n -x -Q 1 --by 500 --quantize 0:1:5:150: ${meta.sample} *bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mosdepth: \$(mosdepth --version 2>&1 | sed 's/^.*mosdepth //; s/ .*\$//')
    END_VERSIONS
    """

}
