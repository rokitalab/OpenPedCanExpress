# Source Data Files

This directory should contain the OpenPedCan data release files needed to build the Parquet expression database.

## Required files

To run the preprocessing script (`scripts/01-build-expression-parquet.R`), place the following files in this directory:

### From OpenPedCan data release:

1. **histologies.tsv** — main histologies file with tumor and control metadata
2. **gene-expression-rsem-tpm-collapsed.rds** — tumor TPM expression matrix (PBTA, TARGET, GMKF, DGD)
3. **gtex-harmonized-gene-expression-rsem-tpm-collapsed.brain-under40.rds** — GTEx brain TPM matrix (<40 years)
4. **ped-normal-brain-gene-expression-rsem-tpm.all.rds** — pediatric normal brain TPM matrix
5. **evodevo_gene-expression-rsem-tpm-collapsed.all.rds** — evo-devo TPM matrix
6. **ped-normal-brain-histologies.tsv** — pediatric normal brain metadata
7. **evodevo-histologies.tsv** — evo-devo metadata
8. **gtex-samples-by-age.tsv** — GTEx age metadata
9. **independent-specimens.rnaseqpanel.primary.tsv** — independent specimen list

### From TAPESTRY preprocessing repository:

10. **cohort-histologies.tsv** — TAPESTRY histologies with plot_group annotations
    - Located at: `analyses/00-create-cohort-histologies/results/cohort-histologies.tsv`
    - Repository: [TAPESTRY-data-preprocessing](https://github.com/d3b-center/TAPESTRY-data-preprocessing)

## How to obtain these files

Contact the Rokita Lab or OpenPedCan data maintainers for access to the required source files.

## After placing files here

Run the preprocessing script to generate the Parquet files:

```bash
cd ../..  # back to repo root
Rscript scripts/01-build-expression-parquet.R
```

This will create partitioned Parquet files in `data/partitions/` that the web app loads.
