#!/usr/bin/env Rscript
# Install required packages

packages <- c("tidyverse", "nanoparquet", "jsonlite", "here")

for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing ", pkg, "...")
    install.packages(pkg, repos = "https://cloud.r-project.org")
  } else {
    message(pkg, " already installed")
  }
}

message("\nAll dependencies installed!")
