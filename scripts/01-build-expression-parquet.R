#!/usr/bin/env Rscript
#
# 01-build-expression-parquet.R
#
# Builds the partitioned Parquet files the web app loads, from the long-format
# expression Parquet files made by 00-convert-source-to-parquet.R.
#
# Sample metadata is assembled in R (small tables); the join, filter, sort and
# partitioning of the ~200M expression rows is done by DuckDB, which streams
# from disk, so memory stays low.
#
# Input (expected in data/source/):
#   - histologies.tsv (or uses TAPESTRY cohort-histologies.tsv for plot groups)
#   - parquet/{tumor,gtex,pedbrain,evodevo}.parquet (from 00-convert-source-to-parquet.R)
#   - ped-normal-brain-histologies.tsv
#   - evodevo-histologies.tsv
#   - gtex-histologies.tsv (QC-passed GTEx samples; defines which samples to keep)
#   - independent-specimens.rnaseqpanel.primary.tsv
#
# Output (written to data/partitions/):
#   - genes_A-D.parquet, genes_E-H.parquet, ... (partitioned by gene symbol)
#   - manifest.json (list of partition files + metadata)
#

library(tidyverse)
library(DBI)
library(duckdb)
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

message("\n[1/4] Loading metadata...")

# Load both histologies files:
# - TAPESTRY cohort-histologies.tsv for tumor plot_group
# - OpenPedCan histologies.tsv for GTEx metadata
# Expected at data/source/cohort-histologies.tsv (copy from the TAPESTRY
# tumor-enriched-splicing repo:
# analyses/00-create-cohort-histologies/results/cohort-histologies.tsv).
tapestry_histologies <- read_tsv(
  file.path(source_dir, "cohort-histologies.tsv"),
  show_col_types = FALSE
)

# OpenPedCan histologies (tumors)
openpedcan_histologies <- read_tsv(
  file.path(source_dir, "histologies.tsv"),
  show_col_types = FALSE
)

# Independent specimens (primary tumors only, RNA-Seq only; one specimen per
# participant within each cohort)
independent_specimens <- read_tsv(
  file.path(source_dir, "independent-specimens.rnaseqpanel.primary.eachcohort.tsv"),
  show_col_types = FALSE
) %>%
  filter(
    experimental_strategy == "RNA-Seq",
    tumor_descriptor %in% c("Initial CNS Tumor", "Primary Tumor")
  ) %>%
  pull(Kids_First_Biospecimen_ID)

# GTEx histologies. Samples that failed QC were removed from this file, so it
# defines the samples we keep. Age comes in decade bins; <40 = 20-29 and 30-39.
gtex_histologies <- read_tsv(
  file.path(source_dir, "gtex-histologies.tsv"),
  show_col_types = FALSE
) %>%
  filter(gtex_age_years %in% c("20-29", "30-39"))

gtex_under40_samples <- gtex_histologies$Kids_First_Biospecimen_ID

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

message("  Loaded ", nrow(tapestry_histologies), " rows from TAPESTRY cohort-histologies.tsv")
message("  Loaded ", nrow(openpedcan_histologies), " rows from OpenPedCan histologies.tsv")
message("  ", length(independent_specimens), " independent primary tumor specimens")
message("  ", length(gtex_under40_samples), " GTEx <40yo samples")
message("  ", nrow(pedbrain_histologies), " pediatric normal brain samples")
message("  ", nrow(evodevo_histologies), " evo-devo samples")

# Tumor sample metadata
tumor_metadata_opc <- openpedcan_histologies %>%
  filter(
    sample_type == "Tumor",
    experimental_strategy == "RNA-Seq",
    cohort %in% c("PBTA", "TARGET", "GMKF", "DGD"),
    Kids_First_Biospecimen_ID %in% independent_specimens,
    # Exclude neuroblastoma specimens from the PBTA cohort
    !(cohort == "PBTA" & str_starts(coalesce(molecular_subtype, ""), "NBL, "))
  ) %>%
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
  ) %>%
  # Manual molecular_subtype corrections (e.g. unclassified MYCN status)
  left_join(
    read_tsv(
      file.path(source_dir, "molecular-subtype-overrides.tsv"),
      show_col_types = FALSE
    ) %>% rename(molecular_subtype_override = molecular_subtype),
    by = "sample_id"
  ) %>%
  mutate(
    molecular_subtype = coalesce(molecular_subtype_override, molecular_subtype)
  ) %>%
  select(-molecular_subtype_override)

# PBTA plot groups come from the current TAPESTRY cohort-histologies.tsv.
tumor_metadata_tapestry <- tapestry_histologies %>%
  select(
    sample_id = Kids_First_Biospecimen_ID,
    plot_group_tapestry = plot_group
  ) %>%
  select(sample_id, plot_group_tapestry)

# ==============================================================================
# Sample metadata for all cohorts (one row per sample per matrix)
# ==============================================================================

message("\n[2/4] Assembling sample metadata...")

meta_cols <- c(
  "matrix", "sample_id", "source_cohort", "plot_group", "broad_group", "cohort",
  "composition", "broad_histology", "molecular_subtype", "cancer_group",
  "primary_site", "RNA_library", "is_tumor", "is_control"
)

