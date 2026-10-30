# bps.R ----
# What:   Building Permits Survey — Fauquier County 2000–2025 by structure type, plus
#         2026 year-to-date (Jan–Sep) vs the same months of 2025.
#         Place-level series for Town of Warrenton (Bealeton is a CDP — county-issued only).
# Source: Census Bureau BPS text files https://www2.census.gov/econ/bps/
#         Approved per PLAN.md §3: census.gov text files
#         County/co{yyyy}a.txt (annual), County/co{yymm}y.txt (YTD),
#         Place/South Region/so{yyyy}a.txt, so{yymm}y.txt
# Output: data/bps.rds
#   $bps_county        tibble — geoid / year / type / units (4 structure types × 26 years)
#   $bps_county_ytd    tibble — geoid / year / type / units, Jan–`ytd_month` of 2025 and 2026
#   $bps_warrenton     tibble — year / type / units, 2000–2025 (annual)
#   $bps_warrenton_ytd tibble — year / type / units, Jan–`ytd_month` of 2025 and 2026
#   $warrenton_in_bps  logical — TRUE if Warrenton found in the place files
#   $ytd_through       Date — last day of the YTD month

## 1. Setup ----
library(tidyverse)
library(glue)
library(janitor)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier        <- "51061"
bps_base_county <- "https://www2.census.gov/econ/bps/County"
bps_base_place  <- "https://www2.census.gov/econ/bps/Place/South%20Region"
bps_years       <- 2000:2025
ytd_year        <- 2026   # latest YTD file: co2609y.txt (through Sep 2026)
ytd_month       <- 9
ytd_through     <- ceiling_date(make_date(ytd_year, ytd_month, 1), "month") - 1

bps_types <- c("1-unit", "2-units", "3-4 units", "5+ units")

## 2. Header-parsing helper (county files) ----
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

# One county file → Fauquier rows, long by structure type
read_county_file <- function(file, yr) {
  read_csv(glue("{bps_base_county}/{file}"), skip = 2, col_names = FALSE,
           show_col_types = FALSE) |>
    select(X1:X18) |>
    set_names(county_col_names) |>
    mutate(
      GEOID = paste0(
        str_pad(as.character(`FIPS: State`),  2, pad = "0"),
        str_pad(as.character(`FIPS: County`), 3, pad = "0")
      )
    ) |>
    filter(GEOID == fauquier) |>
    select(GEOID, `1-unit: Bldgs`:`5+ units: Value`) |>
    pivot_longer(`1-unit: Bldgs`:`5+ units: Value`,
                 names_to = "type_col", values_to = "value") |>
    separate(type_col, into = c("type", "col"), sep = ": ") |>
    pivot_wider(names_from = col, values_from = value) |>
    clean_names() |>
    mutate(year = yr) |>
    select(geoid, year, type, units)
}

## 3. County annual 2000–2025 ----
bps_county <- map_dfr(bps_years, \(yr) read_county_file(glue("co{yr}a.txt"), yr))

## 4. County year-to-date (this year vs same months last year) ----
ytd_file <- \(yr) glue("co{str_sub(yr, 3, 4)}{str_pad(ytd_month, 2, pad = '0')}y.txt")
bps_county_ytd <- map_dfr(c(ytd_year - 1, ytd_year), \(yr) read_county_file(ytd_file(yr), yr))

## 5. Warrenton place series ----
# Place files have 17 ID columns before the permit blocks; the layout is fixed:
#   col 2 = state FIPS, col 17 = place name, then Bldgs/Units/Value for 1-unit,
#   2-units, 3-4 units, 5+ units starting at col 18. Units are cols 19, 22, 25, 28.
# Warrenton (state 51) is matched by name — place codes changed across years.
read_place_file <- function(file, yr) {
  raw <- read_csv(glue("{bps_base_place}/{file}"), skip = 2, col_names = FALSE,
                  col_types = cols(.default = "c"))
  # 2000–2006 files carry 3 fewer ID columns: name in col 14, units at 16/19/22/25
  name_col <- if (yr <= 2006) 14 else 17
  unit_cols <- paste0("X", name_col + 2 + 3 * 0:3)
  row <- raw |>
    filter(str_trim(X2) == "51",
           str_detect(str_trim(.data[[paste0("X", name_col)]]),
                      regex("^warrenton", ignore_case = TRUE))) |>
    slice(1)
  if (nrow(row) == 0) stop("Warrenton row not found")
  tibble(year = yr, type = bps_types, units = as.numeric(unlist(row[unit_cols])))
}

safe_place <- \(file, yr) tryCatch(read_place_file(file, yr), error = function(e) {
  message("  Place file ", file, " failed: ", conditionMessage(e))
  NULL
})

bps_warrenton <- map_dfr(bps_years, \(yr) safe_place(glue("so{yr}a.txt"), yr))
bps_warrenton_ytd <- map_dfr(c(ytd_year - 1, ytd_year),
                             \(yr) safe_place(str_replace(ytd_file(yr), "^co", "so"), yr))

warrenton_found <- nrow(bps_warrenton) > 0
message("Warrenton place series years: ",
        paste(sort(unique(bps_warrenton$year)), collapse = ", "))

## 6. Write output ----
write_rds(
  list(
    bps_county        = bps_county,
    bps_county_ytd    = bps_county_ytd,
    bps_warrenton     = bps_warrenton,
    bps_warrenton_ytd = bps_warrenton_ytd,
    warrenton_in_bps  = warrenton_found,
    ytd_through       = ytd_through
  ),
  "data/bps.rds"
)
message("Wrote data/bps.rds — warrenton_in_bps: ", warrenton_found)

## 7. Validate ----
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
  warning(glue("BPS avg permits 2020-25: {round(avg_2020_25)} — expected ~266/yr"))
} else {
  message("BPS avg permits 2020-25: ", round(avg_2020_25), " (within expected range)")
}

stopifnot(
  setequal(unique(bps$bps_county_ytd$year), c(ytd_year - 1, ytd_year)),
  nrow(bps$bps_county_ytd) == 8,
  isTRUE(bps$warrenton_in_bps),
  setequal(unique(bps$bps_warrenton$year), bps_years),
  setequal(unique(bps$bps_warrenton_ytd$year), c(ytd_year - 1, ytd_year))
)

message("BPS ", ytd_year, " YTD (through ", format(ytd_through, "%b %Y"), "): ",
        sum(bps$bps_county_ytd$units[bps$bps_county_ytd$year == ytd_year]), " county units vs ",
        sum(bps$bps_county_ytd$units[bps$bps_county_ytd$year == ytd_year - 1]), " same months ",
        ytd_year - 1)
message("bps.R validation passed.")
