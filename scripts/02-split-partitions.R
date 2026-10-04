#!/usr/bin/env Rscript
#
# 02-split-partitions.R
#
# Splits existing Parquet partitions in half to stay under GitHub's 100MB file limit
#

library(tidyverse)
library(nanoparquet)
library(jsonlite)

output_dir <- "data/partitions"

message("Splitting Parquet partitions to stay under 100MB limit...")

# Define split scheme: each partition gets split in half by letter range
splits <- list(
  "A-H" = list(
    "A-D" = c("A", "B", "C", "D"),
    "E-H" = c("E", "F", "G", "H")
  ),
  "I-P" = list(
    "I-L" = c("I", "J", "K", "L"),
    "M-P" = c("M", "N", "O", "P")
  ),
  "Q-Z" = list(
    "Q-T" = c("Q", "R", "S", "T"),
    "U-Z" = c("U", "V", "W", "X", "Y", "Z")
  )
)

new_manifest <- list()

for (old_partition_name in names(splits)) {
  old_file <- file.path(output_dir, paste0("genes_", old_partition_name, ".parquet"))
  message(sprintf("\nProcessing %s...", old_partition_name))

  # Load the partition
  partition_data <- read_parquet(old_file)
  message(sprintf("  Loaded %s rows", format(nrow(partition_data), big.mark = ",")))

  # Split into two new partitions
  for (new_partition_name in names(splits[[old_partition_name]])) {
    letters_in_new_partition <- splits[[old_partition_name]][[new_partition_name]]

    new_partition_data <- partition_data %>%
      filter(str_sub(gene_symbol, 1, 1) %in% letters_in_new_partition)

    new_file <- file.path(output_dir, paste0("genes_", new_partition_name, ".parquet"))
    write_parquet(new_partition_data, new_file)

    file_size_mb <- file.size(new_file) / 1024^2
    n_genes <- length(unique(new_partition_data$gene_symbol))
    n_rows <- nrow(new_partition_data)

    message(sprintf("  %s: %s genes, %s rows, %.1f MB",
                    new_partition_name,
                    format(n_genes, big.mark = ","),
                    format(n_rows, big.mark = ","),
                    file_size_mb))

    new_manifest[[new_partition_name]] <- list(
      file = basename(new_file),
      letters = letters_in_new_partition,
      n_genes = n_genes,
      n_rows = n_rows,
      size_mb = round(file_size_mb, 2)
    )
  }

  # Remove old partition file
  message(sprintf("  Removing old file: %s", basename(old_file)))
  unlink(old_file)
}

# Write updated manifest
manifest_file <- file.path(output_dir, "manifest.json")

# Load old manifest to get totals
old_manifest <- read_json(manifest_file)

write_json(
  list(
    generated_at = Sys.time(),
    total_genes = old_manifest$total_genes,
    total_samples = old_manifest$total_samples,
    total_rows = old_manifest$total_rows,
    partitions = new_manifest
  ),
  manifest_file,
  pretty = TRUE,
  auto_unbox = TRUE
)

message("\n================================================================================")
message("Done!")
message("================================================================================")
message(sprintf("New partitions written to: %s", output_dir))
message(sprintf("Updated manifest: %s", manifest_file))
