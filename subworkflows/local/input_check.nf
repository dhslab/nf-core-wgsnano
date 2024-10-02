//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_reads_channel(it) }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ reads ] ]
def create_reads_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.id
    meta.sample         = row.sample
    meta.flowcell         = row.flowcell
    meta.batch         = row.batch
    meta.kit         = row.kit
    meta.vcf          = row.vcf ?: "$projectDir/assets/NO_FILE.vcf"
    meta.vcf_tbi      = row.vcf_tbi ?: "$projectDir/assets/NO_FILE.vcf.tbi"

    // add path(s) of the reads files to the meta map
    def reads_meta = []
        reads_meta = [ meta, row.reads ]
    return reads_meta
}
