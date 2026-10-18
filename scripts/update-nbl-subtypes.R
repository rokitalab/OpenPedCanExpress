#!/usr/bin/env Rscript
#
# update-nbl-subtypes.R
#
# Regenerates data/source/molecular-subtype-overrides.tsv with the neuroblastoma
# (NBL) molecular subtypes from the OpenPedCan-Project subtyping branch, for the
# tumors the release histologies.tsv labels differently. 01-build-expression-
# parquet.R applies the file on top of the release's molecular_subtype.
#
# The branch's NBL calls use MYCN copy number, then the clinical MYCN status,
# then MYCN expression (analyses/molecular-subtyping/06-subtype-solid-tumors.R);
# the release labeled many tumors by expression alone.
#
# Usage: Rscript scripts/update-nbl-subtypes.R [path/to/OpenPedCan-Project]
#        (default: ../OpenPedCan-Project, with the branch checked out)
#
# Only NBL labels are taken (new label starts with "NBL, "), and only for the
# cohorts the app plots from histologies.tsv. Other subtype changes on the
# branch are not applied.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
})

args <- commandArgs(trailingOnly = TRUE)
root_dir <- here::here()
opc_dir <- if (length(args) >= 1) args[1] else file.path(dirname(root_dir), "OpenPedCan-Project")
new_file <- file.path(opc_dir, "analyses", "molecular-subtyping-integrate", "results", "histologies.tsv")
if (!file.exists(new_file)) stop("Not found: ", new_file)

git <- function(...) suppressWarnings(system2("git", c("-C", shQuote(opc_dir), ...), stdout = TRUE, stderr = FALSE))
message("OpenPedCan-Project: branch ", git("rev-parse", "--abbrev-ref", "HEAD"),
        ", commit ", git("rev-parse", "--short", "HEAD"))

release <- read_tsv(file.path(root_dir, "data", "source", "histologies.tsv"),
                    show_col_types = FALSE, guess_max = 1e5) %>%
  select(Kids_First_Biospecimen_ID, cohort, release_subtype = molecular_subtype)
new <- read_tsv(new_file, show_col_types = FALSE, guess_max = 1e5) %>%
  select(Kids_First_Biospecimen_ID, new_subtype = molecular_subtype)

overrides <- release %>%
  inner_join(new, by = "Kids_First_Biospecimen_ID") %>%
  filter(
    cohort %in% c("TARGET", "GMKF", "DGD"),
    str_starts(coalesce(new_subtype, ""), "NBL, "),
    coalesce(release_subtype, "") != new_subtype
  )

message("Changes vs release (cohort, release -> new):")
print(overrides %>% count(cohort, release_subtype, new_subtype), n = Inf)

out_file <- file.path(root_dir, "data", "source", "molecular-subtype-overrides.tsv")
overrides %>%
  transmute(sample_id = Kids_First_Biospecimen_ID, molecular_subtype = new_subtype) %>%
  arrange(sample_id) %>%
  write_tsv(out_file)
message("Wrote ", nrow(overrides), " overrides to ", out_file)
