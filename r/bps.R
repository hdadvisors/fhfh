# bps.R ----
# What:   Building Permits Survey — Fauquier County 2000–2025 by structure type.
#         Place-level check for Town of Warrenton (Bealeton is a CDP — county-issued only).
# Source: Census Bureau BPS annual text files https://www2.census.gov/econ/bps/
#         Approved per PLAN.md §3: census.gov text files
# Output: data/bps.rds
#   $bps_county      tibble — GEOID / year / type / units (4 structure types × 26 years)
#   $bps_warrenton   tibble or NULL — same structure if Warrenton found in place files
#   $warrenton_in_bps  logical or NA — FALSE/TRUE if checked; NA if place file fetch failed

## 1. Setup ----
library(tidyverse)
library(glue)
library(janitor)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier        <- "51061"
bps_base_county <- "https://www2.census.gov/econ/bps/County"
bps_base_place  <- "https://www2.census.gov/econ/bps/Place"
bps_years       <- 2000:2025  # co2025a.txt confirmed live 2026-07-08

## 2. Header-parsing helper ----
# BPS files have 2 header rows: row 1 = group name (FIPS, 1-unit, 2-units…),
# row 2 = sub-name (State, County, Bldgs, Units, Value…).
# Transpose, fill group name down, concatenate → "FIPS: State", "1-unit: Bldgs", etc.
parse_bps_col_names <- function(url) {
  read_csv(url, col_names = FALSE, n_max = 2, show_col_types = FALSE) |>
    select(X1:X18) |>
    t() |>
    as_tibble() |>
    mutate(group = rep(1:6, each = 3)) |>
    group_by(group) |>
    fill(V1, .direction = "updown") |>
    mutate(col_name = paste0(V1, ": ", V2)) |>
    pull(col_name)
}

county_col_names <- parse_bps_col_names(glue("{bps_base_county}/co2024a.txt"))

## 3. Fetch county files 2000–2025 ----
cbps_raw <- map_dfr(bps_years, \(yr) {
  read_csv(
    glue("{bps_base_county}/co{yr}a.txt"),
    skip = 2, col_names = FALSE, show_col_types = FALSE
  ) |>
    select(X1:X18) |>
    set_names(county_col_names) |>
    mutate(`Survey: Date` = yr)
})

## 4. Filter to Fauquier and reshape ----
bps_county <- cbps_raw |>
  mutate(
    year  = `Survey: Date`,
    GEOID = paste0(
      str_pad(as.character(`FIPS: State`),  2, pad = "0"),
      str_pad(as.character(`FIPS: County`), 3, pad = "0")
    )
  ) |>
  filter(GEOID == fauquier) |>
  select(GEOID, year, `1-unit: Bldgs`:`5+ units: Value`) |>
  pivot_longer(`1-unit: Bldgs`:`5+ units: Value`,
               names_to = "type_col", values_to = "value") |>
  separate(type_col, into = c("type", "col"), sep = ": ") |>
  pivot_wider(names_from = col, values_from = value) |>
  clean_names() |>
  select(geoid, year, type, units)

