# acs_stock.R ----
# What:   ACS housing stock tables for Fauquier County, Warrenton, Bealeton, and Virginia.
#         Anchor vintage: 2020-2024 ACS 5-year. Tenure trend: 2013, 2017, 2021, 2024.
# Tables: B25001, B25002, B25004, B25003 (trend), B25024, B25032,
#         B25034, B25035, B25036, B25041, B25042, B25014, B25047, B25051
# Source: tidycensus (ACS 5-year 2020-2024)
# Output: data/acs_stock.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier <- "51061"
towns    <- c(warrenton = "5183136", bealeton = "5105336")
virginia <- "51"

# Standard ACS pull: Fauquier + towns + VA. No benchmark counties (§5 spec: "county, towns, VA").
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
    mutate(cv = (moe / 1.645) / estimate * 100)
}

# Year-parameterized variant for B25003 tenure trend.
pull_acs_bind_year <- function(table, yr) {
  bind_rows(
    get_acs(geography = "county", state = "VA", table = table,
            year = yr, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID == fauquier) |>
      mutate(geo_type = "county"),
    get_acs(geography = "place", state = "VA", table = table,
            year = yr, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID %in% unname(towns)) |>
      mutate(geo_type = "place"),
    get_acs(geography = "state", state = "VA", table = table,
            year = yr, survey = "acs5", cache_table = TRUE) |>
      mutate(geo_type = "state")
  ) |>
    mutate(year = yr, cv = (moe / 1.645) / estimate * 100)
}

## 2. Point-in-time stock tables (2020-2024 anchor) ----
b25001 <- pull_acs_bind("B25001")   # Total housing units
b25002 <- pull_acs_bind("B25002")   # Occupancy status
b25004 <- pull_acs_bind("B25004")   # Vacancy status by type
b25024 <- pull_acs_bind("B25024")   # Units in structure (structure type mix)
b25032 <- pull_acs_bind("B25032")   # Tenure by units in structure
b25034 <- pull_acs_bind("B25034")   # Year structure built
b25035 <- pull_acs_bind("B25035")   # Median year structure built
b25036 <- pull_acs_bind("B25036")   # Year structure built, renter-occupied
b25041 <- pull_acs_bind("B25041")   # Bedrooms
b25042 <- pull_acs_bind("B25042")   # Bedrooms by tenure
b25014 <- pull_acs_bind("B25014")   # Occupants per room (crowding)
b25047 <- pull_acs_bind("B25047")   # Plumbing facilities
b25051 <- pull_acs_bind("B25051")   # Kitchen facilities

## 3. Variable label lookups (stored in output for chapter use) ----
vars_2024 <- load_variables(2024, "acs5", cache = TRUE)

extract_vars <- function(prefix) {
  vars_2024 |>
    filter(str_starts(name, prefix)) |>
    separate_wider_delim(label, "!!", names = c("est", "col2", "col3", "col4"),
                         too_few = "align_start", too_many = "drop")
}

table_prefixes <- c(
  b25001 = "B25001_", b25002 = "B25002_", b25004 = "B25004_", b25003 = "B25003_",
  b25024 = "B25024_", b25032 = "B25032_", b25034 = "B25034_", b25035 = "B25035_",
  b25036 = "B25036_", b25041 = "B25041_", b25042 = "B25042_",
  b25014 = "B25014_", b25047 = "B25047_", b25051 = "B25051_"
)

vars_list <- map(table_prefixes, extract_vars)

## 4. Tenure trend — B25003: 2013, 2017, 2021, 2024 ----
# PLAN.md §4: "trend tables back to 2010 for tenure."
# Anchor years: roughly non-overlapping 5-year windows covering 2009-2024.
# 2021/2024 overlap on survey year 2020 — acceptable; note in data-notes.qmd.
trend_years <- c(2013, 2017, 2021, 2024)
b25003_trend <- map_dfr(trend_years, \(yr) pull_acs_bind_year("B25003", yr))

## 5. Write output ----
write_rds(
  list(
    b25001       = b25001,
    b25002       = b25002,
    b25004       = b25004,
    b25003_trend = b25003_trend,
    b25024       = b25024,
    b25032       = b25032,
    b25034       = b25034,
    b25035       = b25035,
    b25036       = b25036,
    b25041       = b25041,
    b25042       = b25042,
    b25014       = b25014,
    b25047       = b25047,
    b25051       = b25051,
    vars         = vars_list
  ),
  "data/acs_stock.rds"
)
message("Wrote data/acs_stock.rds")

## 6. Validate ----
stock <- read_rds("data/acs_stock.rds")

# Total housing units for Fauquier County — GP benchmark ~30,000 (allow ±5k for vintage diff)
fauquier_units <- stock$b25001 |>
  filter(GEOID == fauquier, variable == "B25001_001") |>
  pull(estimate)
stopifnot(between(fauquier_units, 25000, 35000))
message("Fauquier total housing units: ", fauquier_units)

# SFD structure mix ~84.8% (GP benchmark: 1-unit detached share)
# B25024_002 = 1-unit detached; B25024_001 = total. Allow ±7pp for vintage/methodology diff.
sfd_vals <- stock$b25024 |>
  filter(GEOID == fauquier, variable %in% c("B25024_001", "B25024_002")) |>
  select(variable, estimate)
sfd_share <- sfd_vals$estimate[sfd_vals$variable == "B25024_002"] /
             sfd_vals$estimate[sfd_vals$variable == "B25024_001"]
if (!between(sfd_share, 0.75, 0.92)) {
  warning(paste0("SFD detached share: ", scales::percent(sfd_share, 0.1),
                 " — expected ~84.8% (GP benchmark; allow ±7pp for vintage/methodology diff)"))
} else {
  message("SFD detached share: ", scales::percent(sfd_share, 0.1))
}

# Trend: all 4 anchor years present for Fauquier County
trend_years_check <- stock$b25003_trend |>
  filter(GEOID == fauquier, variable == "B25003_001") |>
  distinct(year) |>
  nrow()
stopifnot(trend_years_check == 4)

# Both towns present
n_places <- stock$b25001 |> filter(geo_type == "place") |> distinct(GEOID) |> nrow()
stopifnot(n_places == 2)

# All 13 point-in-time tables present and non-empty
point_tables <- c("b25001","b25002","b25004","b25024","b25032","b25034","b25035",
                  "b25036","b25041","b25042","b25014","b25047","b25051")
for (tbl in point_tables) {
  stopifnot(nrow(stock[[tbl]]) > 0)
}

message("acs_stock.R validation passed.")
