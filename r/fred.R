# fred.R ----
# What:   Pull CPI less shelter and PMMS 30-yr mortgage rate from FRED
# Source: FRED API — CUUR0000SA0L2 (CPI less shelter), MORTGAGE30US (Freddie Mac PMMS)
# Output: data/fred.rds

## 1. Setup ----
library(tidyverse)
library(fredr)
library(lubridate)

if (Sys.getenv("FRED_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
fredr_set_key(Sys.getenv("FRED_API_KEY"))

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. CPI less shelter — annual ----
message("Pulling CPI less shelter (CUUR0000SA0L2)...")

cpi <- fredr(
  series_id          = "CUUR0000SA0L2",
  observation_start  = as.Date("2010-01-01"),
  frequency          = "a",
  aggregation_method = "avg"
) |>
  mutate(year = year(date)) |>
  select(year, cpi_less_shelter = value)

message("  ", nrow(cpi), " annual observations.")

## 3. PMMS 30-yr fixed rate ----
message("Pulling PMMS (MORTGAGE30US)...")

pmms_monthly <- fredr(
  series_id          = "MORTGAGE30US",
  observation_start  = as.Date("2010-01-01"),
  frequency          = "m",
  aggregation_method = "avg"
) |>
  mutate(year = year(date), month = month(date)) |>
  select(date, year, month, mortgage_rate_30yr = value)

pmms_annual <- pmms_monthly |>
  summarize(mortgage_rate_30yr = mean(mortgage_rate_30yr, na.rm = TRUE), .by = year)

message("  ", nrow(pmms_monthly), " monthly observations.")

## 4. Write output ----
write_rds(
  list(cpi = cpi, pmms_monthly = pmms_monthly, pmms_annual = pmms_annual),
  "data/fred.rds"
)
message("Wrote data/fred.rds")

## 5. Validate ----
fred <- read_rds("data/fred.rds")
stopifnot(
  nrow(fred$cpi) >= 10,
  nrow(fred$pmms_monthly) >= 100,
  between(tail(fred$pmms_annual$mortgage_rate_30yr, 1), 4, 9)
)
message("fred.R validation passed.")
message("  Latest annual PMMS: ", round(tail(fred$pmms_annual$mortgage_rate_30yr, 1), 2), "%")
message("  Latest CPI less shelter: ", round(tail(fred$cpi$cpi_less_shelter, 1), 1))