# --- Tumors --------------------------------------------------------------
# PBTA: only samples with a TAPESTRY plot group are kept (no short_histology
# fallback). Other cohorts fall back to short_histology; the app replaces
# those with cancer_group from plot-groups.tsv.
meta_tumor <- tumor_metadata_opc %>%
  left_join(tumor_metadata_tapestry, by = "sample_id") %>%
  mutate(
    plot_group = if_else(
      cohort == "PBTA",
      plot_group_tapestry,
      coalesce(plot_group_tapestry, short_histology)
    ),
    plot_group = if_else(plot_group == "DIPG or DMG", "Diffuse midline glioma", plot_group)
  ) %>%
  filter(!is.na(plot_group)) %>%
  mutate(
    matrix = "tumor",
    source_cohort = cohort,
    broad_group = plot_group,
    is_tumor = TRUE,
    is_control = FALSE
  )

# --- GTEx (<40yo, QC-passed samples in gtex-histologies.tsv) ---------------
# TAPESTRY labels: narrow = gtex_subgroup (e.g. "Brain - Cerebellum"),
# broad = gtex_group (e.g. "Brain")
meta_gtex <- gtex_histologies %>%
  transmute(
    matrix = "gtex",
    sample_id = Kids_First_Biospecimen_ID,
    source_cohort = "GTEx (<40yo)",
    plot_group = gtex_subgroup,
    broad_group = gtex_group,
    cohort = "GTEx",
    composition = "Normal",
    broad_histology = NA_character_,
    molecular_subtype = NA_character_,
    cancer_group = NA_character_,
    primary_site = gtex_subgroup,
    RNA_library,
    is_tumor = FALSE,
    is_control = TRUE
  )

# --- Pediatric normal brain -------------------------------------------------
# The TPM columns are SRR accessions, which are in the histologies' sample_id
# column (Kids_First_Biospecimen_ID holds GSM IDs).
meta_pedbrain <- pedbrain_histologies %>%
  transmute(
    matrix = "pedbrain",
    sample_id,
    source_cohort = "Pediatric Normal Brain",
    plot_group = primary_site,
    broad_group = primary_site,
    cohort = "Ped Normal Brain",
    composition = "Normal",
    broad_histology = NA_character_,
    molecular_subtype = NA_character_,
    cancer_group = NA_character_,
    primary_site,
    RNA_library,
    is_tumor = FALSE,
    is_control = TRUE
  )

# --- Evo-devo ----------------------------------------------------------------
# Labels follow TAPESTRY: "<tissue>-<timepoint>", e.g.
# "Forebrain-4 Weeks Post Conception" or "Heart-Neonate".
#   narrow (plot_group): tissue + exact timepoint
#   broad (broad_group): tissue + "Prenatal" (all post-conception weeks) or
#                        "Postnatal" (neonate through elderly)
meta_evodevo <- evodevo_histologies %>%
  mutate(
    timepoint = str_replace(str_trim(pathology_free_text_diagnosis), "Week Post", "Weeks Post"),
    prenatal = str_detect(timepoint, "Post Conception")
  ) %>%
  transmute(
    matrix = "evodevo",
    sample_id = Kids_First_Biospecimen_ID,
    source_cohort = "Evo-devo",
    plot_group = paste0(primary_site, "-", timepoint),
    broad_group = paste0(primary_site, "-", if_else(prenatal, "Prenatal", "Postnatal")),
    cohort = "Evo-devo",
    composition = "Normal",
    broad_histology = NA_character_,
    molecular_subtype = NA_character_,
    cancer_group = NA_character_,
    primary_site,
    RNA_library,
    is_tumor = FALSE,
    is_control = TRUE
  )

sample_meta <- bind_rows(
  select(meta_tumor, all_of(meta_cols)),
  select(meta_gtex, all_of(meta_cols)),
  select(meta_pedbrain, all_of(meta_cols)),
  select(meta_evodevo, all_of(meta_cols))
)

dups <- sample_meta %>% count(matrix, sample_id) %>% filter(n > 1)
if (nrow(dups) > 0) {
  stop("Duplicate sample IDs in metadata: ", paste(head(dups$sample_id, 5), collapse = ", "))
}
message("  Samples with metadata: ", paste(
  names(table(sample_meta$matrix)), table(sample_meta$matrix), sep = "=", collapse = ", "))

# ==============================================================================
# Join, sort and partition with DuckDB
# ==============================================================================

message("\n[3/4] Joining expression to metadata and writing partitions (DuckDB)...")

parquet_dir <- file.path(source_dir, "parquet")
matrices <- c("tumor", "gtex", "pedbrain", "evodevo")
missing_files <- matrices[!file.exists(file.path(parquet_dir, paste0(matrices, ".parquet")))]
if (length(missing_files) > 0) {
  stop("Missing converted Parquet for: ", paste(missing_files, collapse = ", "),
       ". Run scripts/00-convert-source-to-parquet.R first.")
}

