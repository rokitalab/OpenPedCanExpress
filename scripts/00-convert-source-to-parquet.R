#!/usr/bin/env Rscript
#
# 00-convert-source-to-parquet.R
#
# One-time conversion of the TPM matrices (RDS) in data/source/ to long-format
# Parquet files in data/source/parquet/ (gene_symbol, sample_id, tpm).
#
# Reading an RDS loads the whole matrix into memory, and pivoting it to long
# format in R is what made the build memory-hungry. Converted once, the build
# script (01) can stream the Parquet files through DuckDB instead. Rerun this
# only when a source matrix changes; files that already exist are skipped
# (set FORCE=1 to overwrite).
#
# Usage: Rscript scripts/00-convert-source-to-parquet.R
#
# Output (data/source/parquet/):
#   tumor.parquet, gtex.parquet, pedbrain.parquet, evodevo.parquet
#
# Samples are NOT filtered here; the build script filters by metadata.

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(dplyr)
  library(stringr)
})

root_dir <- here::here()
source_dir <- file.path(root_dir, "data", "source")
parquet_dir <- file.path(source_dir, "parquet")
dir.create(parquet_dir, showWarnings = FALSE, recursive = TRUE)

force <- Sys.getenv("FORCE") == "1"
chunk_size <- 250  # samples per chunk (250 x ~60k genes = ~15M rows)

# name -> list(file, type)
#   "wide":  data.frame with gene symbols as rownames, one column per sample
#   "gene_id": data.frame whose first column `gene_id` is "ENSG..._SYMBOL"
sources <- list(
  tumor = list(
    file = "gene-expression-rsem-tpm-collapsed.rds",
    type = "wide"
  ),
  gtex = list(
    file = "gtex-harmonized.gene-expression-rsem-tpm-collapsed.all.rds",
    type = "wide"
  ),
  pedbrain = list(
    file = "ped-normal-brain-gene-expression-rsem-tpm.all.rds",
    type = "gene_id"
  ),
  evodevo = list(
    file = "evodevo_gene-expression-rsem-tpm-collapsed.all.rds",
    type = "wide"
  )
)

con <- dbConnect(duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

convert_one <- function(name, spec) {
  out_file <- file.path(parquet_dir, paste0(name, ".parquet"))
  if (file.exists(out_file) && !force) {
    message("[", name, "] ", basename(out_file), " exists, skipping")
    return(invisible())
  }

  message("[", name, "] reading ", spec$file, "...")
  x <- readRDS(file.path(source_dir, spec$file))

  if (spec$type == "gene_id") {
    # Extract gene symbol from "ENSGXXX.XX_SYMBOL"
    genes <- str_replace(x$gene_id, "^.*_", "")
    x$gene_id <- NULL
  } else {
    genes <- rownames(x)
  }
  samples <- colnames(x)
  message("  ", length(genes), " genes x ", length(samples), " samples")

  chunk_dir <- tempfile(paste0("chunks_", name, "_"))
  dir.create(chunk_dir)
  starts <- seq(1, length(samples), by = chunk_size)

  for (i in seq_along(starts)) {
    idx <- starts[i]:min(starts[i] + chunk_size - 1, length(samples))
    long <- data.frame(
      gene_symbol = rep(genes, times = length(idx)),
      sample_id = rep(samples[idx], each = length(genes)),
      tpm = as.vector(as.matrix(x[, idx, drop = FALSE])),
      stringsAsFactors = FALSE
    )
    duckdb_register(con, "chunk", long)
    dbExecute(con, sprintf(
      "COPY chunk TO '%s' (FORMAT parquet, COMPRESSION zstd)",
      file.path(chunk_dir, sprintf("chunk-%05d.parquet", i))
    ))
    duckdb_unregister(con, "chunk")
    message("  chunk ", i, "/", length(starts))
  }
  rm(x, long)
  invisible(gc())

  # Merge chunks into one file (no sort here: sorting hundreds of millions of
  # rows spills a lot of temp disk; the build script sorts the final partitions).
  message("  merging into ", basename(out_file), "...")
  dbExecute(con, sprintf(
    "COPY (SELECT * FROM read_parquet('%s/*.parquet'))
       TO '%s' (FORMAT parquet, COMPRESSION zstd)",
    chunk_dir, out_file
  ))
  unlink(chunk_dir, recursive = TRUE)

  n <- dbGetQuery(con, sprintf("SELECT count(*) n FROM read_parquet('%s')", out_file))$n
  message(sprintf("  done: %s rows, %.1f MB", format(n, big.mark = ","), file.size(out_file) / 1024^2))
}

dbExecute(con, "SET memory_limit = '16GB'")
dbExecute(con, sprintf("SET temp_directory = '%s'", tempdir()))

for (nm in names(sources)) convert_one(nm, sources[[nm]])

message("\nConverted files in ", parquet_dir)
