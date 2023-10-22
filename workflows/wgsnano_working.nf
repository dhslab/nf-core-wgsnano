/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowWgsnano.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { GUPPY_BASECALLER            } from '../modules/local/GUPPY_BASECALLER'
include { GUPPY_BASECALLER_GPU        } from '../modules/local/GUPPY_BASECALLER_GPU'
include { PYCOQC                      } from '../modules/local/PYCOQC'
include { GUPPY_ALIGNER               } from '../modules/local/GUPPY_ALIGNER'
include { SAMTOOLS_MERGE              } from '../modules/local/SAMTOOLS_MERGE'
include { PEPPER                      } from '../modules/local/PEPPER'
include { SAMTOOLS_INDEX              } from '../modules/local/SAMTOOLS_INDEX'
include { MOSDEPTH                    } from '../modules/local/MOSDEPTH'
include { MODBAM2BED                  } from '../modules/local/MODBAM2BED'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { MULTIQC                     } from '../modules/local/MULTIQC'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow WGSNANO {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    //
    // CHANNEL: Channel construction to stream reference genome fasta file
    //
    ch_fasta = Channel.fromPath(params.fasta)
    // Run basecall if input is fast5
    if (params.reads_format == 'fast5') {
        //
        // MODULE: Guppy Basecaller
        //

        // Run with GPU if use_gpu = true, and set a channel to stream Guppy Basecaller output
        if ( params.use_gpu ) {
            GUPPY_BASECALLER_GPU (
                INPUT_CHECK.out.reads
            )
            ch_versions = ch_versions.mix(GUPPY_BASECALLER_GPU.out.versions)
            ch_basecall_out = GUPPY_BASECALLER_GPU.out
        } else {
            GUPPY_BASECALLER (
                INPUT_CHECK.out.reads
            )
            ch_versions = ch_versions.mix(GUPPY_BASECALLER.out.versions)
            ch_basecall_out = GUPPY_BASECALLER.out
        }

        //
        // MODULE: PycoQC (QC from Basecall results)
        //
        PYCOQC (
            ch_basecall_out.summary
        )
        ch_versions = ch_versions.mix(PYCOQC.out.versions)


        //
        // CHANNEL: Channel operation group unaligned bams paths by sample (i.e bams of reads from multiple flow cells but the same sample streamed together to be fed for alignment module)
        //
        ch_basecall_out // basecll output channel
        .basecall_bams_path // bams path output
        .map { meta, bams -> [[sample: meta.sample] , bams]} // make sample name the only mets (remove flow cell and other info)
        .groupTuple(by: 0) // group bams by meta (i.e sample) which zero indexed
        .dump(pretty: true)
        .set { ch_reads_path_per_sample } // set channel name

    } else if (params.reads_format == 'bam') {
        INPUT_CHECK.out.reads
        .map { meta, reads -> 
            def bamFiles = file(reads).isDirectory() ? file("$reads/**.bam") : file("$reads")
            [[sample: meta.sample], bamFiles]
        }
        .groupTuple(by: 0)
        .map {meta, reads -> [meta, reads.flatten()]}
        .dump(pretty: true)
        .set { ch_reads_path_per_sample }

    }

    //
    // MODULE: GUPPY_ALIGNER for Alignment
    //
    GUPPY_ALIGNER (
        ch_reads_path_per_sample,
        file(params.fasta)
    )
    ch_versions = ch_versions.mix(GUPPY_ALIGNER.out.versions)

    //
    // MODULE: Samtools merge all bams
    //
    SAMTOOLS_MERGE (
        GUPPY_ALIGNER.out.bams,
        GUPPY_ALIGNER.out.bais
    )
    ch_versions = ch_versions.mix(SAMTOOLS_MERGE.out.versions)


    //
    // MODULE: PEPPER
    //
    PEPPER (
        SAMTOOLS_MERGE.out.bam,
        SAMTOOLS_MERGE.out.bai,
        file(params.fasta)
    )
    ch_versions = ch_versions.mix(PEPPER.out.versions)

    //
    // MODULE: Index PEPPER bam
    //
    SAMTOOLS_INDEX (
        PEPPER.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions)


    //
    // MODULE: MOSDEPTH for depth calculation
    //
    MOSDEPTH (
        SAMTOOLS_INDEX.out.bam,
        SAMTOOLS_INDEX.out.bai
    )
    ch_versions = ch_versions.mix(MOSDEPTH.out.versions)


    //
    // MODULE: MODBAM2BED to extract methylation data
    //
    MODBAM2BED (
        SAMTOOLS_INDEX.out.bam,
        SAMTOOLS_INDEX.out.bai,
        file(params.fasta)
    )
    ch_versions = ch_versions.mix(MODBAM2BED.out.versions)




    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowWgsnano.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowWgsnano.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.global_txt.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.summary_txt.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.regions_txt.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.regions_bed.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.regions_csi.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.quantized_bed.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.quantized_csi.collect{it[1]}.ifEmpty([]))
    if (params.reads_format == 'fast5' || params.reads_format == 'pod5') {
        ch_multiqc_files = ch_multiqc_files.mix(PYCOQC.out.json.collect{it[1]}.ifEmpty([]))
    }



    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
    // emit: Channel.empty()
    // emit: GUPPY_BASECALLER.out.basecall_bams_path.map { meta, bams -> [meta.sample , bams]} .groupTuple()
    // emit : ch_reads_path_per_sample
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
