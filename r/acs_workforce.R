# acs_workforce.R ----
# What:   B08303 travel time to work + B08007 place of work, for Ch 2 commute charts
# Tables: B08303, B08007
# Source: tidycensus (ACS 5-year 2024)
# Output: data/acs_workforce.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")

# Standard ACS pull helper (same pattern as Session 2)
pull_acs_bind <- function(table) {
  bind_rows(
    get_acs(geography = "county", state = "VA", table = table,
            year = 2024, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID %in% c(fauquier, unname(benchmarks))) |>
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

## 2. B08303 — Travel time to work ----
# Universe: workers 16+ who did not work from home
b08303 <- pull_acs_bind("B08303")

vars_b08303 <- load_variables(2024, "acs5", cache = TRUE) |>
  filter(str_starts(name, "B08303_")) |>
  separate_wider_delim(label, "!!", names = c("est", "total", "time_band"),
                       too_few = "align_start", too_many = "drop")

## 3. B08007 — Place of work ----
# Universe: workers 16 years and over
# _001: Total | _002: worked in state of residence | _003: worked in county of residence
# _004: worked in different county same state | _005: worked outside state
# Key metric: B08007_003 / B08007_001 = share employed in home county
b08007 <- pull_acs_bind("B08007")

vars_b08007 <- load_variables(2024, "acs5", cache = TRUE) |>
  filter(str_starts(name, "B08007_")) |>
  separate_wider_delim(label, "!!", names = c("est", "total", "col3", "col4"),
                       too_few = "align_start", too_many = "drop")

## 4. Write output ----
write_rds(
  list(
    b08303      = b08303,
    b08007      = b08007,
    vars_b08303 = vars_b08303,
    vars_b08007 = vars_b08007
  ),
  "data/acs_workforce.rds"
)
message("Wrote data/acs_workforce.rds")

## 5. Validate ----
wf <- read_rds("data/acs_workforce.rds")

# B08303 total for Fauquier (workers 16+ not WFH)
b08303_total <- wf$b08303 |>
  filter(GEOID == fauquier, variable == "B08303_001") |>
  pull(estimate)
stopifnot(between(b08303_total, 20000, 45000))

# B08007 total for Fauquier (all workers 16+)
b08007_total <- wf$b08007 |>
  filter(GEOID == fauquier, variable == "B08007_001") |>
  pull(estimate)
stopifnot(between(b08007_total, 30000, 55000))

# All 4 county geographies present
n_counties_b08303 <- wf$b08303 |> filter(geo_type == "county") |> distinct(GEOID) |> nrow()
n_counties_b08007 <- wf$b08007 |> filter(geo_type == "county") |> distinct(GEOID) |> nrow()
stopifnot(n_counties_b08303 == 4, n_counties_b08007 == 4)

message("acs_workforce.R validation passed.")
