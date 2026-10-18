// OpenPedCanExpress release history (newest first).
// Versions match the data folders on S3 (v1, v1.1.0, v1.2.0). NOTE: dates are provisional.

export const RELEASES = [
  {
    version: "v1.2.0",
    date: "2026-10-18",
    current: true,
    summary:
      "`GTEx` and evo-devo controls now cover all tissues (not only brain), `PBTA` plot groups are updated to the current TAPESTRY groups, and neuroblastoma `MYCN` subtypes are updated.",
    changes: [
      "`GTEx <40` now includes all tissues: 2,481 samples from donors aged 20-39 across 30 tissue groups (53 subgroups). Only samples that passed QC (those in `gtex-histologies.tsv`) are used. Previously only brain regions were included.",
      "Evo-devo now includes all seven tissues: Forebrain, Hindbrain, Heart, Kidney, Liver, Ovary, and Testis (312 samples). Previously only Forebrain and Hindbrain were included.",
      "Evo-devo labels now match TAPESTRY and include the tissue, for example `Forebrain-4 Weeks Post Conception` and `Heart-Neonate` (`Newborn` is now `Neonate`, and `Week` is now `Weeks`).",
      "Evo-devo is grouped by `Prenatal / Postnatal for each tissue` by default (for example `Forebrain-Prenatal`, then `Forebrain-Postnatal`). `Group Evo-devo by` in `Configure Sample Groups` also offers `Exact timepoint (narrow)` (for example `Forebrain-4 Weeks Post Conception`) and `Tissue only` (one box per tissue covering all timepoints). `Group GTEx by` offers `Subgroup (narrow)` (for example `Brain - Cerebellum`, the default) and `Group (broad)` (for example `Brain`).",
      "New ways to select control groups: an `All <tissue>` checkbox for each GTEx and evo-devo tissue, `prenatal only` and `postnatal only` checkboxes for each evo-devo tissue, and tissue categories (such as `Reproductive Organs` and `Skin/Fat`) that select related GTEx and evo-devo tissues together.",
      "Sample counts (N) are shown in the axis labels by default, for example `Forebrain-Prenatal (N=32)`; turn them off with `Show sample count (N) in axis labels` in `Configure Sample Groups`. The counts follow the groups you select and how you group them, and are included in exports.",
      "New `Order Evo-devo by` option: `Tissue, then time` or `Time, then tissue` (for example all prenatal groups, then all postnatal groups).",
      "The first view shows GTEx brain regions, pediatric brain, and evo-devo prenatal and postnatal boxes for all seven tissues. Other GTEx tissues are one click away in `Configure Sample Groups`.",
      "`PBTA` plot groups now come from the current TAPESTRY cohort histologies (v3). New groups: `Pineoblastoma` and `Rare CNS tumor`; `Schwannoma` is now `Schwannoma/MPNST`; `Other tumor` is no longer used. `PBTA` now has 1,276 samples (1,284 in v1.1.0).",
      "Neuroblastoma `MYCN` subtypes are updated from the OpenPedCan-Project subtyping branch (`rokita/subtyping-integrate`). `MYCN` status now uses copy number amplification, then the clinical report, then expression. About 110 `TARGET` and `GMKF` specimens that were `NBL, MYCN amplified` in `OpenPedCan v15` are now `NBL, MYCN non-amplified`; their clinical status is non-amplified and their `MYCN` expression is low. Counts shown: `GMKF` 23 amplified and 173 non-amplified, `TARGET` 32 amplified and 117 non-amplified. This replaces the v1.1.0 correction for participant PASXIE.",
      "New `Top facet labels` option in `Configure Sample Groups` for the labels above the plot (`PBTA`, `TARGET`, `GMKF`, ...): `Auto` (the default) puts a multi-word label on two lines when it does not fit over its facet (for example `Pediatric` over `Brain`) and rotates it only when it still does not fit, such as a cohort with a single group; `Horizontal` and `Rotated` force one orientation; `Hidden` removes the labels. It also applies to exports.",
      "Fixed the leftmost x-axis label being cut off on the left when there are many groups or long labels. The plot and exports now widen the left margin to fit it.",
      "Fixed the `TARGET` `Neuroblastoma` group missing from `Configure Sample Groups`: groups with the same name in different cohorts are now listed and selected separately.",
      "Expression files are larger (about 1.2 GB across three files, 312 million rows) because of the added tissues. The app still reads only the parts it needs for the gene you search. Files are now sorted by gene.",
      "The page title now reads `Pediatric Tumor vs. Normal Gene Expression Explorer`.",
    ],
  },
  {
    version: "v1.1.0",
    date: "2026-10-04",
    summary:
      "Expression data from `OpenPedCan v15`, with `TARGET` and `GMKF` tumor cohorts added, tumor samples restricted to independent RNA-Seq specimens, and new documentation.",
    changes: [
      "Expression data is from the `OpenPedCan v15` data release.",
      "`TARGET` (1,125 samples) and `GMKF` (196 samples) tumor cohorts added. All cohorts are shown by default, each in its own facet; uncheck a cohort under `Cohorts` in `Configure Sample Groups` to hide it.",
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