## 5. Warrenton place-level check ----
# BPS place file column layout inspected from pl2024a.txt.
# Wrapped in tryCatch — 524 timeouts are possible on census.gov BPS place files.
warrenton_place_result <- tryCatch({
  place_col_names <- parse_bps_col_names(glue("{bps_base_place}/pl2024a.txt"))

  pbps_2024 <- read_csv(
    glue("{bps_base_place}/pl2024a.txt"),
    skip = 2, col_names = FALSE, show_col_types = FALSE
  ) |>
    set_names(place_col_names[seq_len(ncol(.))])

  # Show column names for §11 logging
  message("Place file ncol: ", ncol(pbps_2024))
  message("Place file col names (first 6): ",
          paste(names(pbps_2024)[1:min(6, ncol(pbps_2024))], collapse = ", "))

  # Filter Virginia rows; search all columns for "Warrenton"
  warrenton_rows <- pbps_2024 |>
    filter(str_pad(as.character(.[[1]]), 2, pad = "0") == "51") |>
    filter(if_any(everything(),
                  \(x) str_detect(as.character(x), regex("warrenton", ignore_case = TRUE))))

  warrenton_found <- nrow(warrenton_rows) > 0
  message("Warrenton in BPS 2024 place file: ", warrenton_found)

  if (warrenton_found) {
    message("Warrenton row col 1–6: ",
            paste(as.character(warrenton_rows[1, 1:min(6, ncol(warrenton_rows))]), collapse = " | "))
  }

  list(found = warrenton_found, rows = warrenton_rows)
}, error = function(e) {
  message("Place file fetch failed (", conditionMessage(e), ") — skipping Warrenton check")
  list(found = NA, rows = NULL)
})

warrenton_found <- warrenton_place_result$found
warrenton_rows  <- warrenton_place_result$rows

## 6. Fetch Warrenton place series if found ----
# place_id_col: inspect warrenton_rows column names to confirm; logged in §11.
bps_warrenton <- if (isTRUE(warrenton_found)) {
  place_col_names <- parse_bps_col_names(glue("{bps_base_place}/pl2024a.txt"))

  place_id_col <- 2  # verify by inspecting warrenton_rows column names logged above
  warrenton_id <- warrenton_rows[[place_id_col]][1]

  tryCatch(
    map_dfr(bps_years, \(yr) {
      read_csv(
        glue("{bps_base_place}/pl{yr}a.txt"),
        skip = 2, col_names = FALSE, show_col_types = FALSE
      ) |>
        set_names(place_col_names[seq_len(ncol(.))]) |>
        filter(
          str_pad(as.character(.[[1]]), 2, pad = "0") == "51",
          .[[place_id_col]] == warrenton_id
        ) |>
        mutate(`Survey: Date` = yr)
    }) |>
      select(`Survey: Date`, `1-unit: Bldgs`:`5+ units: Value`) |>
      pivot_longer(`1-unit: Bldgs`:`5+ units: Value`,
                   names_to = "type_col", values_to = "value") |>
      separate(type_col, into = c("type", "col"), sep = ": ") |>
      pivot_wider(names_from = col, values_from = value) |>
      clean_names() |>
      rename(year = survey_date) |>
      select(year, type, units),
    error = function(e) {
      message("Warrenton series fetch failed: ", conditionMessage(e))
      NULL
    }
  )
} else {
  NULL
}

## 7. Write output ----
write_rds(
  list(
    bps_county       = bps_county,
    bps_warrenton    = bps_warrenton,
    warrenton_in_bps = warrenton_found   # TRUE/FALSE/NA (NA = network error)
  ),
  "data/bps.rds"
)
message("Wrote data/bps.rds — warrenton_in_bps: ", warrenton_found)

## 8. Validate ----
bps <- read_rds("data/bps.rds")

n_years <- bps$bps_county |> distinct(year) |> nrow()
n_types <- bps$bps_county |> distinct(type)  |> nrow()
stopifnot(n_years == 26, n_types == 4)

year_range <- bps$bps_county |> summarise(min = min(year), max = max(year))
stopifnot(year_range$min == 2000, year_range$max == 2025)

avg_2020_25 <- bps$bps_county |>
  filter(year >= 2020) |>
  summarise(total = sum(units, na.rm = TRUE), .by = year) |>
  summarise(avg = mean(total)) |>
  pull(avg)

if (!between(avg_2020_25, 100, 500)) {
  warning(glue("BPS avg permits 2020-25: {round(avg_2020_25)} — expected ~241/yr (GP benchmark)"))
} else {
  message("BPS avg permits 2020-25: ", round(avg_2020_25), " (within expected range)")
}

message("bps.R validation passed.")
