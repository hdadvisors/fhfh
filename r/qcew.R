# qcew.R ----
# What:   Employment + avg wages, total + 2-digit NAICS, county/benchmarks/VA 2015–2025
# Source: BLS QCEW open-data CSVs (data.bls.gov/cew/data/api/) — Path A (script-fetch)
# Output: data/qcew.rds
# agglvl discovery: 70 = county all-ownerships total; 75 = county 2-digit NAICS all-ownerships
#                   (confirmed 2026-07-08 against 51061 2022 annual file)

## 1. Setup ----
library(tidyverse)
library(janitor)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier   <- "51061"
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")
# BLS area codes: 5-digit FIPS for counties; 2-digit state FIPS + "000" for state
area_codes <- c("51061", "51047", "51153", "51107", "51000")
years      <- 2015:2025

## 2. Fetch from BLS API (Path A) ----
fetch_qcew_area_year <- function(year, area_code) {
  url <- paste0("https://data.bls.gov/cew/data/api/", year, "/a/area/",
                toupper(area_code), ".csv")
  message("Fetching: ", url)
  tryCatch(
    read_csv(url, na = " ", show_col_types = FALSE,
             col_types = cols(.default = "c")) |>
      mutate(year_fetched = as.integer(.env$year)),
    error = function(e) {
      message("  Failed: ", conditionMessage(e))
      NULL
    }
  )
}

raw <- map(years, \(yr)
  map(area_codes, \(area) fetch_qcew_area_year(yr, area)) |> compact()
) |> list_flatten() |> list_rbind()

## 3. Filter and type-convert ----
# County totals: agglvl_code 70; county 2-digit NAICS: 75
# State totals:  agglvl_code 50; state 2-digit NAICS:  55
# (confirmed 2026-07-08: county CSV only contains 70-78; state CSV only contains 50-58)
qcew_clean <- raw |>
  clean_names() |>
  filter(
    area_fips %in% area_codes,
    agglvl_code %in% c("50", "55", "70", "75")
  ) |>
  mutate(
    across(c(annual_avg_estabs, annual_avg_emplvl, total_annual_wages,
             annual_avg_wkly_wage, avg_annual_pay), as.numeric),
    year = coalesce(as.integer(year), year_fetched)
  ) |>
  select(-any_of("year_fetched"))

## 4. Split into named list elements ----
qcew_total  <- qcew_clean |> filter(agglvl_code %in% c("50", "70"))
qcew_sector <- qcew_clean |> filter(agglvl_code %in% c("55", "75"))

## 5. Write output ----
write_rds(list(total = qcew_total, sector = qcew_sector), "data/qcew.rds")
message("Wrote data/qcew.rds")

## 6. Validate ----
qcew <- read_rds("data/qcew.rds")

latest_yr <- max(qcew$total$year, na.rm = TRUE)

# Fauquier total jobs — GP benchmark: ~24,138 (2025); own_code "0" = all ownerships combined
fauquier_jobs <- qcew$total |>
  filter(area_fips == fauquier, year == latest_yr, own_code == "0") |>
  pull(annual_avg_emplvl) |> as.numeric()
stopifnot(between(fauquier_jobs, 17000, 33000))

# Fauquier avg annual pay — GP benchmark: ~$64,272
fauquier_wage <- qcew$total |>
  filter(area_fips == fauquier, year == latest_yr, own_code == "0") |>
  pull(avg_annual_pay) |> as.numeric()
stopifnot(between(fauquier_wage, 45000, 90000))

# Sector coverage — expect 15+ distinct NAICS supersectors
n_sectors <- qcew$sector |>
  filter(area_fips == fauquier, year == latest_yr) |>
  distinct(industry_code) |> nrow()
if (n_sectors < 15) warning("Fewer than 15 NAICS sectors for Fauquier — check agglvl_code filter")

# All 5 areas present
stopifnot(all(area_codes %in% unique(qcew$total$area_fips)))

message("qcew.R validation passed. Latest year: ", latest_yr,
        " | Fauquier jobs: ", round(fauquier_jobs, 0),
        " | Avg pay: $", round(fauquier_wage, 0))
