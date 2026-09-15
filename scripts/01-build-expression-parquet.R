#!/usr/bin/env Rscript
#
# 01-build-expression-parquet.R
#
# Builds long-format Parquet files from OpenPedCan TPM matrices for OpenPedCanExpress.
#
# Input (expected in data/source/):
#   - histologies.tsv
#   - gene-expression-rsem-tpm-collapsed.rds
#   - gtex_gene-expression-rsem-tpm-collapsed.rds
#   - ped-normal-brain-gene-expression-rsem-tpm.all.rds
#   - evodevo_gene-expression-rsem-tpm-collapsed.all.rds
#   - ped-normal-brain-histologies.tsv
#   - evodevo-histologies.tsv
#   - gtex-samples-by-age.tsv
#   - independent-specimens.rnaseq.primary-plus-pre-release.tsv
#
# Output (written to data/partitions/):
#   - genes_A-D.parquet, genes_E-H.parquet, ... (partitioned by gene symbol)
#   - manifest.json (list of partition files + metadata)
#

library(tidyverse)
library(nanoparquet)
library(jsonlite)

# ==============================================================================
# Configuration
# ==============================================================================

root_dir <- here::here()  # or rprojroot::find_root(rprojroot::has_dir(".git"))
source_dir <- file.path(root_dir, "data", "source")
output_dir <- file.path(root_dir, "data", "partitions")

# Create output directory if needed
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Define gene-symbol partitions
# Using 3 large partitions to reduce memory pressure during processing
# (fewer iterations = less peak memory usage)
gene_partitions <- list(
  "A-H" = c("A", "B", "C", "D", "E", "F", "G", "H"),
  "I-P" = c("I", "J", "K", "L", "M", "N", "O", "P"),
  "Q-Z" = c("Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z")
)

message("OpenPedCanExpress: Building expression Parquet files")
message("Source directory: ", source_dir)
message("Output directory: ", output_dir)

# ==============================================================================
# Load metadata
# ==============================================================================

message("\n[1/6] Loading metadata...")

# Main histologies file (tumors, GTEx, etc.)
histologies <- read_tsv(
  file.path(source_dir, "histologies.tsv"),
  show_col_types = FALSE
)

# Independent specimens (primary tumors only)
independent_specimens <- read_tsv(
  file.path(source_dir, "independent-specimens.rnaseq.primary-plus-pre-release.tsv"),
  show_col_types = FALSE
) %>%
  filter(tumor_descriptor %in% c("Initial CNS Tumor", "Primary Tumor")) %>%
  pull(Kids_First_Biospecimen_ID)

# GTEx age metadata (to filter <40 years)
gtex_age <- read_tsv(
  file.path(source_dir, "gtex-samples-by-age.tsv"),
  show_col_types = FALSE
)

gtex_under40_samples <- gtex_age %>%
  filter(AGE %in% c("20-29", "30-39")) %>%
  pull(Kids_First_Biospecimen_ID)

# Pediatric normal brain metadata
pedbrain_histologies <- read_tsv(
  file.path(source_dir, "ped-normal-brain-histologies.tsv"),
  show_col_types = FALSE
) %>%
  filter(Kids_First_Biospecimen_ID != "7316-7585")  # Exclude known outlier

# Evo-devo metadata
evodevo_histologies <- read_tsv(
  file.path(source_dir, "evodevo-histologies.tsv"),
  show_col_types = FALSE
)

message("  Loaded ", nrow(histologies), " rows from histologies.tsv")
message("  ", length(independent_specimens), " independent primary tumor specimens")
message("  ", length(gtex_under40_samples), " GTEx <40yo samples")
message("  ", nrow(pedbrain_histologies), " pediatric normal brain samples")
message("  ", nrow(evodevo_histologies), " evo-devo samples")

# ==============================================================================
# Load TPM matrices
# ==============================================================================

message("\n[2/6] Loading TPM matrices...")

# Tumor TPM (PBTA/OpenPedCan)
tumor_tpm <- readRDS(file.path(source_dir, "gene-expression-rsem-tpm-collapsed.rds"))
message("  Tumor TPM: ", nrow(tumor_tpm), " genes x ", ncol(tumor_tpm), " samples")

