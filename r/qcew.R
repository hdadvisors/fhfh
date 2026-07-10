# qcew.R ----
# What:   Employment + avg wages: county/benchmarks/VA 2015–2025 at four cuts —
#         all-industry total, by ownership sector, 2-digit NAICS sector, 3-digit subsector
# Source: BLS QCEW open-data CSVs (data.bls.gov/cew/data/api/) — Path A (script-fetch)
# Output: data/qcew.rds
# agglvl map (confirmed 2026-07-08 against 51061 annual file; expanded Session 6 2026-07-10):
#   county: 70 = total all industries (own 0); 71 = by ownership sector;
#           74 = 2-digit NAICS sector by ownership; 75 = 3-digit NAICS subsector by ownership
#   state:  50 / 51 / 54 / 55 = same cuts for VA
#   (Session 6 added 71/74 + 51/54 so gaps.R can build the wages-vs-costs signature chart:
#    Local Government comes from ownership own_code 3; Health Care/Retail from 2-digit sectors.)

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
# Keep four aggregation cuts per geography (see agglvl map in header):
#   50/70 total | 51/71 by ownership | 54/74 2-digit NAICS sector | 55/75 3-digit subsector
# (confirmed 2026-07-08: county CSV only contains 70-78; state CSV only contains 50-58)
qcew_clean <- raw |>
  clean_names() |>
  filter(
    area_fips %in% area_codes,
    agglvl_code %in% c("50", "51", "54", "55", "70", "71", "74", "75")
  ) |>
  mutate(
    across(c(annual_avg_estabs, annual_avg_emplvl, total_annual_wages,
             annual_avg_wkly_wage, avg_annual_pay), as.numeric),
    year = coalesce(as.integer(year), year_fetched)
  ) |>
  select(-any_of("year_fetched"))

## 4. Split into named list elements ----
# total     = all industries, all ownership (own_code 0)
# ownership = all industries, by ownership sector (own 1 fed / 2 state / 3 local / 5 private)
# sector    = 2-digit NAICS sector, by ownership   (Session 6: Fig 8 sector wages)
# subsector = 3-digit NAICS subsector, by ownership (was `sector` pre-Session 6)
qcew_total     <- qcew_clean |> filter(agglvl_code %in% c("50", "70"))
qcew_ownership <- qcew_clean |> filter(agglvl_code %in% c("51", "71"))
qcew_sector    <- qcew_clean |> filter(agglvl_code %in% c("54", "74"))
qcew_subsector <- qcew_clean |> filter(agglvl_code %in% c("55", "75"))

## 5. Write output ----
write_rds(
  list(total = qcew_total, ownership = qcew_ownership,
       sector = qcew_sector, subsector = qcew_subsector),
  "data/qcew.rds"
)
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

# Subsector coverage — expect 15+ distinct 3-digit NAICS subsectors (unchanged 3-digit cut)
n_subsectors <- qcew$subsector |>
  filter(area_fips == fauquier, year == latest_yr) |>
  distinct(industry_code) |> nrow()
if (n_subsectors < 15) warning("Fewer than 15 NAICS subsectors for Fauquier — check agglvl_code filter")

# 2-digit sector cut present (Session 6 add) — expect 10+ sectors
n_sectors <- qcew$sector |>
  filter(area_fips == fauquier, year == latest_yr) |>
  distinct(industry_code) |> nrow()
stopifnot(n_sectors >= 10)

# Ownership cut present with Local Government (own_code 3) — needed for Fig 8 signature chart
local_gov_wage <- qcew$ownership |>
  filter(area_fips == fauquier, year == latest_yr, own_code == "3") |>
  pull(avg_annual_pay) |> as.numeric()
stopifnot(length(local_gov_wage) == 1, between(local_gov_wage, 30000, 100000))

# All 5 areas present
stopifnot(all(area_codes %in% unique(qcew$total$area_fips)))

message("qcew.R validation passed. Latest year: ", latest_yr,
        " | Fauquier jobs: ", round(fauquier_jobs, 0),
        " | Avg pay: $", round(fauquier_wage, 0),
        " | 2-digit sectors: ", n_sectors,
        " | Local gov wage: $", round(local_gov_wage, 0))
