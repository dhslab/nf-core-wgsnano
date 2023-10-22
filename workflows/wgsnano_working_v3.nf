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

include { FAST5_TO_POD5                                 } from '../modules/local/FAST5_TO_POD5'
include { DORADO_BASECALLER_GPU                         } from '../modules/local/DORADO_BASECALLER_GPU'
include { MERGE_BASECALL as MERGE_BASECALL_ID           } from '../modules/local/MERGE_BASECALL'
include { MERGE_BASECALL as MERGE_BASECALL_SAMPLE       } from '../modules/local/MERGE_BASECALL'
include { DORADO_BASECALL_SUMMARY                       } from '../modules/local/DORADO_BASECALL_SUMMARY'
include { PYCOQC                                        } from '../modules/local/PYCOQC'
include { DORADO_ALIGNER                                } from '../modules/local/DORADO_ALIGNER'
include { SAMTOOLS_SORT                                 } from '../modules/local/SAMTOOLS_SORT'
include { PEPPER                                        } from '../modules/local/PEPPER'
include { SAMTOOLS_INDEX                                } from '../modules/local/SAMTOOLS_INDEX'
include { MOSDEPTH                                      } from '../modules/local/MOSDEPTH'
include { MODKIT                                        } from '../modules/local/MODKIT'
include { CUSTOM_DUMPSOFTWAREVERSIONS                   } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { MULTIQC                                       } from '../modules/local/MULTIQC'


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

    // fast5 input
    if (params.reads_format == 'fast5') {
        INPUT_CHECK
        .out
        .reads
        .map { meta, fast5_path -> 
            def fast5_files = []
            if (file(fast5_path).isDirectory()) {
                fast5_files = file("${fast5_path}/*.fast5")
            } else if (fast5_path.endsWith('.fast5')) {
                fast5_files = [file(fast5_path)]
            }
            [meta, fast5_files]
        }
        .flatMap { meta, files ->
            def chunks = files.toList().collate(params.dorado_files_chunksize)  // chunk files into groups of 2
            def chunkList = []
            for (int i = 0; i < chunks.size(); i++) {
                def newMeta = meta.clone()  // clone the meta to avoid modifying the original
                newMeta.chunkNumber = i + 1  // add chunk number, starting from 1
                chunkList << [newMeta, chunks[i]]
            }
            return chunkList
        }
        .dump(tag: 'input', pretty: true)
        .set { ch_fast5 }

    FAST5_TO_POD5 (
        ch_fast5
    )

    FAST5_TO_POD5
    .out
    .pod5
    .set { ch_pod5 } 

    ch_versions = ch_versions.mix(FAST5_TO_POD5.out.versions)

    } else if (params.reads_format == 'pod5') {
    INPUT_CHECK
    .out
    .reads
    .map { meta, pod5_path -> 
        def pod5_files = []
        if (file(pod5_path).isDirectory()) {
            pod5_files = file("${pod5_path}/*.pod5")
        } else if (pod5_path.endsWith('.pod5')) {
            pod5_files = [file(pod5_path)]
        }
        [meta, pod5_files]
    }
    .flatMap { meta, files ->
        def chunks = files.toList().collate(params.dorado_files_chunksize)  // chunk files into groups of 2
        def chunkList = []
        for (int i = 0; i < chunks.size(); i++) {
            def newMeta = meta.clone()  // clone the meta to avoid modifying the original
            newMeta.chunkNumber = i + 1  // add chunk number, starting from 1
            chunkList << [newMeta, chunks[i]]
        }
        return chunkList
    }
    .dump(tag: 'input_pod5', pretty: true)
    .set { ch_pod5 }
    }


    if (params.reads_format == 'pod5' || params.reads_format == 'fast5') {
        DORADO_BASECALLER_GPU (
            ch_pod5
        )
        ch_versions = ch_versions.mix(DORADO_BASECALLER_GPU.out.versions)
        DORADO_BASECALLER_GPU
        .out
        .bam
        .map { meta, bam -> [[id: meta.id, sample: meta.sample, flowcell: meta.flowcell, batch: meta.batch, kit: meta.kit] , bam]} // make sample name the only mets (remove flow cell and other info)
        .groupTuple(by: 0) // group bams by meta (i.e sample) which zero indexed
        // .dump(pretty: true)
        .set { ch_basecall_single_bams }

        MERGE_BASECALL_ID (
        ch_basecall_single_bams
        )
        ch_versions = ch_versions.mix(MERGE_BASECALL_ID.out.versions)

        MERGE_BASECALL_ID
        .out
        .merged_bam
        // .dump(tag: 'basecall_id', pretty: true)
        .set { ch_basecall_id_merged_bams }

        // Dorado basecall summary
        DORADO_BASECALL_SUMMARY (
            ch_basecall_id_merged_bams
        )

        //
        // CHANNEL: Channel operation group unaligned bams paths by sample (i.e bams of reads from multiple flow cells but the same sample streamed together to be fed for alignment module)
        //
        ch_basecall_id_merged_bams
        .map { meta, bam -> [[sample: meta.sample] , bam]} // make sample name the only mets (remove flow cell and other info)
        .groupTuple(by: 0) // group bams by meta (i.e sample) which zero indexed
        .dump(tag: 'basecall_sample', pretty: true)
        .set { ch_basecall_sample_merged_bams } // set channel name


        DORADO_BASECALL_SUMMARY
        .out
        .summary
        // .dump(pretty: true)
        .set { ch_basecall_summary }


        // MODULE: PycoQC (QC from Basecall results)
        PYCOQC (
            ch_basecall_summary
        )
        ch_versions = ch_versions.mix(PYCOQC.out.versions)

    }

