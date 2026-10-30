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
# Post-2020 PEP API uses `vintage` to select the release year; `year` alone silently
# falls back to the previous vintage. vintage = 2025 is the latest release (Oct 2026).
pep_vintage <- 2025

message("Pulling county population time series (vintage ", pep_vintage, ")...")
pep_pop <- get_estimates(geography = "county", state = "VA", vintage = pep_vintage,
                         product = "population", time_series = TRUE) |>
  filter(GEOID == fauquier)
message("County pop rows: ", nrow(pep_pop))

## 3. Components of change (county, 2020–2025) ----
message("Pulling components of change (vintage ", pep_vintage, ")...")
pep_comp <- tryCatch(
  get_estimates(geography = "county", state = "VA", vintage = pep_vintage,
                product = "components", time_series = TRUE) |>
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

## 4. Place-level estimates (2020–2025) ----
# Bealeton is a CDP — CDPs are not covered by the Population Estimates Program.
# Only Warrenton (incorporated town, GEOID 5183136) will appear in PEP.
# Chapters use ACS 5-year or decennial for Bealeton population.
message("Pulling place estimates (Warrenton; Bealeton CDP excluded by PEP design)...")
pep_places <- tryCatch(
  get_estimates(geography = "place", state = "VA", vintage = pep_vintage,
                product = "population", time_series = TRUE) |>
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

# Every product must reach the current vintage year
stopifnot(
  max(pep$pop$year) == pep_vintage,
  !is.null(pep$components), max(pep$components$year) == pep_vintage,
  !is.null(pep$places), max(pep$places$year) == pep_vintage
)

pop_latest <- pep$pop |>
  filter(variable == "POPESTIMATE", year == max(year)) |>
  pull(value)

stopifnot(length(pop_latest) == 1, between(pop_latest, 73000, 83000))
# Fauquier trending ~76–78k; bracket generous for vintage uncertainty

message("pep.R validation passed.")
message("  Most-recent county pop: ", format(pop_latest[1], big.mark = ","))