# GTEx TPM (pre-filtered to brain <40)
gtex_tpm <- readRDS(file.path(source_dir, "gtex-harmonized-gene-expression-rsem-tpm-collapsed.brain-under40.rds"))
message("  GTEx TPM (brain <40): ", nrow(gtex_tpm), " genes x ", ncol(gtex_tpm), " samples")

# Pediatric normal brain TPM
pedbrain_tpm <- readRDS(file.path(source_dir, "ped-normal-brain-gene-expression-rsem-tpm.all.rds"))
message("  Ped normal brain TPM: ", nrow(pedbrain_tpm), " rows x ", ncol(pedbrain_tpm), " cols")

# Evo-devo TPM
evodevo_tpm <- readRDS(file.path(source_dir, "evodevo_gene-expression-rsem-tpm-collapsed.all.rds"))
message("  Evo-devo TPM: ", nrow(evodevo_tpm), " genes x ", ncol(evodevo_tpm), " samples")

# ==============================================================================
# Process tumor samples
# ==============================================================================

message("\n[3/6] Processing tumor samples...")

# Filter columns BEFORE pivoting to save memory
tumor_samples_keep <- intersect(colnames(tumor_tpm), independent_specimens)
message("  Keeping ", length(tumor_samples_keep), " of ", ncol(tumor_tpm), " tumor samples")

tumor_long <- tumor_tpm %>%
  as.data.frame() %>%
  select(all_of(tumor_samples_keep)) %>%
  rownames_to_column("gene_symbol") %>%
  pivot_longer(
    cols = -gene_symbol,
    names_to = "sample_id",
    values_to = "tpm"
  ) %>%
  # Join metadata
  left_join(
    histologies %>%
      select(
        sample_id = Kids_First_Biospecimen_ID,
        cohort,
        composition,
        short_histology,
        broad_histology,
        molecular_subtype,
        cancer_group,
        RNA_library,
        primary_site
      ),
    by = "sample_id"
  ) %>%
  mutate(
    source_cohort = "PBTA",
    plot_group = short_histology,
    is_tumor = TRUE,
    is_control = FALSE
  )

message("  ", format(nrow(tumor_long), big.mark = ","), " tumor expression values")

# Save to temp file and free memory
temp_tumor_file <- file.path(output_dir, "_temp_tumor.rds")
saveRDS(tumor_long, temp_tumor_file)
rm(tumor_long, tumor_tpm, tumor_samples_keep)
gc()

# ==============================================================================
# Process GTEx samples
# ==============================================================================

message("\n[4/6] Processing GTEx samples...")

# GTEx file is already pre-filtered to brain <40, so just convert to long format
gtex_long <- gtex_tpm %>%
  as.data.frame() %>%
  rownames_to_column("gene_symbol") %>%
  pivot_longer(
    cols = -gene_symbol,
    names_to = "sample_id",
    values_to = "tpm"
  ) %>%
  # Join metadata
  left_join(
    histologies %>%
      filter(cohort == "GTEx") %>%
      select(
        sample_id = Kids_First_Biospecimen_ID,
        gtex_group,
        gtex_subgroup,
        RNA_library
      ),
    by = "sample_id"
  ) %>%
  mutate(
    source_cohort = "GTEx (<40yo)",
    plot_group = str_remove(gtex_subgroup, "Brain - "),
    cohort = "GTEx",
    composition = "Normal",
    short_histology = NA_character_,
    broad_histology = NA_character_,
    molecular_subtype = NA_character_,
    cancer_group = NA_character_,
    primary_site = gtex_subgroup,
    is_tumor = FALSE,
    is_control = TRUE
  )

message("  ", format(nrow(gtex_long), big.mark = ","), " GTEx expression values")

# Save to temp file and free memory
temp_gtex_file <- file.path(output_dir, "_temp_gtex.rds")
saveRDS(gtex_long, temp_gtex_file)
rm(gtex_long, gtex_tpm)
gc()

