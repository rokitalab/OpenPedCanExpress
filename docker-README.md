# Rebuilding the data with Docker Compose

This rebuilds the Parquet expression files from the OpenPedCan source data.
It runs on any machine with Docker, so no cloud instance is needed.

## Quick start

1. Install [Docker](https://docs.docker.com/get-docker/) with Docker Compose.
2. Raise Docker's memory limit to at least 24 GB (Docker Desktop: Settings > Resources).
3. Put the source files in `data/source/`.
   See [data/source/README.md](data/source/README.md) for the list, including `cohort-histologies.tsv` from the TAPESTRY `tumor-enriched-splicing` repository.
4. Build and run:

   ```bash
   docker compose up --build
   ```

5. When it finishes, the Parquet files and `manifest.json` are in `data/partitions/`.

## Tips

- Watch progress with `docker compose logs -f`.
- Clean up with `docker compose down`.
- If the build stops with exit code 137, Docker ran out of memory; raise the memory limit and rerun.
- To publish the new data, upload the three `.parquet` files (and optionally `manifest.json`) to your S3 data folder.
