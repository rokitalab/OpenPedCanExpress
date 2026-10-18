# Dockerfile for OpenPedCanExpress preprocessing
# Builds the Parquet expression database from OpenPedCan RDS matrices

FROM rocker/tidyverse:4.5.2
LABEL maintainer="Rokita Lab"

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    bzip2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('DBI', 'duckdb', 'jsonlite', 'here'), repos='https://cloud.r-project.org')"

# Copy scripts
COPY scripts/ /app/scripts/

# Set working directory
WORKDIR /app

# Default command: convert the expression matrices to Parquet, then build the partitions
# Mount data at /app/data when running container
CMD ["sh", "-c", "Rscript scripts/00-convert-source-to-parquet.R && Rscript scripts/01-build-expression-parquet.R"]
