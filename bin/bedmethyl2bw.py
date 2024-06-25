#!/usr/bin/env python3

import argparse
import pyBigWig
import gzip
import re
import os
import sys

def parse_arguments():
    parser = argparse.ArgumentParser(description='Process a BED methylation file and output a BigWig file.')
    parser.add_argument('-c', '--chromsizes', required=True, help='FAI file with chromosome sizes')
    parser.add_argument('-b', '--bedmethyl', required=True, help='BEDMethyl file')
    parser.add_argument('-m', '--modification', default='m', help='Modification to extract, from column 4')
    parser.add_argument('-o', '--outfile', required=False, help='Output BigWig file')
    return parser.parse_args()

def read_chrom_sizes(fai_file):
    chrom_sizes = []
    if not fai_file.endswith('fai'):
        if os.path.exists(fai_file + '.fai'):
            fai_file = fai_file + '.fai'
        else:
            print(f"Error: Chromosome sizes file '{fai_file}' not found.")
            sys.exit(1)

    with open(fai_file, 'r') as f:
        for line in f:
            fields = line.strip().split('\t')
            chrom = fields[0]
            size = int(fields[1])
            chrom_sizes.append((chrom, size))
    return chrom_sizes

def open_file(filename):
    if filename.endswith('.gz'):
        return gzip.open(filename, 'rt')
    else:
        return open(filename, 'r')

def process_bedmethyl_file(bedmethyl_file, chrom_sizes, mod_arg, output_file):
    # Create a new BigWig file
    bw = pyBigWig.open(output_file, "w")

    # Add header information from the chrom sizes file
    bw.addHeader(chrom_sizes)

    with open_file(bedmethyl_file) as infile:
        for line in infile:
            fields = line.strip().split('\t')
            if fields[3] == mod_arg:
                chrom = fields[0]
                start = int(fields[1])
                end = int(fields[2])
                score = float(fields[10]) / 100
                bw.addEntries(chrom, [start], values=[score], span=end-start+1)

    bw.close()

def main():
    args = parse_arguments()

    # Read chromosome sizes from FAI file
    chrom_sizes = read_chrom_sizes(args.chromsizes)

    # Determine the output file name
    if args.outfile:
        output_file = args.outfile
    else:
        output_file = re.sub(r'\.bedmethyl(\.gz)?$', '.bw', args.bedmethyl)

    # Process the BED methylation file
    process_bedmethyl_file(args.bedmethyl, chrom_sizes, args.modification, output_file)

if __name__ == '__main__':
    main()
