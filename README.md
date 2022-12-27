# wgsnano
## Whole Genome Sequencing by Nanopore data analysis


[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)


## Introduction

<!-- TODO nf-core: Write a 1-2 sentence summary of what data the pipeline is for and what it does -->

**nf-core-wgsnano** is a bioinformatics best-practice analysis pipeline for Nanopore Whole Genome Sequencing.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible.

<!-- TODO nf-core: Add full-sized test dataset and amend the paragraph below if applicable -->


## Pipeline summary

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

1. Basecalling ([`Guppy`](https://nanoporetech.com/nanopore-sequencing-data-analysis)) - with GPU run option
1. Basecalling QC ([`PycoQC`](https://a-slide.github.io/pycoQC/))
1. Alignment ([`Guppy`](https://nanoporetech.com/nanopore-sequencing-data-analysis) with [`minimap2`](https://github.com/lh3/minimap2))
1. Merge all aligned bam files into a single file ([`samtools`](http://www.htslib.org/doc/samtools.html))
1. Haplotyping and phased variants calling ([`PEPPER-Margin-DeepVariant`](https://github.com/kishwarshafin/pepper))
1. Methylation calls extraction from bam to bed files ([`modbam2bed`](https://github.com/epi2me-labs/modbam2bed))
1. Depth calculation ([`mosdepth`](https://github.com/brentp/mosdepth))
1. MultiQC ([`MultiQC`](https://multiqc.info/)) for Basecalling (PycoQC) and Depth (mosdepth)

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=22.10.1`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(**this pipeline can NOT be run with conda**))_. This requirement is not needed for running the pipeline in WashU RIS cluster.

3. Download the pipeline and test it on a minimal dataset with a single command:

   ```bash
   nextflow run dhslab/nf-core-wgsnano -profile test,YOURPROFILE(S) --outdir <OUTDIR>
   ```


4. Start running your own analysis!

   <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

   ```bash
   nextflow run dhslab/nf-core-wgsnano --input samplesheet.csv --fasta <FASTA> -profile <docker/singularity/podman/shifter/charliecloud/conda/institute> --outdir <OUTDIR>
   ```

## Usage
### Required parameters:
1. **Input** `samplesheet.cvs` which provides directory paths for fast5 raw reads and their metadata. this can be provided either in a configuration file or as `--input path/to/samplesheet.cvs` command line parameter. Example sheet located in `assets/samplesheet.csv`.
2. **Reference genome fasta** file, either in a configuration file or as `--fasta path/to/genome.fasta` command line parameter.

### Nanopore and runtime default parameters:
The following parameters are set to the shown default values, but should be modified when required in command line, or in user-provided config files:

- `--basecall_config dna_r10.4.1_e8.2_400bps_modbases_5mc_cg_sup.cfg` -> Guppy's config file for basecalling
- `--nanopore_reads_type ont_r10_q20` -> PEPPER's reads-type option
- `--use_gpu true` -> Enable GPU for basecalling (it can be disabled, but basecallling will take significantly longer time with CPU run)

### Running a pipeline test in LSF cluster (configured to WashU RIS cluster environment)


### **1) Directly from GitHub:**
```bash
NXF_HOME=${PWD}/.nextflow LSF_DOCKER_VOLUMES="/storage1/fs1/dspencer/Active:/storage1/fs1/dspencer/Active $HOME:$HOME" bsub -g /dspencer/nextflow -G compute-dspencer -q dspencer -e nextflow_launcher.err -o nextflow_launcher.log -We 2:00 -n 2 -M 12GB -R "select[mem>=16000] span[hosts=1] rusage[mem=16000]" -a "docker(ghcr.io/dhslab/docker-nextflow)" nextflow run dhslab/nf-core-wgsnano -r dev -profile test,ris,dhslab --outdir results
```
**Notice that three profiles are used here:**
1. `test`-> to provide `input` and `fasta` paths for the test run
2. `ris`-> to set **general** configuration for RIS LSF cluster
3. `dhslab`-> to set **lab-specific** cluster configuration

### **2) Alternatively, clone the repository and run the pipeline from local directory:**
```bash
git clone https://github.com/dhslab/nf-core-wgsnano.git
cd nf-core-wgsnano/
chmod +x bin/*
NXF_HOME=${PWD}/.nextflow LSF_DOCKER_VOLUMES="/storage1/fs1/dspencer/Active:/storage1/fs1/dspencer/Active $HOME:$HOME" bsub -g /dspencer/nextflow -G compute-dspencer -q dspencer -e nextflow_launcher.err -o nextflow_launcher.log -We 2:00 -n 2 -M 12GB -R "select[mem>=16000] span[hosts=1] rusage[mem=16000]" -a "docker(ghcr.io/dhslab/docker-nextflow)" nextflow run main.nf -profile test,ris,dhslab --outdir results
```
### **Directory tree for test run output:**

```
.
├── multiqc
│   ├── multiqc_data
│   └── multiqc_plots
│       ├── pdf
│       ├── png
│       └── svg
├── pipeline_info
└── samples
    ├── sample_1
    │   ├── fastq
    │   ├── methylation_calls
    │   │   ├── accumulated
    │   │   └── stranded
    │   ├── pepper
    │   │   ├── haplotagged_bam
    │   │   └── vcf
    │   └── qc
    │       ├── mosdepth
    │       └── pycoqc
    └── sample_2
        ├── fastq
        ├── methylation_calls
        │   ├── accumulated
        │   └── stranded
        ├── pepper
        │   ├── haplotagged_bam
        │   └── vcf
        └── qc
            ├── mosdepth
            └── pycoqc
```


### Notes:
- The pipeline is developed and optimized to be run in WashU RIS (LSF) HPC, but could be deployed in any [`HPC environment supported by Nextflow`](https://www.nextflow.io/docs/latest/executor.html).
- The pipeline does NOT support conda because some of the tools used are not available as conda packages.
- The pipeline can NOT be fully tested in a personal computer as basecalling step is computationally intense even for small test files. For testing/development purposes, the pipeline can be run in [`stub`](https://www.nextflow.io/docs/latest/process.html#stub) (dry-run) mode (see below).

**Stub (dry-run) for testing and development purposes**
- `stub` run requires `aws cli` and `docker` (or any other Containerization software)
- steps:
   1. download the pipeline
   2. download the `stub-data` results generated from pre-run test analysis (requires `aws cli` installed). It should be downloaded in the pipeline directory (`wgsnano/`)
   3. Run the pipeline in `stub` mode
```
git clone https://github.com/dhslab/nf-core-wgsnano.git
cd wgsnano/
aws s3 sync s3://davidspencerlab/nextflow/wgsnano/test-datasets/stub-test/ stub-test/ --no-sign-request
nextflow run main.nf -stub -profile test,docker --outdir results
```