# ==============================================================================
# Process pediatric normal brain samples
# ==============================================================================

message("\n[5/6] Processing pediatric normal brain samples...")

# The ped-normal-brain RDS already has gene_id as first column (not rownames)
# Extract gene symbol from "ENSGXXX.XX_SYMBOL" format
pedbrain_long <- pedbrain_tpm %>%
  as.data.frame() %>%
  mutate(gene_symbol = str_replace(gene_id, "^.*_", "")) %>%
  select(-gene_id) %>%
  pivot_longer(
    cols = -gene_symbol,
    names_to = "sample_id",
    values_to = "tpm"
  ) %>%
  # Join metadata
  left_join(
    pedbrain_histologies %>%
      select(
        sample_id = Kids_First_Biospecimen_ID,
        primary_site,
        RNA_library
      ),
    by = "sample_id"
  ) %>%
  mutate(
    source_cohort = "Pediatric Normal Brain",
    plot_group = paste("Pediatric", primary_site),
    cohort = "Ped Normal Brain",
    composition = "Normal",
    short_histology = NA_character_,
    broad_histology = NA_character_,
    molecular_subtype = NA_character_,
    cancer_group = NA_character_,
    gtex_group = NA_character_,
    gtex_subgroup = NA_character_,
    is_tumor = FALSE,
    is_control = TRUE
  )

message("  ", format(nrow(pedbrain_long), big.mark = ","), " ped normal brain expression values")

# Save to temp file and free memory
temp_pedbrain_file <- file.path(output_dir, "_temp_pedbrain.rds")
saveRDS(pedbrain_long, temp_pedbrain_file)
rm(pedbrain_long, pedbrain_tpm)
gc()

# ==============================================================================
# Process evo-devo samples
# ==============================================================================

message("\n[6/6] Processing evo-devo samples...")

evodevo_long <- evodevo_tpm %>%
  as.data.frame() %>%
  rownames_to_column("gene_symbol") %>%
  pivot_longer(
    cols = -gene_symbol,
    names_to = "sample_id",
    values_to = "tpm"
  ) %>%
  # Join metadata
  left_join(
    evodevo_histologies %>%
      select(
        sample_id = Kids_First_Biospecimen_ID,
        primary_site,
        pathology_free_text_diagnosis,
        RNA_library
      ),
    by = "sample_id"
  ) %>%
  # Parse region and timepoint from pathology_free_text_diagnosis
  # Expected format: "Forebrain-4 Week Post Conception" or "Hindbrain-Neonate"
  mutate(
    region_timepoint = pathology_free_text_diagnosis,
    region = str_extract(region_timepoint, "^[^-]+"),
    timepoint = str_replace(region_timepoint, "^[^-]+-", "")
  ) %>%
  mutate(
    source_cohort = "Evo-devo",
    plot_group = region_timepoint,
    cohort = "Evo-devo",
    composition = "Normal",
    short_histology = NA_character_,
    broad_histology = NA_character_,
    molecular_subtype = NA_character_,
    cancer_group = NA_character_,
    gtex_group = NA_character_,
    gtex_subgroup = NA_character_,
    is_tumor = FALSE,
    is_control = TRUE
  )

message("  ", format(nrow(evodevo_long), big.mark = ","), " evo-devo expression values")

# Save to temp file and free memory
temp_evodevo_file <- file.path(output_dir, "_temp_evodevo.rds")
saveRDS(evodevo_long, temp_evodevo_file)
rm(evodevo_long, evodevo_tpm)
gc()

# ==============================================================================
# Partition by gene symbol and write Parquet (memory-efficient approach)
# ==============================================================================

message("\nPartitioning and writing Parquet files (processing one partition at a time)...")

# Free up metadata we no longer need
rm(histologies, pedbrain_histologies, evodevo_histologies, independent_specimens, gtex_age, gtex_under40_samples)
gc()

# Standardize column order for all cohorts
standard_cols <- c(
  "gene_symbol", "sample_id", "tpm",
  "source_cohort", "plot_group", "cohort", "composition",
  "short_histology", "broad_histology", "molecular_subtype",
  "cancer_group", "primary_site", "RNA_library",
  "is_tumor", "is_control"
)

