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
        .map { create_fast5_channel(it) }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fast5_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.id
    meta.sample         = row.sample
    meta.flowcell         = row.flowcell
    meta.batch         = row.batch
    meta.kit         = row.kit

    // add path(s) of the fast5 files to the meta map
    def fast5_meta = []
        fast5_meta = [ meta, row.fast5_path ]
    return fast5_meta
}
