# Source Data Files

This directory should contain the OpenPedCan data release files needed to build the Parquet expression database.

## Required files

To run the preprocessing script (`scripts/01-build-expression-parquet.R`), place the following files in this directory:

### From OpenPedCan/haydar-r01 data release:

1. **histologies.tsv** — main histologies file with tumor and control metadata
2. **gene-expression-rsem-tpm-collapsed.rds** — tumor TPM expression matrix
3. **gtex_gene-expression-rsem-tpm-collapsed.rds** — GTEx TPM expression matrix
4. **ped-normal-brain-gene-expression-rsem-tpm.all.rds** — pediatric normal brain TPM matrix
5. **evodevo_gene-expression-rsem-tpm-collapsed.all.rds** — evo-devo TPM matrix
6. **ped-normal-brain-histologies.tsv** — pediatric normal brain metadata
7. **evodevo-histologies.tsv** — evo-devo metadata
8. **gtex-samples-by-age.tsv** — GTEx age metadata (from `analyses/ADAM10-tumor-normal-expr/input/`)
9. **independent-specimens.rnaseq.primary-plus-pre-release.tsv** — independent specimen list

## How to obtain these files

### Option 1: Copy from an existing haydar-r01 clone

If you have the haydar-r01 repository cloned locally with data downloaded:

```bash
# From the OpenPedCanExpress root directory
cp ../haydar-r01/data/histologies.tsv data/source/
cp ../haydar-r01/data/gene-expression-rsem-tpm-collapsed.rds data/source/
cp ../haydar-r01/data/gtex_gene-expression-rsem-tpm-collapsed.rds data/source/
cp ../haydar-r01/data/ped-normal-brain-gene-expression-rsem-tpm.all.rds data/source/
cp ../haydar-r01/data/evodevo_gene-expression-rsem-tpm-collapsed.all.rds data/source/
cp ../haydar-r01/data/ped-normal-brain-histologies.tsv data/source/
cp ../haydar-r01/data/evodevo-histologies.tsv data/source/
cp ../haydar-r01/data/independent-specimens.rnaseq.primary-plus-pre-release.tsv data/source/
cp ../haydar-r01/analyses/ADAM10-tumor-normal-expr/input/gtex-samples-by-age.tsv data/source/
```

### Option 2: Download directly from the data release

```bash
# Set the release URL and version
URL="https://s3.amazonaws.com/bti-openaccess-us-east-1-bti-bfx/haydar-r01"
RELEASE="v2"

# Download files
cd data/source
curl -O $URL/$RELEASE/histologies.tsv
curl -O $URL/$RELEASE/gene-expression-rsem-tpm-collapsed.rds
curl -O $URL/$RELEASE/gtex_gene-expression-rsem-tpm-collapsed.rds
curl -O $URL/$RELEASE/ped-normal-brain-gene-expression-rsem-tpm.all.rds
curl -O $URL/$RELEASE/evodevo_gene-expression-rsem-tpm-collapsed.all.rds
curl -O $URL/$RELEASE/ped-normal-brain-histologies.tsv
curl -O $URL/$RELEASE/evodevo-histologies.tsv
curl -O $URL/$RELEASE/independent-specimens.rnaseq.primary-plus-pre-release.tsv

# GTEx age file requires cloning haydar-r01 or downloading separately
# (it's in analyses/ subdirectory, not the main data release)
```

## After placing files here

Run the preprocessing script to generate the Parquet files:

```bash
cd ../..  # back to repo root
Rscript scripts/01-build-expression-parquet.R
```

This will create partitioned Parquet files in `data/partitions/` that the web app loads.
