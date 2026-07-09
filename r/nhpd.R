# nhpd.R ----
# What:   Filter NHPD Virginia extract to Fauquier County; tidy subsidy program data
# Source: data/raw/nhpd/nhpd_virginia.xlsx
# Output: data/nhpd.rds

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Read and filter ----
message("Reading nhpd_virginia.xlsx (290-col XLSX — suppressing type warnings)...")

nhpd_raw <- suppressWarnings(
  read_excel("data/raw/nhpd/nhpd_virginia.xlsx")
) |>
  clean_names()

message("  Raw: ", nrow(nhpd_raw), " rows × ", ncol(nhpd_raw), " columns")

nhpd_fauquier <- nhpd_raw |>
  filter(str_detect(county, regex("fauquier", ignore_case = TRUE)))

message("  Fauquier properties: ", nrow(nhpd_fauquier))

## 3. Property-level summary frame ----
# Compute total assisted units as sum of all *_assisted_units columns
assisted_cols <- names(nhpd_fauquier)[str_detect(names(nhpd_fauquier), "_assisted_units")]

properties <- nhpd_fauquier |>
  mutate(
    total_assisted_units = rowSums(
      across(all_of(assisted_cols), as.numeric),
      na.rm = TRUE
    )
  ) |>
  select(
    nhpd_id            = nhpd_property_id,
    property_name,
    address            = property_address,
    city,
    zip,
    county,
    total_units,
    total_assisted_units,
    active_subsidies,
    earliest_expiration = earliest_end_date,
    latest_expiration   = latest_end_date,
    year_built          = earliest_construction_date,
    property_status
  ) |>
  mutate(
    across(c(total_units, total_assisted_units, active_subsidies), as.numeric),
    zip = as.character(zip)
  )

message("  Properties columns: ", ncol(properties))
message("  Total assisted units: ", sum(properties$total_assisted_units, na.rm = TRUE))

## 4. Program-level frame — one row per active subsidy per property ----
# NHPD encodes programs in blocks: s8_1_*, s8_2_*, lihtc_1_*, lihtc_2_*, etc.
# Pivot all *_program_name columns to long format
program_name_cols <- names(nhpd_fauquier)[str_detect(names(nhpd_fauquier), "_program_name$")]
message("  Program name columns (", length(program_name_cols), "): ",
        paste(program_name_cols[1:min(5, length(program_name_cols))], collapse = ", "), "...")

programs <- nhpd_fauquier |>
  select(
    nhpd_id = nhpd_property_id,
    all_of(program_name_cols),
    matches("_status$"),
    matches("_start_date$"),
    matches("_end_date$"),
    matches("_assisted_units$")
  ) |>
  pivot_longer(
    cols      = all_of(program_name_cols),
    names_to  = "program_slot",
    values_to = "program_name"
  ) |>
  filter(!is.na(program_name), program_name != "") |>
  mutate(
    # Extract program prefix (e.g. "s8_1" from "s8_1_program_name") for matching subsidy info
    slot_prefix = str_remove(program_slot, "_program_name$")
  )

message("  Active program records: ", nrow(programs))

## 5. Write output ----
write_rds(list(properties = properties, programs = programs), "data/nhpd.rds")
message("Wrote data/nhpd.rds")

## 6. Validate ----
out <- read_rds("data/nhpd.rds")
stopifnot(between(nrow(out$properties), 8, 25))
message("nhpd.R validation passed.")
message("  Properties: ", nrow(out$properties), " (benchmark ~13)")
message("  Total assisted units: ", sum(out$properties$total_assisted_units, na.rm = TRUE),
        " (benchmark ~750)")
