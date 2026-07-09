# costar.R ----
# What:   Clean CoStar quarterly (property-level) and property-level static data;
#         aggregate to market-level quarterly series; CPI-adjust asking rents
# Source: data/raw/costar/costar_market_quarterly.xlsx, data/raw/costar/costar_properties.xlsx
# Source: FRED API — CUUR0000SEHA (CPI Rent of Primary Residence) for inflation adjustment
# Output: data/costar.rds

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
library(fredr)
library(lubridate)

if (Sys.getenv("FRED_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
fredr_set_key(Sys.getenv("FRED_API_KEY"))

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Quarterly property-level data ----
message("Reading costar_market_quarterly.xlsx...")

# Row 1 is an embedded sub-header (Canva artifact); all columns read as character.
# Some columns have Excel header names (building, inventory, asking_rent, etc.);
# unnamed columns get positional names x1, x2, ... after clean_names().
qtr_raw <- read_excel(
  "data/raw/costar/costar_market_quarterly.xlsx",
  col_types = "text"
)

message("  Raw: ", nrow(qtr_raw), " rows × ", ncol(qtr_raw), " columns")

qtr_prop <- qtr_raw |>
  slice(-1) |>          # drop embedded sub-header (row 1)
  clean_names() |>
  filter(!is.na(x1)) |>
  filter(!str_detect(x2, regex("Subtotal|Grand Total", ignore_case = TRUE))) |>
  rename(
    period         = x1,
    building_class = x2,
    address        = x3,
    units          = x9    # actual unit count per PLAN.md notes
  ) |>
  # Parse year/qtr BEFORE applying parse_number to remaining character columns
  mutate(
    year = as.integer(str_sub(period, 1, 4)),
    qtr  = as.integer(str_sub(period, -1))
  ) |>
  mutate(across(
    -c(period, building_class, address, building, year, qtr),
    \(x) suppressWarnings(parse_number(x))   # city/text cols produce expected NAs
  )) |>
  filter(!str_detect(period, "QTD"), year >= 2015)

message("  Property-level quarterly rows: ", nrow(qtr_prop),
        " (", min(qtr_prop$year), " Q", min(qtr_prop$qtr[qtr_prop$year == min(qtr_prop$year)]),
        " – ", max(qtr_prop$year), " Q", max(qtr_prop$qtr[qtr_prop$year == max(qtr_prop$year)]), ")")
message("  Asking rent column confirmed: ", "asking_rent" %in% names(qtr_prop))

## 3. Aggregate to market-level quarterly series ----
# Unit-weighted average asking rent and vacancy across all properties per quarter
qtr_market <- qtr_prop |>
  filter(!is.na(units), units > 0, !is.na(asking_rent)) |>
  summarize(
    market_units    = sum(units, na.rm = TRUE),
    asking_rent_avg = weighted.mean(asking_rent, units, na.rm = TRUE),
    vacancy_rate    = if ("vacancy" %in% names(qtr_prop))
                        weighted.mean(vacancy, units, na.rm = TRUE) else NA_real_,
    n_properties    = n(),
    .by = c(year, qtr)
  ) |>
  arrange(year, qtr)

message("  Market-level quarters: ", nrow(qtr_market))

## 4. Property-level static data ----
message("Reading costar_properties.xlsx...")

props <- read_excel("data/raw/costar/costar_properties.xlsx") |>
  clean_names()
# Properties file columns are already typed by read_excel; no parse_number needed

message("  Properties: ", nrow(props))

## 5. CPI-adjust asking rents ----
message("Pulling CPI Rent of Primary Residence (CUUR0000SEHA)...")

cpi_q <- fredr(
  series_id          = "CUUR0000SEHA",
  observation_start  = as.Date("2015-01-01"),
  frequency          = "q",
  aggregation_method = "avg"
) |>
  mutate(year = year(date), qtr = quarter(date)) |>
  select(year, qtr, cpi = value)

cpi_latest <- fredr(
  series_id         = "CUUR0000SEHA",
  observation_start = as.Date("2025-01-01")
) |>
  slice_max(date, n = 1) |>
  pull(value)

message("  CPI latest: ", round(cpi_latest, 3))

qtr_market_adj <- qtr_market |>
  left_join(cpi_q, by = c("year", "qtr")) |>
  mutate(
    asking_rent_adj = if_else(
      !is.na(asking_rent_avg) & !is.na(cpi),
      (cpi_latest / cpi) * asking_rent_avg,
      NA_real_
    )
  )

## 6. Write output ----
write_rds(
  list(
    quarterly       = qtr_market_adj,
    quarterly_prop  = qtr_prop,
    properties      = props,
    cpi_latest      = cpi_latest
  ),
  "data/costar.rds"
)
message("Wrote data/costar.rds")

## 7. Validate ----
out <- read_rds("data/costar.rds")
stopifnot(
  nrow(out$quarterly) >= 20,
  nrow(out$properties) >= 1,
  !is.na(out$cpi_latest)
)
message("costar.R validation passed.")
message("  Market quarterly periods: ", nrow(out$quarterly))
message("  Properties: ", nrow(out$properties))
latest <- out$quarterly |>
  filter(!is.na(asking_rent_adj)) |>
  slice_max(year * 10 + qtr, n = 1)
message("  Latest adj asking rent (", latest$year, " Q", latest$qtr, "): $",
        round(latest$asking_rent_adj, 0), "/mo (GP benchmark SF rent ~$2,450)")
