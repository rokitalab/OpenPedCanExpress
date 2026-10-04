// TAPESTRY color scheme
export const HISTOLOGY_COLORS = {
  "Atypical Teratoid Rhabdoid Tumor": "#4d0d85",
  "Choroid plexus tumor":             "#00441B",
  "Craniopharyngioma":                "#b2502d",
  "Diffuse midline glioma":           "#ff40d9",
  "Ependymoma":                       "#2200ff",
  "Germ cell tumor":                  "#0074d9",
  "Low-grade glioma":                 "#8f8fbf",
  "Medulloblastoma":                  "#a340ff",
  "Meningioma":                       "#2db398",
  "Mesenchymal tumor":                "#7fbf00",
  "Mixed neuronal-glial tumor":       "#685815",
  "Neurofibroma plexiform":           "#e6ac39",
  "Non-neoplastic tumor":             "#FFF5EB",
  "Oligodendroglioma":                "#D2B48C",
  "Other CNS embryonal tumor":        "#b08ccf",
  "Other high-grade glioma":          "#ffccf5",
  "Other tumor":                      "#b5b5b5",
  "Schwannoma":                       "#ab7200",

  // Non-CNS tumor groups from TARGET and GMKF (cancer_group)
  "Acute Lymphoblastic Leukemia":     "#d62728",
  "Acute Myeloid Leukemia":           "#8c1c13",
  "Neuroblastoma":                    "#ff7f0e",
  "Wilms tumor":                      "#17a2b8",
  "Rhabdoid tumor of the kidney":     "#1f4e79",
  "Clear cell sarcoma of the kidney": "#7fcdd8",
  "Osteosarcoma":                     "#556b2f",
};

export const CONTROL_COHORT_COLORS = {
  "GTEx (<40yo)": "#1f77b4",
  "Evo-devo": "#e67e22",
  "Pediatric Normal Brain": "#2ca02c",
  "Pediatric brain cell type": "#17becf",
};

export function histologyColor(plotGroup, fallback = "#b5b5b5") {
  // Strip molecular subtype suffix if present (e.g., "Medulloblastoma (MB, SHH)" -> "Medulloblastoma")
  const baseGroup = plotGroup.replace(/\s*\([^)]+\)\s*$/, '');
  return HISTOLOGY_COLORS[baseGroup] ?? fallback;
}

export function controlCohortColor(cohort, fallback = "#b5b5b5") {
  return CONTROL_COHORT_COLORS[cohort] ?? fallback;
}

export function groupColor(group) {
  return group.is_control
    ? controlCohortColor(group.source_cohort)
    : histologyColor(group.plot_group);
}

// Facet ordering
export const COHORT_FACET_NAMES = {
  "Pediatric brain cell type": "Cell of Origin",
  "Evo-devo": "Evo-devo",
  "Pediatric Normal Brain": "Pediatric Brain",
  "GTEx (<40yo)": "GTEx <40",
};

export const FACET_ORDER = [
  "PBTA",
  "TARGET",
  "GMKF",
  "Cell of Origin",
  "Evo-devo",
  "Pediatric Brain",
  "GTEx <40",
  "Cell Lines",
  "Other"
];

// Developmental order for evo-devo timepoints
export const EVODEVO_ORDER = [
  "4 Week Post Conception",
  "5 Week Post Conception",
  "6 Week Post Conception",
  "7 Week Post Conception",
  "8 Week Post Conception",
  "9 Week Post Conception",
  "10 Week Post Conception",
  "11 Week Post Conception",
  "12 Week Post Conception",
  "13 Week Post Conception",
  "16 Week Post Conception",
  "18 Week Post Conception",
  "19 Week Post Conception",
  "Newborn",
  "Infant",
  "Toddler",
  "School Age Child",
  "Adolescent",
  "Young Adult",
  "Middle Adult",
  "Elderly"
];

export function facetName(group) {
  // Tumor facets are named for their cohort (PBTA, TARGET, GMKF).
  if (group.is_tumor && !group.is_cell_line) return group.cohort || "PBTA";
  if (group.is_cell_line) return "Cell Lines";
  return COHORT_FACET_NAMES[group.source_cohort] ?? "Other";
}

export function evoDevoOrder(label) {
  const index = EVODEVO_ORDER.indexOf(label);
  return index === -1 ? 9999 : index;
}
