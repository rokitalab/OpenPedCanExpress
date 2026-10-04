// OpenPedCanExpress release history (newest first).
// Versions match the data folders on S3 (v1, v1.1.0). NOTE: dates are provisional.

export const RELEASES = [
  {
    version: "v1.1.0",
    date: "2026-10-04",
    current: true,
    summary:
      "Expression data from `OpenPedCan v15`, with `TARGET` and `GMKF` tumor cohorts added, tumor samples restricted to independent RNA-Seq specimens, and new documentation.",
    changes: [
      "Expression data is from the `OpenPedCan v15` data release.",
      "`TARGET` (1,125 samples) and `GMKF` (196 samples) tumor cohorts added. `PBTA` remains the default view; select `TARGET` or `GMKF` under `Cohorts` in `Configure Sample Groups`. Each cohort is shown in its own facet.",
      "Tumor facet headers are now named for their cohort (`PBTA`, `TARGET`, `GMKF`) instead of `Primary Tumors`.",
      "`TARGET` and `GMKF` samples are grouped by `cancer_group` (Acute Lymphoblastic Leukemia, Acute Myeloid Leukemia, Neuroblastoma, Osteosarcoma, Rhabdoid tumor of the kidney, Wilms tumor, Clear cell sarcoma of the kidney). Groups with 3 or fewer samples are not shown, and `Ganglioneuroblastoma` is combined with `Neuroblastoma`.",
      "Tumor samples are now limited to independent primary RNA-Seq specimens (one per participant within each cohort), from `independent-specimens.rnaseqpanel.primary.eachcohort.tsv`. Previously all RNA-Seq tumor samples in the expression matrix were used.",
      "PBTA plot groups are unchanged from the previous release (1,284 samples). Neuroblastoma specimens (`molecular_subtype` beginning with `NBL, `) were removed from PBTA.",
      "Molecular subtype correction: the unclassified neuroblastoma sample from participant PASXIE is now `NBL, MYCN amplified` in both `TARGET` and `GMKF`.",
      "Fixed the y-axis title overlapping the tick labels in plots, especially at smaller export font sizes.",
      "The `Configure Sample Groups` window is wider and easier to read, with histologies and control groups organized under cohort headings.",
      "Added this documentation page and release notes.",
    ],
  },
  {
    version: "v1.0.0",
    date: "2026-09-15",
    summary:
      "Initial release of OpenPedCanExpress, a browser-based explorer for gene expression in pediatric brain tumors versus normal controls.",
    changes: [
      "Genome-wide gene search with faceted box plots of `PBTA` tumor histologies against `GTEx` brain (<40 years), pediatric normal brain, and evo-devo developmental timepoints.",
      "Filter by cohort, histology, and molecular subtype, with an option to split histologies by molecular subtype.",
      "Interactive plots with per-sample tooltips and a `log2 scale` toggle, and export to PDF, JPG, PNG, or SVG with adjustable size.",
      "Expression data stored as Parquet files and queried in the browser with `DuckDB-WASM`; no server required.",
    ],
  },
];
