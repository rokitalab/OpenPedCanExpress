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
  "Pineoblastoma":                    "#FF2900",
  "Rare CNS tumor":                   "#9F0B62",
  "Schwannoma/MPNST":                 "#ab7200",

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

// Developmental order for evo-devo timepoints (TAPESTRY labels). "Prenatal" and
// "Postnatal" are the broad groupings of post-conception weeks and of neonate-onward.
export const EVODEVO_ORDER = [
  "4 Weeks Post Conception",
  "5 Weeks Post Conception",
  "6 Weeks Post Conception",
  "7 Weeks Post Conception",
  "8 Weeks Post Conception",
  "9 Weeks Post Conception",
  "10 Weeks Post Conception",
  "11 Weeks Post Conception",
  "12 Weeks Post Conception",
  "13 Weeks Post Conception",
  "16 Weeks Post Conception",
  "18 Weeks Post Conception",
  "19 Weeks Post Conception",
  "Prenatal",
  "Neonate",
  "Infant",
  "Toddler",
  "School Age Child",
  "Adolescent",
  "Young Adult",
  "Middle Adult",
  "Elderly",
  "Postnatal"
];

// Evo-devo tissues, in display order (brain regions first)
export const EVODEVO_TISSUES = ["Forebrain", "Hindbrain", "Heart", "Kidney", "Liver", "Ovary", "Testis"];

export function facetName(group) {
  // Tumor facets are named for their cohort (PBTA, TARGET, GMKF).
  if (group.is_tumor && !group.is_cell_line) return group.cohort || "PBTA";
  if (group.is_cell_line) return "Cell Lines";
  return COHORT_FACET_NAMES[group.source_cohort] ?? "Other";
}

// Evo-devo labels are "<tissue>-<timepoint>". Ordering modes:
//   'tissue': by tissue, then developmental time (each tissue's timepoints together)
//   'time':   by developmental time, then tissue (e.g. all Prenatal groups, then all Postnatal)
export function evoDevoOrder(label, mode = 'tissue') {
  const dash = label.indexOf('-');
  const tissue = dash === -1 ? label : label.slice(0, dash);
  const time = dash === -1 ? "" : label.slice(dash + 1);
  const tissueIdx = EVODEVO_TISSUES.indexOf(tissue);
  // A bare tissue ("Forebrain", all timepoints in one group) sorts by tissue
  const timeIdx = dash === -1 ? 0 : EVODEVO_ORDER.indexOf(time);
  if (tissueIdx === -1 || timeIdx === -1) return 9999;
  return mode === 'time' ? timeIdx * 100 + tissueIdx : tissueIdx * 100 + timeIdx;
}

// Tissue categories, for selecting related GTEx and Evo-devo tissues together. Keys are
// tissue names as they appear in the labels: GTEx gtex_group and the first part of
// gtex_subgroup (e.g. "Artery" from "Artery - Aorta"), and the evo-devo tissues.
export const TISSUE_CATEGORIES = {
  "Brain & Nerve": ["Brain", "Nerve", "Forebrain", "Hindbrain"],
  "Reproductive Organs": ["Ovary", "Testis", "Uterus", "Vagina", "Prostate", "Fallopian Tube", "Cervix Uteri", "Cervix"],
  "Skin/Fat": ["Skin", "Adipose"],
  "Heart & Blood": ["Heart", "Blood", "Artery", "Spleen"],
  "Digestive": ["Colon", "Esophagus", "Small Intestine", "Stomach", "Liver", "Pancreas", "Minor Salivary Gland"],
  "Kidney & Bladder": ["Kidney", "Bladder"],
  "Endocrine": ["Adrenal Gland", "Thyroid", "Pituitary"],
  "Lung": ["Lung"],
  "Muscle": ["Muscle"],
  "Breast": ["Breast"],
  "Cell Lines": ["Cells"]
};

export function tissueCategory(tissue) {
  for (const [category, tissues] of Object.entries(TISSUE_CATEGORIES)) {
    if (tissues.includes(tissue)) return category;
  }
  return null;
}
