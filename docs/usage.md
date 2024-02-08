# nf-core-wgsnano pipeline parameters

Nextflow pipeline for analysis of Nanopore Whole Genome Sequencing

## Input/output options

Define where the pipeline should find input data and save output data.

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `input` | Path to comma-separated file containing information about the samples in the experiment.| `string` |  | True |
| `outdir` | The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure. | `string` |  | True |

## Workflow Options

Set of configurable parameters that determine the operational sequence and behavior of the pipeline

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `reads_format` | Specifies the input file format for the sequencing reads <details><summary>Help</summary><small><br>This option determines the starting point and processing steps of the pipeline based on the provided file format. Supported formats are `fast5`, `pod5`, and `bam`.<br>- `fast5`: When this format is selected, the pipeline initiates by converting `fast5` files to `pod5` files, followed by basecalling.<br>- `pod5`: Selecting this format starts the pipeline directly with Dorado basecalling, skipping any format conversion steps.<br>- `bam`: If `bam` format is chosen, the pipeline omits the basecalling stage and begins with read alignment, as `bam` files are assumed to be already basecalled.<br>- This option is crucial for directing the pipeline to correctly interpret the input data and apply the appropriate processing steps.<br></small></details>| `string` | bam | True |
| `extract_methylation` | Determines whether to extract methylation BED files from BAM files <details><summary>Help</summary><small>If enabled, the PEPPER output BAM files will serve as input for the modkit tool, which extracts methylation BED files from these BAM files. This process depends on the presence of modification basecalling values within the BAM files.</small></details>| `boolean` | True |  |

## Reference genome options

Reference genome related files and options required for the workflow.

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `fasta` | Path to FASTA genome file.| `string` |  |  |

## Dorado Options

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `use_gpu` | Whether to use GPU for Dorado Basecalling | `boolean` | True | True |
| `dorado_model` | Dorado Basecalling basic model | `string` | dna_r10.4.1_e8.2_400bps_sup@v4.3.0 |  |
| `dorado_modifications_model` | Dorado Basecalling modification model | `string` | 5mCG_5hmCG |  |
| `dorado_files_chunksize` | Specifies the number of files to be processed simultaneously by one Nextflow job in the Dorado basecalling | `integer` | 20000 |  |

## PEPPER Options

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `nanopore_reads_type` | PEPPER's reads-type option | `string` | ont_r10_q20 | True |