con <- dbConnect(duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
tmp_dir <- file.path(output_dir, "_duckdb_tmp")
dir.create(tmp_dir, showWarnings = FALSE)
dbExecute(con, sprintf("SET memory_limit = '%s'", Sys.getenv("DUCKDB_MEMORY_LIMIT", "20GB")))
dbExecute(con, sprintf("SET temp_directory = '%s'", tmp_dir))
duckdb_register(con, "sample_meta", sample_meta)

# Non-matrix columns, in the app's expected order
out_cols <- c(
  "source_cohort", "plot_group", "broad_group", "cohort", "composition",
  "broad_histology", "molecular_subtype", "cancer_group", "primary_site",
  "RNA_library", "is_tumor", "is_control"
)

manifest <- list()
total_rows <- 0
all_genes <- character()

for (partition_name in names(gene_partitions)) {
  message(sprintf("\nProcessing partition %s...", partition_name))
  letters_in_partition <- gene_partitions[[partition_name]]
  letter_list <- paste0("'", letters_in_partition, "'", collapse = ", ")

  # Each starting letter is joined and sorted separately into a small piece
  # file, then the pieces are concatenated in letter order. This gives the same
  # gene-sorted output as one global ORDER BY (row-group min/max stats let the
  # app's single-gene queries skip most of the file) but sorts ~1/10th of the
  # rows at a time, so DuckDB's temp-disk spill stays small.
  piece_dir <- file.path(tmp_dir, partition_name)
  dir.create(piece_dir, showWarnings = FALSE)
  piece_files <- character()

  for (letter in letters_in_partition) {
    # One SELECT per matrix, inner-joined to that matrix's metadata. The inner
    # join is what drops samples with no metadata (QC-removed GTEx,
    # non-independent tumors, unannotated columns, ...).
    selects <- vapply(matrices, function(m) {
      sprintf(
        "SELECT e.gene_symbol, e.sample_id, e.tpm, %s
           FROM read_parquet('%s') e
           JOIN sample_meta m ON m.matrix = '%s' AND m.sample_id = e.sample_id
          WHERE substr(e.gene_symbol, 1, 1) = '%s'",
        paste0("m.", out_cols, collapse = ", "),
        file.path(parquet_dir, paste0(m, ".parquet")), m, letter
      )
    }, character(1))

    piece <- file.path(piece_dir, paste0(letter, ".parquet"))
    dbExecute(con, sprintf(
      "COPY (SELECT * FROM (%s) ORDER BY gene_symbol, sample_id) TO '%s' (FORMAT parquet)",
      paste(selects, collapse = "\n UNION ALL \n"), piece
    ))
    message("  ", letter, ": ", format(
      dbGetQuery(con, sprintf("SELECT count(*) n FROM read_parquet('%s')", piece))$n, big.mark = ","), " rows")
    piece_files <- c(piece_files, piece)
  }

  output_file <- file.path(output_dir, paste0("genes_", partition_name, ".parquet"))
  keep <- piece_files[file.size(piece_files) > 0]
  dbExecute(con, sprintf(
    "COPY (SELECT * FROM read_parquet([%s])) TO '%s' (FORMAT parquet)",
    paste0("'", keep, "'", collapse = ", "), output_file
  ))
  unlink(piece_dir, recursive = TRUE)

  stats <- dbGetQuery(con, sprintf(
    "SELECT count(DISTINCT gene_symbol) n_genes, count(*) n_rows FROM read_parquet('%s')",
    output_file
  ))
  file_size_mb <- file.size(output_file) / 1024^2
  message(sprintf("  %s: %s genes, %s rows, %.1f MB",
                  partition_name,
                  format(stats$n_genes, big.mark = ","),
                  format(stats$n_rows, big.mark = ","),
                  file_size_mb))

  manifest[[partition_name]] <- list(
    file = basename(output_file),
    letters = letters_in_partition,
    n_genes = stats$n_genes,
    n_rows = stats$n_rows,
    size_mb = round(file_size_mb, 2)
  )
  total_rows <- total_rows + stats$n_rows
}

# ==============================================================================
# Manifest
# ==============================================================================

message("\n[4/4] Writing manifest...")

all_files <- paste0("'", file.path(output_dir, vapply(manifest, `[[`, "", "file")), "'", collapse = ", ")
totals <- dbGetQuery(con, sprintf(
  "SELECT count(DISTINCT gene_symbol) n_genes, count(DISTINCT sample_id) n_samples
     FROM read_parquet([%s])", all_files
))
unlink(tmp_dir, recursive = TRUE)

manifest_file <- file.path(output_dir, "manifest.json")
write_json(
  list(
    generated_at = Sys.time(),
    total_genes = totals$n_genes,
    total_samples = totals$n_samples,
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
message(sprintf("Total genes: %s", format(totals$n_genes, big.mark = ",")))
message(sprintf("Total samples: %s", format(totals$n_samples, big.mark = ",")))
message(sprintf("Total rows: %s", format(total_rows, big.mark = ",")))
message(sprintf("Manifest: %s", manifest_file))
message(sprintf("Parquet files: %s", output_dir))