manifest <- list()
total_rows <- 0
all_genes <- character()

for (partition_name in names(gene_partitions)) {
  message(sprintf("\nProcessing partition %s...", partition_name))
  letters_in_partition <- gene_partitions[[partition_name]]

  # Load each cohort from temp file, filter, and combine
  # Load one at a time to minimize peak memory usage
  message("  Loading tumor data...")
  tumor_partition <- readRDS(temp_tumor_file) %>%
    filter(str_sub(gene_symbol, 1, 1) %in% letters_in_partition) %>%
    select(all_of(standard_cols))

  message("  Loading GTEx data...")
  gtex_partition <- readRDS(temp_gtex_file) %>%
    filter(str_sub(gene_symbol, 1, 1) %in% letters_in_partition) %>%
    select(all_of(standard_cols))

  message("  Loading pediatric normal brain data...")
  pedbrain_partition <- readRDS(temp_pedbrain_file) %>%
    filter(str_sub(gene_symbol, 1, 1) %in% letters_in_partition) %>%
    select(all_of(standard_cols))

  message("  Loading evo-devo data...")
  evodevo_partition <- readRDS(temp_evodevo_file) %>%
    filter(str_sub(gene_symbol, 1, 1) %in% letters_in_partition) %>%
    select(all_of(standard_cols))

  # Combine just this partition
  message("  Combining cohorts...")
  partition_df <- bind_rows(
    tumor_partition,
    gtex_partition,
    pedbrain_partition,
    evodevo_partition
  )

  # Free memory
  rm(tumor_partition, gtex_partition, pedbrain_partition, evodevo_partition)
  gc()

  if (nrow(partition_df) == 0) {
    message(sprintf("  Skipping %s (no genes)", partition_name))
    next
  }

  output_file <- file.path(output_dir, paste0("genes_", partition_name, ".parquet"))

  write_parquet(partition_df, output_file)

  file_size_mb <- file.size(output_file) / 1024^2
  n_genes <- length(unique(partition_df$gene_symbol))
  n_rows <- nrow(partition_df)

  message(sprintf("  %s: %s genes, %s rows, %.1f MB",
                  partition_name,
                  format(n_genes, big.mark = ","),
                  format(n_rows, big.mark = ","),
                  file_size_mb))

  manifest[[partition_name]] <- list(
    file = basename(output_file),
    letters = letters_in_partition,
    n_genes = n_genes,
    n_rows = n_rows,
    size_mb = round(file_size_mb, 2)
  )

  total_rows <- total_rows + n_rows
  all_genes <- c(all_genes, unique(partition_df$gene_symbol))

  # Free memory for next iteration
  rm(partition_df)
  gc()
}

# Write manifest
manifest_file <- file.path(output_dir, "manifest.json")

# Count total unique samples across all cohorts
message("\nCounting total samples...")
temp_sample_counts <- length(unique(c(
  readRDS(temp_tumor_file)$sample_id,
  readRDS(temp_gtex_file)$sample_id,
  readRDS(temp_pedbrain_file)$sample_id,
  readRDS(temp_evodevo_file)$sample_id
)))

# Clean up temp files
message("Cleaning up temporary files...")
unlink(c(temp_tumor_file, temp_gtex_file, temp_pedbrain_file, temp_evodevo_file))

write_json(
  list(
    generated_at = Sys.time(),
    total_genes = length(unique(all_genes)),
    total_samples = temp_sample_counts,
    total_rows = total_rows,
    partitions = manifest
  ),
  manifest_file,
  pretty = TRUE,
  auto_unbox = TRUE
)

message("\n================================================================================")
message("Done!")
message("================================================================================")
message(sprintf("Total genes: %s", format(length(unique(all_genes)), big.mark = ",")))
message(sprintf("Total rows: %s", format(total_rows, big.mark = ",")))
message(sprintf("Manifest: %s", manifest_file))
message(sprintf("Parquet files: %s", output_dir))
