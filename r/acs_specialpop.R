# acs_specialpop.R ----
# What:   ACS special-population tables for Fauquier County, Warrenton, Bealeton, and Virginia.
#         Point-in-time vintage: 2020-2024 ACS 5-year (no trend). Raw pulls + label lookups only;
#         collapsing/derivation (disability age bands, single-parent families, older-householder
#         tenure) happens in the Ch 5 build (Session 10) per the read_rds-only data-flow rule.
# Tables: B18101 (sex×age×disability), B11003 (family type by presence/age of own children),
#         S1702 (poverty status of families — SUBJECT table), B25007 (tenure by age of householder).
#         NOTE: B11007 (households by age of householder, 65+) is NOT pulled here — it already lives
#         in data/acs_demographics.rds$b11007; Ch 5 reads it from there.
# Source: tidycensus (ACS 5-year 2024)
# Output: data/acs_specialpop.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
stopifnot(Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier <- "51061"
towns    <- c(warrenton = "5183136", bealeton = "5105336")
virginia <- "51"

# Standard pull: Fauquier + towns + VA (no benchmark counties, per §5). Guarded cv — special-pop
# place cells (esp. Bealeton) are thin; guard the ratio against estimate == 0 / NA.
pull_acs_bind <- function(table) {
  bind_rows(
    get_acs(geography = "county", state = "VA", table = table,
            year = 2024, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID == fauquier) |>
      mutate(geo_type = "county"),
    get_acs(geography = "place", state = "VA", table = table,
            year = 2024, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID %in% unname(towns)) |>
      mutate(geo_type = "place"),
    get_acs(geography = "state", state = "VA", table = table,
            year = 2024, survey = "acs5", cache_table = TRUE) |>
      mutate(geo_type = "state")
  ) |>
    mutate(cv = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_))
}

## 2. Point-in-time special-population tables ----
b18101 <- pull_acs_bind("B18101")   # Sex by age by disability status
b11003 <- pull_acs_bind("B11003")   # Family type by presence/age of own children
s1702  <- pull_acs_bind("S1702")    # Poverty status of families (subject table)
b25007 <- pull_acs_bind("B25007")   # Tenure by age of householder

## 3. Variable label lookups (stored for chapter use) ----
# Detail and subject variables live in different dictionaries. Split labels on "!!" to a depth
# that fits each table (B18101=5, B11003=6, B25007=4, S1702=7). The C01/C02/C03 column dimension
# of the subject table is carried in `name` (the full variable id), so chapters key on `name`.
vars_detail  <- load_variables(2024, "acs5", cache = TRUE)
vars_subject <- load_variables(2024, "acs5/subject", cache = TRUE)

extract_vars <- function(v, prefix, depth) {
  v |>
    filter(str_starts(name, prefix)) |>
    separate_wider_delim(label, "!!",
                         names = c("est", paste0("col", 2:depth)),
                         too_few = "align_start", too_many = "drop")
}

vars_list <- list(
  b18101 = extract_vars(vars_detail,  "B18101_", 5),
  b11003 = extract_vars(vars_detail,  "B11003_", 6),
  b25007 = extract_vars(vars_detail,  "B25007_", 4),
  s1702  = extract_vars(vars_subject, "S1702_",  7)
)

## 4. Write output ----
write_rds(
  list(b18101 = b18101, b11003 = b11003, s1702 = s1702, b25007 = b25007,
       vars = vars_list),
  "data/acs_specialpop.rds"
)
message("Wrote data/acs_specialpop.rds")

## 5. Validate ----
out <- read_rds("data/acs_specialpop.rds")
fc  <- function(tbl, v) out[[tbl]] |> filter(GEOID == fauquier, variable == v) |> pull(estimate)

b25007_tot <- fc("b25007", "B25007_001")   # total occupied HH  ≈ 26,720
b11003_tot <- fc("b11003", "B11003_001")   # total families
b18101_tot <- fc("b18101", "B18101_001")   # civilian noninstitutionalized population ≈ county pop
s1702_tot  <- fc("s1702",  "S1702_C01_001") # total families (subject) — should ≈ B11003_001

message("  Fauquier B25007_001 (occupied HH): ", b25007_tot, " (≈ 26,720)")
message("  Fauquier B11003_001 (families):    ", b11003_tot)
message("  Fauquier B18101_001 (civ. noninst. pop): ", b18101_tot, " (≈ county pop ~74,577)")
message("  Fauquier S1702_C01_001 (families): ", s1702_tot, " (≈ B11003_001)")

n_places <- out$b25007 |> filter(geo_type == "place") |> distinct(GEOID) |> nrow()
message("  Places present: ", n_places, " | S1702 vars captured: ", nrow(out$vars$s1702))

stopifnot(
  between(b25007_tot, 24000, 29000),                 # occupied HH near the ACS 26,720 baseline
  between(b11003_tot, 15000, 25000),                 # total families (plausible for ~26.7k HH)
  between(b18101_tot, 70000, 78000),                 # civ. noninstitutionalized ≈ county population
  abs(s1702_tot - b11003_tot) / b11003_tot < 0.05,   # subject family total reconciles with B11003
  n_places == 2,                                     # Warrenton + Bealeton both present
  all(c("b18101", "b11003", "s1702", "b25007") %in% names(out)),
  nrow(out$vars$s1702) > 0
)
message("acs_specialpop.R validation passed.")
