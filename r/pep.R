# pep.R ----
# What:   Census Population Estimates Program — county totals + components of change,
#         and place-level estimates (Warrenton only; Bealeton CDP not PEP-covered)
# Source: tidycensus get_estimates(), vintage 2025
# Output: data/pep.rds

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

## 2. County population time series 2020–2025 ----
message("Pulling county population time series (vintage 2025)...")
pep_pop <- tryCatch(
  get_estimates(geography = "county", state = "VA", year = 2025,
                product = "population", time_series = TRUE) |>
    filter(GEOID == fauquier),
  error = function(e) {
    message("time_series=TRUE failed (", conditionMessage(e), ").")
    message("Falling back to year-by-year pulls...")
    map_dfr(2020:2025, \(yr)
      tryCatch(
        get_estimates(geography = "county", state = "VA", year = yr,
                      product = "population") |>
          filter(GEOID == fauquier) |>
          mutate(year = yr),
        error = function(e2) {
          message("  Year ", yr, " failed: ", conditionMessage(e2))
          NULL
        }
      )
    )
  }
)
message("County pop rows: ", nrow(pep_pop))
if (nrow(pep_pop) > 0) message("  Columns: ", paste(names(pep_pop), collapse = ", "))

## 3. Components of change (county, vintage 2024) ----
# Post-2020 PEP API uses `vintage` to select the release year, not `year`.
# vintage = 2024 is the most recent release as of July 2026.
message("Pulling components of change (vintage 2024)...")
pep_comp <- tryCatch(
  get_estimates(geography = "county", state = "VA",
                vintage = 2024, product = "components") |>
    filter(GEOID == fauquier),
  error = function(e) {
    message("Components of change unavailable: ", conditionMessage(e))
    NULL
  }
)
if (!is.null(pep_comp)) {
  message("Components rows: ", nrow(pep_comp))
} else {
  message("Components: NULL (will be logged in §11)")
}

## 4. Place-level estimates (vintage 2024) ----
# Bealeton is a CDP — CDPs are not covered by the Population Estimates Program.
# Only Warrenton (incorporated town, GEOID 5183136) will appear in PEP.
# Chapters use ACS 5-year or decennial for Bealeton population.
message("Pulling place estimates (Warrenton; Bealeton CDP excluded by PEP design)...")
pep_places <- tryCatch(
  get_estimates(geography = "place", state = "VA",
                vintage = 2024, product = "population") |>
    filter(GEOID %in% unname(towns)),
  error = function(e) {
    message("PEP place-level unavailable: ", conditionMessage(e))
    message("Note: Bealeton CDP is excluded from PEP by design (CDPs not covered).")
    NULL
  }
)
if (!is.null(pep_places)) {
  message("Place rows: ", nrow(pep_places))
} else {
  message("Place estimates: NULL")
}

## 5. Write output ----
write_rds(
  list(pop = pep_pop, components = pep_comp, places = pep_places),
  "data/pep.rds"
)
message("Wrote data/pep.rds")

## 6. Validate ----
pep <- read_rds("data/pep.rds")

stopifnot(!is.null(pep$pop), nrow(pep$pop) > 0)

# Extract most-recent population estimate; handle different column structures
pop_df <- pep$pop
if ("variable" %in% names(pop_df)) {
  pop_pop <- pop_df |> filter(str_detect(variable, "^POP"))
  if (nrow(pop_pop) > 0) pop_df <- pop_pop
}

pop_latest <- if ("year" %in% names(pop_df)) {
  pop_df |> filter(year == max(year)) |> pull(value)
} else if ("DATE_CODE" %in% names(pop_df)) {
  pop_df |> filter(DATE_CODE == max(DATE_CODE)) |> pull(value)
} else {
  pop_df |> pull(value) |> tail(1)
}

stopifnot(length(pop_latest) > 0, between(pop_latest[1], 73000, 83000))
# Fauquier trending ~76–78k; bracket generous for vintage uncertainty

message("pep.R validation passed.")
message("  Most-recent county pop: ", format(pop_latest[1], big.mark = ","))