if (params.reads_format == 'bam' ) {
    INPUT_CHECK
    .out
    .reads
    .flatMap { meta, bam_path -> 
        def bam_files = []
        if (file(bam_path).isDirectory()) {
            bam_files = file("${bam_path}/*.bam")
        } else if (bam_path.endsWith('.bam')) {
            bam_files = [file(bam_path)]
        }
        bam_files.collect { [[sample: meta.sample], it] }  // Create a list of [meta, file] pairs
    }
    .groupTuple(by: 0) // group bams by meta (i.e sample) which is zero-indexed
    .dump(tag: 'basecall_sample', pretty: true)
    .set { ch_basecall_sample_merged_bams } // set channel name
}



    // Merge Bam files for each run (by id)
    // DORADO_BASECALLER_GPU
    // .out
    // .bam
    // .map { meta, bam -> [[id: meta.id, sample: meta.sample, flowcell: meta.flowcell, batch: meta.batch, kit: meta.kit] , bam]} // make sample name the only mets (remove flow cell and other info)
    // .groupTuple(by: 0) // group bams by meta (i.e sample) which zero indexed
    // // .dump(pretty: true)
    // .set { ch_basecall_single_bams }

    // MERGE_BASECALL_ID (
    //     ch_basecall_single_bams
    // )
    // ch_versions = ch_versions.mix(MERGE_BASECALL_ID.out.versions)

    // MERGE_BASECALL_ID
    // .out
    // .merged_bam
    // // .dump(tag: 'basecall_id', pretty: true)
    // .set { ch_basecall_id_merged_bams }

    //
    // CHANNEL: Channel operation group unaligned bams paths by sample (i.e bams of reads from multiple flow cells but the same sample streamed together to be fed for alignment module)
    //
    // ch_basecall_id_merged_bams
    // .map { meta, bam -> [[sample: meta.sample] , bam]} // make sample name the only mets (remove flow cell and other info)
    // .groupTuple(by: 0) // group bams by meta (i.e sample) which zero indexed
    // .dump(tag: 'basecall_sample', pretty: true)
    // .set { ch_basecall_sample_merged_bams } // set channel name


    // // Dorado basecall summary
    // DORADO_BASECALL_SUMMARY (
    //     ch_basecall_id_merged_bams
    // )

    // DORADO_BASECALL_SUMMARY
    // .out
    // .summary
    // // .dump(pretty: true)
    // .set { ch_basecall_summary }


    // // MODULE: PycoQC (QC from Basecall results)
    // PYCOQC (
    //     ch_basecall_summary
    // )
    // ch_versions = ch_versions.mix(PYCOQC.out.versions)


    //
    // MODULE: DORADO_ALIGNER for Alignment
    //
    MERGE_BASECALL_SAMPLE (
        ch_basecall_sample_merged_bams
    )
    ch_versions = ch_versions.mix(MERGE_BASECALL_SAMPLE.out.versions)

    // MERGE_BASECALL_SAMPLE
    // .out
    // .merged_bam
    // // .dump(pretty: true)
    // .set { ch_alignment_input_bams }
    

    DORADO_ALIGNER (
        MERGE_BASECALL_SAMPLE.out.merged_bam,
        file(params.fasta)
    )
    ch_versions = ch_versions.mix(DORADO_ALIGNER.out.versions)


    //
    // MODULE: Samtools sort and indedx aligned bams
    //
    SAMTOOLS_SORT (
        DORADO_ALIGNER.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)

    SAMTOOLS_SORT
    .out
    .bam
    .dump(pretty: true)





    //
    // MODULE: PEPPER
    //
    PEPPER (
        SAMTOOLS_SORT.out.bam,
        SAMTOOLS_SORT.out.bai,
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
    // MODULE: MODKIT to extract methylation data
    //
    MODKIT (
        SAMTOOLS_INDEX.out.bam,
        SAMTOOLS_INDEX.out.bai,
        file(params.fasta)
    )
    ch_versions = ch_versions.mix(MODKIT.out.versions)





    //
    // MODULE: MODBAM2BED to extract methylation data
    //
    // MODBAM2BED (
    //     SAMTOOLS_INDEX.out.bam,
    //     SAMTOOLS_INDEX.out.bai,
    //     file(params.fasta)
    // )
    // ch_versions = ch_versions.mix(MODBAM2BED.out.versions)




    // CUSTOM_DUMPSOFTWAREVERSIONS (
    //     ch_versions.unique().collectFile(name: 'collated_versions.yml')
    // )

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
    // ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    // if (params.reads_format == 'fast5') {
    //     ch_multiqc_files = ch_multiqc_files.mix(PYCOQC.out.json.collect{it[1]}.ifEmpty([]))
    // }


    // ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.global_txt.collect{it[1]}.ifEmpty([]))
    // ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.summary_txt.collect{it[1]}.ifEmpty([]))
    // ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.regions_txt.collect{it[1]}.ifEmpty([]))
    // ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.regions_bed.collect{it[1]}.ifEmpty([]))
    // ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.regions_csi.collect{it[1]}.ifEmpty([]))
    // ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.quantized_bed.collect{it[1]}.ifEmpty([]))
    // ch_multiqc_files = ch_multiqc_files.mix(MOSDEPTH.out.quantized_csi.collect{it[1]}.ifEmpty([]))




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
