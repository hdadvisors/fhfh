# Session 5 (Market Data) — FHFH Housing Needs Assessment

Detailed execution plan for PLAN.md §9 **Session 5 — Market data**. PLAN.md (repo root) remains
the source of truth; this document is the step-by-step build reference for the session.

## Context

Session 4 (Housing Stock & Production Data) is complete and committed. Status as of planning:

| Check | Status |
|---|---|
| `data/bps.rds` | ✅ Session 4 output present |
| `data/acs_stock.rds` | ✅ Session 4 output present |
| `data/gp_appendix.rds` | ✅ Built in prereq session 2026-07-09 |
| `data/raw/mls/` (9 files) | ✅ Confirmed present and inspected 2026-07-09 |
| `data/raw/costar/costar_market_quarterly.xlsx` | ✅ Confirmed present |
| `data/raw/costar/costar_properties.xlsx` | ✅ Confirmed present |
| `data/raw/hud/hud_fmr_fy2026.xlsx` | ✅ Confirmed present |
| `data/raw/hud/hud_safmr_fy2026.xlsx` | ✅ Confirmed present |
| `data/raw/nhpd/nhpd_virginia.xlsx` | ✅ Confirmed present |
| FRED_API_KEY | ✅ in `C:/Users/JTK/Documents/.Renviron` |
| CENSUS_API_KEY | ✅ in `C:/Users/JTK/Documents/.Renviron` |

### Data architecture (locked 2026-07-09)

- **Monthly grain** for price trend figures: VAR monthly medians (2016–2021) splice to MLS monthly
  medians computed from transactions (2022+). Avoids averaging-of-medians problem.
- **Annual grain** for sales-count bars, price/payment/income index, price-band chart: GP appendix
  `$sales` for 2016–2021 counts + medians; true annual medians from MLS transactions for 2022+.
- **Price band chart** scoped to 2022+ (transaction-level MLS only); caption references GP study
  figures for historical trend context.
- **CoStar CPI adjustment**: `CUUR0000SEHA` (Rent of Primary Residence) — same as faar pattern;
  inflates historical asking rents to most-recent-period dollars.
- **Fauquier HUD area**: `METRO47900M47900` (DC-Arlington-Alexandria HMFA). SAFMR zip 20186
  appears twice in the SAFMR file — filter to this metro code.

### Out of scope (this session)

No chapter edits. No CHAS (`r/chas.R` is Session 6). No PUMS. No PIT counts or VDOE data
(Session 7 / vulnerable populations). No figures or tables — scripts write `.rds` only.

---

## Shell conventions

Every R invocation from the project root `R:\hda\fhfh` via **Bash**:

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/<name>.R
```

Per PLAN.md §3 and CLAUDE.md Windows R rule: **never run R inline**. Ad-hoc inspections (column
headers, row counts, etc.) go to the session scratchpad, not the repo.

---

## Script anatomy (all six scripts)

```r
# <name>.R ----
# What:   <one-line description>
# Source: <data source(s)>
# Output: data/<name>.rds

## 1. Setup ----
library(tidyverse)
library(readxl)   # as needed
library(fredr)    # as needed
library(lubridate)
library(janitor)

# API key guard (fred.R and acs_costs.R)
if (Sys.getenv("FRED_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Geography constants (mirrors _common.R — defined here so scripts run standalone)
fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
virginia   <- "51"
town_zips  <- list(warrenton = c("20186", "20187"), bealeton = "22712")

## N. <section> ----
# ...

## N+1. Write output ----
write_rds(list(...), "data/<name>.rds")
message("Wrote data/<name>.rds")

## N+2. Validate ----
out <- read_rds("data/<name>.rds")
stopifnot(...)
message("<name>.R validation passed.")
```

---

## Script 1 — `r/fred.R` → `data/fred.rds`

No raw files needed. Fetches CPI (less shelter) and 30-year mortgage rate from FRED. Both series
are consumed by downstream chapters for the payment/income index and inflation-context charts.

```r
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
  series_id        = "CUUR0000SA0L2",
  observation_start = as.Date("2010-01-01"),
  frequency         = "a",
  aggregation_method = "avg"
) |>
  mutate(year = year(date)) |>
  select(year, cpi_less_shelter = value)

message("  ", nrow(cpi), " annual observations.")

## 3. PMMS 30-yr fixed rate ----
# Annual average for trend/index charts; monthly for rate-environment figures
message("Pulling PMMS (MORTGAGE30US)...")

pmms_monthly <- fredr(
  series_id        = "MORTGAGE30US",
  observation_start = as.Date("2010-01-01"),
  frequency         = "m",
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
  # 2024 annual avg should be in plausible range ~6-7%
  between(tail(fred$pmms_annual$mortgage_rate_30yr, 1), 4, 9)
)
message("fred.R validation passed.")
message("  Latest annual PMMS: ", round(tail(fred$pmms_annual$mortgage_rate_30yr, 1), 2), "%")
message("  Latest CPI less shelter: ", round(tail(fred$cpi$cpi_less_shelter, 1), 1))
```

---

## Script 2 — `r/acs_costs.R` → `data/acs_costs.rds`

No raw files needed. Pulls ACS tables for rents, home values, and cost burden. Session 4's
`acs_stock.R` already captured structural tables (B25001–B25051); this script targets cost and
burden tables not yet collected. `pull_acs_bind()` helper mirrors the Session 4 pattern.

```r
# acs_costs.R ----
# What:   ACS cost & burden tables — median rents/values, distributions, cost burden
# Tables: B25031, B25063, B25064, B25070, B25071, B25075, B25077, B25091
#         Trend: B25064 (median rent), B25077 (median value) — 2013/2017/2021/2024
# Source: tidycensus ACS 5-year 2024
# Output: data/acs_costs.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)

if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier  <- "51061"
towns     <- c(warrenton = "5183136", bealeton = "5105336")
virginia  <- "51"
acs_year  <- 2024
trend_years <- c(2013, 2017, 2021, 2024)

## 2. Helper — pull table for county + towns + state, bind ----
pull_acs_bind <- function(table, year = acs_year) {
  county <- get_acs(
    geography = "county", state = "VA", table = table,
    year = year, survey = "acs5", cache_table = TRUE
  ) |>
    filter(GEOID == fauquier) |>
    mutate(geo_type = "county")

  place <- get_acs(
    geography = "place", state = "VA", table = table,
    year = year, survey = "acs5", cache_table = TRUE
  ) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place")

  state <- get_acs(
    geography = "state", table = table,
    year = year, survey = "acs5", cache_table = TRUE
  ) |>
    filter(GEOID == virginia) |>
    mutate(geo_type = "state")

  bind_rows(county, place, state) |>
    mutate(
      year = year,
      cv   = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)
    )
}

## 3. Point-in-time tables ----
tables_pit <- c(
  "B25031",   # median gross rent by bedrooms
  "B25063",   # gross rent distribution
  "B25064",   # median gross rent (single-value subject table)
  "B25070",   # renter cost burden (gross rent as % of HH income)
  "B25071",   # median gross rent as % of HH income
  "B25075",   # home value distribution
  "B25077",   # median home value
  "B25091"    # owner cost burden (monthly owner costs as % of HH income)
)

message("Pulling ", length(tables_pit), " point-in-time ACS tables...")
pit <- map(tables_pit, \(tbl) {
  message("  ", tbl, "...")
  pull_acs_bind(tbl)
}) |>
  set_names(tables_pit)

## 4. Trend pulls — median rent + median value ----
message("Pulling trend tables (", paste(trend_years, collapse = "/"), ")...")

trend_rent <- map_dfr(trend_years, \(yr) {
  message("  B25064 ", yr, "...")
  pull_acs_bind("B25064", year = yr)
})

trend_value <- map_dfr(trend_years, \(yr) {
  message("  B25077 ", yr, "...")
  pull_acs_bind("B25077", year = yr)
})

## 5. Write output ----
write_rds(
  c(pit, list(trend_rent = trend_rent, trend_value = trend_value)),
  "data/acs_costs.rds"
)
message("Wrote data/acs_costs.rds")

## 6. Validate ----
costs <- read_rds("data/acs_costs.rds")

# Fauquier 2024 ACS: median gross rent (B25064_001) ~$1,800–$2,200 range expected
rent_fauquier <- costs$B25064 |>
  filter(GEOID == fauquier, str_detect(variable, "_001"))

# Fauquier 2024 ACS: median home value (B25077_001) — GP benchmark not specified;
# expect $500k–$700k range given market conditions
value_fauquier <- costs$B25077 |>
  filter(GEOID == fauquier, str_detect(variable, "_001"))

stopifnot(
  length(costs) == length(tables_pit) + 2,  # 8 pit + 2 trend
  nrow(trend_rent) > 0,
  nrow(trend_value) > 0,
  between(rent_fauquier$estimate, 1000, 3000),
  between(value_fauquier$estimate, 300000, 900000)
)
message("acs_costs.R validation passed.")
message("  Fauquier 2024 median rent: $", format(rent_fauquier$estimate, big.mark = ","))
message("  Fauquier 2024 median value: $", format(value_fauquier$estimate, big.mark = ","))
```

---

## Script 3 — `r/fmr.R` → `data/fmr.rds`

Reads two HUD xlsx files. FMR covers the Fauquier HMFA (`METRO47900M47900`); SAFMR gives
zip-level rents for the three town zip codes.

HUD FMR file layout (standard): columns include `hud_areaname`, `areatype` or `metro_code`,
and bedroom columns `fmr_0` through `fmr_4` (or similar naming). SAFMR layout adds `zip` and
duplicates zip 20186 across multiple HMFAs — filter on the metro code.

```r
# fmr.R ----
# What:   Tidy HUD FMR and SAFMR data for Fauquier County
# Source: data/raw/hud/hud_fmr_fy2026.xlsx, data/raw/hud/hud_safmr_fy2026.xlsx
# Output: data/fmr.rds

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier_hmfa <- "METRO47900M47900"
town_zips     <- c("20186", "20187", "22712")

## 2. FMR — county/metro level ----
message("Reading hud_fmr_fy2026.xlsx...")
fmr_raw <- read_excel("data/raw/hud/hud_fmr_fy2026.xlsx") |>
  clean_names()

# Inspect available column names on first run
message("  FMR columns: ", paste(names(fmr_raw)[1:10], collapse = ", "), "...")

# Filter to Fauquier HMFA and select bedroom columns
# Column names vary by HUD release year; adjust selectors if clean_names() differs
fmr <- fmr_raw |>
  filter(str_detect(
    coalesce(hud_areacode, metro_code, fips2010, ""),   # try likely column names
    fauquier_hmfa
  )) |>
  select(
    area_code  = matches("hud_areacode|metro_code|areacode"),
    area_name  = matches("hud_areaname|areaname|area_name"),
    fmr_0br    = matches("^fmr_0|^zero_br"),
    fmr_1br    = matches("^fmr_1|^one_br"),
    fmr_2br    = matches("^fmr_2|^two_br"),
    fmr_3br    = matches("^fmr_3|^three_br"),
    fmr_4br    = matches("^fmr_4|^four_br")
  ) |>
  slice(1)  # should be exactly 1 row for this HMFA

stopifnot(nrow(fmr) == 1)
message("  FMR row: ", fmr$area_name)

## 3. SAFMR — zip level ----
message("Reading hud_safmr_fy2026.xlsx...")
safmr_raw <- read_excel("data/raw/hud/hud_safmr_fy2026.xlsx") |>
  clean_names()

message("  SAFMR columns: ", paste(names(safmr_raw)[1:10], collapse = ", "), "...")

# Zip 20186 appears twice (different HMFAs) — keep only the Fauquier HMFA row
safmr <- safmr_raw |>
  filter(
    str_detect(coalesce(zip, zip_code, ""), paste(town_zips, collapse = "|")),
    str_detect(coalesce(hud_areacode, metro_code, areacode, ""), fauquier_hmfa)
  ) |>
  select(
    zip        = matches("^zip"),
    area_code  = matches("hud_areacode|metro_code|areacode"),
    safmr_0br  = matches("^safmr_0|^s?fmr_0"),
    safmr_1br  = matches("^safmr_1|^s?fmr_1"),
    safmr_2br  = matches("^safmr_2|^s?fmr_2"),
    safmr_3br  = matches("^safmr_3|^s?fmr_3"),
    safmr_4br  = matches("^safmr_4|^s?fmr_4")
  )

message("  SAFMR rows retained: ", nrow(safmr), " (expect 3 for zips 20186, 20187, 22712)")

## 4. Write output ----
write_rds(list(fmr = fmr, safmr = safmr), "data/fmr.rds")
message("Wrote data/fmr.rds")

## 5. Validate ----
out <- read_rds("data/fmr.rds")
stopifnot(
  nrow(out$fmr) == 1,
  nrow(out$safmr) == 3,
  between(out$fmr$fmr_2br, 1200, 3500)  # DC-area 2BR FMR; FY2026 expect ~$2,000–$2,800
)
message("fmr.R validation passed.")
message("  2BR FMR: $", format(out$fmr$fmr_2br, big.mark = ","))
message("  SAFMRs: ", paste(out$safmr$zip, "$", out$safmr$safmr_2br, collapse = " | "))
```

**Note on column name matching**: HUD releases FMR/SAFMR files with slightly different column
naming each year. The `matches()` selectors above cover the most common patterns; if a column
is not found, the script will warn. Run with `message("  FMR columns: ...")` visible to verify
before trusting output.

---

## Script 4 — `r/nhpd.R` → `data/nhpd.rds`

Filters the Virginia-wide NHPD export to Fauquier County properties. The XLSX has ~290 columns
and type-mixing warnings from numeric/character mixed cells — `suppressWarnings()` on read. Select
the ~12 needed columns immediately to avoid carrying the full width.

Target: ~13 Fauquier properties per PLAN.md §9 validation benchmark.

```r
# nhpd.R ----
# What:   Filter NHPD Virginia extract to Fauquier County; tidy subsidy program data
# Source: data/raw/nhpd/nhpd_virginia.xlsx
# Output: data/nhpd.rds

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
library(lubridate)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Read and filter ----
message("Reading nhpd_virginia.xlsx (290-col XLSX — suppressing type warnings)...")

nhpd_raw <- suppressWarnings(
  read_excel("data/raw/nhpd/nhpd_virginia.xlsx")
) |>
  clean_names()

message("  Raw: ", nrow(nhpd_raw), " rows × ", ncol(nhpd_raw), " columns")

# Inspect county column name on first run
county_col <- names(nhpd_raw)[str_detect(names(nhpd_raw), "county")]
message("  County columns found: ", paste(county_col, collapse = ", "))

nhpd_fauquier <- nhpd_raw |>
  filter(str_detect(county, regex("fauquier", ignore_case = TRUE)))

message("  Fauquier properties: ", nrow(nhpd_fauquier))

## 3. Select and clean key columns ----
# NHPD standard column names (clean_names() versions); adjust if names differ
properties <- nhpd_fauquier |>
  select(
    nhpd_id        = matches("nhpd_id|property_id"),
    property_name  = matches("property_name|name"),
    address        = matches("^address"),
    city           = matches("^city"),
    zip            = matches("^zip"),
    county,
    total_units    = matches("total_units|units_total"),
    assisted_units = matches("assisted_units|units_assisted"),
    program_type   = matches("program|subsidy_type|federal_program"),
    earliest_expiration = matches("earliest|expir"),
    latest_expiration   = matches("latest|end_date"),
    year_built     = matches("year_built|yr_built")
  ) |>
  mutate(
    across(matches("expiration|year_built|total_units|assisted_units"), as.numeric),
    zip = as.character(zip)
  )

message("  Columns retained: ", ncol(properties))

## 4. Program-level frame (one row per subsidy program per property) ----
# NHPD encodes multiple programs per property in separate columns named like
# federal_program_1, federal_program_2, expiration_date_1, etc.
# Pivot to long format for expiration tracking
program_cols <- names(nhpd_fauquier)[str_detect(names(nhpd_fauquier), "program_\\d|subsidy_\\d")]

if (length(program_cols) > 0) {
  programs <- nhpd_fauquier |>
    select(
      nhpd_id = matches("nhpd_id|property_id"),
      all_of(program_cols),
      matches("expir.*\\d")  # expiration date columns with a trailing number
    ) |>
    pivot_longer(
      cols = matches("program_\\d|subsidy_\\d"),
      names_to = "program_slot",
      values_to = "program_type"
    ) |>
    filter(!is.na(program_type), program_type != "")
} else {
  # Fallback: programs already in the `program_type` column of properties frame
  programs <- properties |>
    select(nhpd_id, program_type) |>
    filter(!is.na(program_type))
  message("  NOTE: no multi-program columns found — using single program_type column")
}

## 5. Write output ----
write_rds(list(properties = properties, programs = programs), "data/nhpd.rds")
message("Wrote data/nhpd.rds")

## 6. Validate ----
out <- read_rds("data/nhpd.rds")
stopifnot(
  between(nrow(out$properties), 8, 25)  # GP benchmark: ~13 Fauquier properties
)
message("nhpd.R validation passed.")
message("  Properties: ", nrow(out$properties))
message("  Total assisted units: ", sum(out$properties$assisted_units, na.rm = TRUE),
        " (benchmark ~750)")
```

---

## Script 5 — `r/costar.R` → `data/costar.rds`

Adapts the faar `costar.R` pattern for FHFH. Key differences from faar:
- Single market (one county), not multi-locality
- Two input files (quarterly market + property-level)
- Sub-header row in quarterly file
- All 31 quarterly columns are character type
- `inventory` column = buildings (always 1); actual unit count is in column `x9`

CPI series: `CUUR0000SEHA` (Rent of Primary Residence) — matches faar pattern, appropriate for
adjusting asking rents to constant dollars.

```r
# costar.R ----
# What:   Clean CoStar quarterly market data and property-level data; CPI-adjust asking rents
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

## 2. Quarterly market data ----
message("Reading costar_market_quarterly.xlsx...")

# Row 1 is an embedded sub-header (Canva design artifact) — slice before renaming
# All 31 columns read as character — parse_number() applied after rename
qtr_raw <- read_excel(
  "data/raw/costar/costar_market_quarterly.xlsx",
  col_types = "text"
)

message("  Raw: ", nrow(qtr_raw), " rows × ", ncol(qtr_raw), " columns")
message("  Row 1 (sub-header to drop): ", paste(unlist(qtr_raw[1, 1:5]), collapse = " | "))

qtr <- qtr_raw |>
  slice(-1) |>           # drop embedded sub-header
  clean_names() |>
  filter(!is.na(x1))     # drop any trailing blank rows

# Inspect column positions on first run to confirm x9 = units
message("  Column names: ", paste(names(qtr)[1:12], collapse = ", "))

# Rename key columns (positions confirmed from PLAN.md notes)
# Adjust if column order differs in the actual export
qtr <- qtr |>
  rename(
    period        = x1,
    property_type = x2,   # verify: should contain "Apartment"
    market_units  = x9    # actual unit count (not inventory/buildings column)
  ) |>
  filter(property_type == "Apartment") |>
  mutate(
    year = as.integer(str_sub(period, 1, 4)),
    qtr  = as.integer(str_sub(period, -1)),
    across(-c(period, property_type), parse_number)
  ) |>
  filter(
    !str_detect(period, "QTD"),  # drop year-to-date partial quarters
    year >= 2015
  )

message("  Quarterly rows after filter: ", nrow(qtr), " (expect ~40–50 quarters)")

## 3. Property-level data ----
message("Reading costar_properties.xlsx...")

props_raw <- read_excel("data/raw/costar/costar_properties.xlsx") |>
  clean_names()

message("  Properties raw: ", nrow(props_raw), " rows")
message("  Property columns: ", paste(names(props_raw)[1:10], collapse = ", "))

# Filter to Apartment properties in Fauquier County
props <- props_raw |>
  filter(
    str_detect(coalesce(property_type, building_type, ""), regex("apartment|multifamily", ignore_case = TRUE)),
    str_detect(coalesce(county, submarket, market, ""), regex("fauquier", ignore_case = TRUE))
  ) |>
  mutate(across(matches("rent|units|year|rate|vacancy"), parse_number))

message("  Apartment properties retained: ", nrow(props))

## 4. CPI-adjust asking rents (quarterly) ----
message("Pulling CPI Rent of Primary Residence (CUUR0000SEHA) for inflation adjustment...")

# Quarterly CPI for join with qtr data
cpi_q <- fredr(
  series_id          = "CUUR0000SEHA",
  observation_start  = as.Date("2015-01-01"),
  frequency          = "q",
  aggregation_method = "avg"
) |>
  mutate(
    year = year(date),
    qtr  = quarter(date)
  ) |>
  select(year, qtr, cpi = value)

# Most recent CPI value as adjustment benchmark
cpi_latest <- fredr(
  series_id         = "CUUR0000SEHA",
  observation_start = as.Date("2025-01-01")
) |>
  slice_max(date, n = 1) |>
  pull(value)

message("  CPI latest: ", round(cpi_latest, 3))

# Identify the asking rent column (likely asking_rent_per_unit or similar)
rent_col <- names(qtr)[str_detect(names(qtr), "asking_rent")]
message("  Rent column(s) found: ", paste(rent_col, collapse = ", "))

qtr_adj <- qtr |>
  left_join(cpi_q, by = c("year", "qtr")) |>
  mutate(
    asking_rent_adj = if_else(
      !is.na(.data[[rent_col[1]]]) & !is.na(cpi),
      (cpi_latest / cpi) * .data[[rent_col[1]]],
      NA_real_
    )
  )

## 5. Write output ----
write_rds(
  list(quarterly = qtr_adj, properties = props, cpi_latest = cpi_latest),
  "data/costar.rds"
)
message("Wrote data/costar.rds")

## 6. Validate ----
out <- read_rds("data/costar.rds")
stopifnot(
  nrow(out$quarterly) >= 20,
  nrow(out$properties) >= 1,
  !is.na(out$cpi_latest)
)
message("costar.R validation passed.")
message("  Quarterly periods: ", nrow(out$quarterly))
message("  Properties: ", nrow(out$properties))
latest_rent <- out$quarterly |>
  slice_max(year * 10 + qtr, n = 1) |>
  pull(asking_rent_adj)
message("  Latest adj asking rent: $", round(latest_rent, 0),
        " (GP benchmark SF rent ~$2,450)")
```

---

## Script 6 — `r/mls.R` → `data/mls.rds`

Most complex script. Three splice sources for price series, four output frames.

**Source mapping:**
- `$monthly`: VAR xlsx (2016–2021) splice to MLS-computed monthly medians (2022+)
- `$annual`: GP appendix `$sales` (2016–2021 counts + medians) splice to MLS annual medians (2022+)
- `$active`: `mls_active_20260709.csv` — July 2026 listings snapshot
- `$rentals`: `mls_rentals_2022_2024.csv` + `mls_rentals_2025_2026_ytd.csv` bound together

**VAR xlsx parsing**: column 2 = Jan 2016; build a date sequence by `seq()`, not by header text.
The label "2021 - Jul" in the sales file marks July 2020 — the value is in the correct column
position despite the wrong label.

```r
# mls.R ----
# What:   Tidy Bright MLS sales + listings + rentals; splice VAR/GP sources for 2016–2021
# Source: data/raw/mls/mls_sales_*.csv (2022+), data/raw/mls/var_*.xlsx (2016–2021),
#         data/gp_appendix.rds ($sales), data/raw/mls/mls_active_*.csv, mls_rentals_*.csv
# Output: data/mls.rds

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
library(lubridate)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

town_zips <- c("20186", "20187", "22712")

## 2. MLS sales transactions (2022+) ----
message("Reading MLS sales CSVs (2022–2026 YTD)...")

sales_files <- list.files("data/raw/mls", pattern = "mls_sales_.*\\.csv", full.names = TRUE)
message("  Files found: ", paste(basename(sales_files), collapse = ", "))

sales_raw <- map_dfr(sales_files, \(f) {
  read_csv(f, show_col_types = FALSE) |>
    mutate(source_file = basename(f))
}) |>
  clean_names()

message("  Transactions loaded: ", nrow(sales_raw))
message("  Columns: ", paste(names(sales_raw)[1:12], collapse = ", "))

# Parse price and date fields — column names vary by MLS export; adjust if needed
# Typical Bright MLS columns after clean_names(): close_price, list_price, close_date,
# new_resale (values "New" / "Resale"), bedrooms, baths, sq_ft, zip_code, county
sales <- sales_raw |>
  mutate(
    close_price = parse_number(as.character(close_price)),
    list_price  = parse_number(as.character(coalesce(list_price, list_price_amount))),
    close_date  = mdy(as.character(coalesce(close_date, closing_date, sold_date))),
    year        = year(close_date),
    month       = month(close_date)
  ) |>
  filter(!is.na(close_date), !is.na(close_price), close_price > 0)

message("  Parsed transactions: ", nrow(sales), " (", min(sales$year), "–", max(sales$year), ")")

## 3. VAR monthly data (2016–2021) ----
message("Reading VAR median sales price xlsx...")

var_msp_raw <- read_excel("data/raw/mls/var_msp_2016_2026_ytd.xlsx", col_names = FALSE)
var_sal_raw <- read_excel("data/raw/mls/var_sales_2016_2026_ytd.xlsx", col_names = FALSE)

# Row containing Fauquier County (col 1 has geography labels)
fauquier_msp_row <- var_msp_raw |> filter(str_detect(`...1`, regex("fauquier", ignore_case = TRUE)))
fauquier_sal_row <- var_sal_raw |> filter(str_detect(`...1`, regex("fauquier", ignore_case = TRUE)))

stopifnot(nrow(fauquier_msp_row) == 1, nrow(fauquier_sal_row) == 1)

# Build date sequence by column position (col 2 = Jan 2016, regardless of header text)
n_months_msp <- ncol(var_msp_raw) - 1
n_months_sal <- ncol(var_sal_raw) - 1
date_seq_msp <- seq(as.Date("2016-01-01"), by = "month", length.out = n_months_msp)
date_seq_sal <- seq(as.Date("2016-01-01"), by = "month", length.out = n_months_sal)

var_monthly_msp <- tibble(
  date         = date_seq_msp,
  median_price = parse_number(as.character(unlist(fauquier_msp_row[-1])))
) |>
  mutate(year = year(date), month = month(date))

var_monthly_sal <- tibble(
  date        = date_seq_sal,
  sales_count = parse_number(as.character(unlist(fauquier_sal_row[-1])))
) |>
  mutate(year = year(date), month = month(date))

# VAR data covers 2016–present; restrict to 2016–2021 (MLS covers 2022+)
var_monthly <- var_monthly_msp |>
  left_join(var_monthly_sal, by = c("date", "year", "month")) |>
  filter(year <= 2021, !is.na(median_price))

message("  VAR monthly rows (2016–2021): ", nrow(var_monthly))

## 4. Monthly price series — VAR splice to MLS ----
message("Building monthly price series (VAR 2016–2021 / MLS 2022+)...")

# Monthly medians from MLS transactions
mls_monthly <- sales |>
  filter(year >= 2022) |>
  summarize(
    median_price = median(close_price, na.rm = TRUE),
    sales_count  = n(),
    .by = c(year, month)
  ) |>
  mutate(date = make_date(year, month, 1))

monthly <- bind_rows(
  var_monthly |> mutate(source = "VAR"),
  mls_monthly |> mutate(source = "MLS")
) |>
  arrange(date)

message("  Monthly rows: ", nrow(monthly), " (", min(monthly$year), "–", max(monthly$year), ")")

## 5. Annual series — GP appendix splice to MLS ----
message("Building annual series (GP 2016–2021 / MLS 2022+)...")

gp <- read_rds("data/gp_appendix.rds")
message("  GP appendix frames: ", paste(names(gp), collapse = ", "))

# GP $sales has columns: year, geography (or county), sales_count, median_price
# Filter to Fauquier
gp_annual <- gp$sales |>
  filter(str_detect(coalesce(geography, county, area, ""), regex("fauquier", ignore_case = TRUE))) |>
  filter(year <= 2021) |>
  select(year, sales_count = matches("sales|count|volume"), median_price = matches("price|median"))

# True annual medians from MLS transactions
mls_annual <- sales |>
  filter(year >= 2022) |>
  summarize(
    median_price = median(close_price, na.rm = TRUE),
    sales_count  = n(),
    .by = year
  )

annual <- bind_rows(
  gp_annual |> mutate(source = "GP"),
  mls_annual |> mutate(source = "MLS")
) |>
  arrange(year)

message("  Annual rows: ", nrow(annual), " (", min(annual$year), "–", max(annual$year), ")")

## 6. Active listings snapshot ----
message("Reading active listings snapshot...")

active_files <- list.files("data/raw/mls", pattern = "mls_active.*\\.csv", full.names = TRUE)
active_raw <- map_dfr(active_files, \(f) read_csv(f, show_col_types = FALSE)) |>
  clean_names()

active <- active_raw |>
  mutate(
    list_price = parse_number(as.character(coalesce(list_price, list_price_amount))),
    list_date  = mdy(as.character(coalesce(list_date, listing_date)))
  ) |>
  filter(!is.na(list_price), list_price > 0)

message("  Active listings: ", nrow(active), " (GP validation benchmark ~218)")

## 7. Rental transactions ----
message("Reading rental CSVs...")

rental_files <- list.files("data/raw/mls", pattern = "mls_rentals.*\\.csv", full.names = TRUE)

rentals_raw <- map_dfr(rental_files, \(f) {
  read_csv(f, show_col_types = FALSE) |>
    mutate(source_file = basename(f))
}) |>
  clean_names()

rentals <- rentals_raw |>
  mutate(
    lease_price = parse_number(as.character(coalesce(close_price, lease_price, list_price))),
    lease_date  = mdy(as.character(coalesce(close_date, lease_date, start_date))),
    year        = year(lease_date),
    month       = month(lease_date)
  ) |>
  filter(!is.na(lease_date), !is.na(lease_price), lease_price > 0)

message("  Rental records: ", nrow(rentals), " (", min(rentals$year), "–", max(rentals$year), ")")

## 8. Write output ----
write_rds(
  list(monthly = monthly, annual = annual, active = active, rentals = rentals),
  "data/mls.rds"
)
message("Wrote data/mls.rds")

## 9. Validate ----
out <- read_rds("data/mls.rds")

# Monthly series: should span 2016–2026
stopifnot(
  min(out$monthly$year) == 2016,
  max(out$monthly$year) >= 2025
)

# Annual median 2025: GP benchmark ~$645,250
ann_2025 <- out$annual |> filter(year == 2025) |> pull(median_price)
if (length(ann_2025) > 0) {
  if (!between(ann_2025, 550000, 750000))
    warning("2025 annual median $", round(ann_2025, 0), " outside expected range $550k–$750k")
  message("  2025 annual median: $", format(round(ann_2025, 0), big.mark = ","),
          " (benchmark ~$645,250)")
}

# Active listings: expect ~200+ as of Jul 2026 snapshot
stopifnot(nrow(out$active) >= 100)

# SF rent: GP benchmark ~$2,450
median_rent <- median(out$rentals$lease_price, na.rm = TRUE)
message("  Median SF rent: $", format(round(median_rent, 0), big.mark = ","),
        " (benchmark ~$2,450)")

message("mls.R validation passed.")
message("  Monthly rows: ", nrow(out$monthly))
message("  Annual rows: ", nrow(out$annual))
message("  Active listings: ", nrow(out$active))
message("  Rental records: ", nrow(out$rentals))
```

---

## Execution order

| Step | Script | Dependency | Why this order |
|---|---|---|---|
| 1 | `r/fred.R` | None | No raw files; fast API call; output not needed by other scripts |
| 2 | `r/acs_costs.R` | None | No raw files; Census API; independent of all local sources |
| 3 | `r/fmr.R` | None | Local xlsx only; fast; independent |
| 4 | `r/nhpd.R` | None | Local xlsx only; fast; independent |
| 5 | `r/costar.R` | fred.R (FRED API key confirmed) | CPI fetch via fredr; local xlsx |
| 6 | `r/mls.R` | `data/gp_appendix.rds` (Session 5 prereq) | Most complex; reads gp_appendix.rds |

Steps 1–4 are independent — run in any order. Step 5 follows 1–4 (FRED key already confirmed).
Step 6 last (most complex; catches any upstream issues first).

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/fred.R
Rscript r/acs_costs.R
Rscript r/fmr.R
Rscript r/nhpd.R
Rscript r/costar.R
Rscript r/mls.R
```

Expected runtime: fred ~30s, acs_costs ~5–8 min (Census API), fmr ~15s, nhpd ~15s,
costar ~30s, mls ~30s.

---

## Known gotchas

1. **CoStar sub-header**: Row 1 of `costar_market_quarterly.xlsx` is a Canva-generated sub-header
   row, not data. `slice(-1)` before `clean_names()`. Column `x9` = actual unit count after
   `clean_names()` renames unnamed columns by position; verify with `message()` on first run.

2. **CoStar column positions are load-bearing**: The script renames `x2` as `property_type`.
   If the export has a different column order, the `filter(property_type == "Apartment")` step
   will silently keep all rows. Always verify with the `message("  Column names: ...")` output.

3. **SAFMR zip 20186 duplicate**: Two rows in the SAFMR file share zip 20186 — different HMFAs.
   The `filter(str_detect(..., fauquier_hmfa))` guard on the metro code keeps only the correct row.

4. **VAR July 2020 mislabel**: The `var_sales_2016_2026_ytd.xlsx` file labels the column for
   July 2020 as "2021 - Jul". Because the script builds dates by position (`seq()`) rather than
   parsing header text, this error has no effect on the output.

5. **NHPD type warnings**: The 290-column XLSX mixes numeric and character data in many columns.
   `suppressWarnings()` wraps the `read_excel()` call. All columns of interest are coerced
   explicitly with `as.numeric()` / `as.character()` after reading.

6. **MLS column name variation**: Bright MLS export columns are named slightly differently across
   export dates. The script uses `coalesce(close_price, ...)` patterns to handle common aliases.
   On first run, check the `message("  Columns: ...")` output against actual column names and
   adjust `mutate()` selectors if needed.

7. **FMR/SAFMR column names**: HUD slightly renames columns across FY releases. The `matches()`
   selectors in `fmr.R` cover common patterns; if a `select()` call produces a zero-column result
   the `stopifnot()` will catch it. Check the `message("  FMR columns: ...")` output.

8. **GP appendix `$sales` column names**: The `gp_appendix.rds` `$sales` frame was built from
   a PDF extraction scratchpad in the prereq session. Its exact column names are not locked;
   `mls.R` uses `matches()` to find the sales count and price columns. If names differ from
   expected, adjust the `select()` call in Section 5.

---

## End-of-session hygiene

### PLAN.md §9 checkboxes to tick

```
- [x] `r/fred.R` (CPI + PMMS series)
- [x] `r/acs_costs.R` (rents/values/burden tables incl. trends)
- [x] `r/fmr.R` (FMR/SAFMR tidy)
- [x] `r/nhpd.R`: Fauquier properties/units by program + expirations
- [x] `r/costar.R`: adapt faar pattern incl. CPI adjustment
- [x] `r/mls.R`: monthly + annual output frames; splice VAR/GP/MLS; listings snapshot; rentals
- [x] Validation: 2025 median price ~$645,250; ~218 active listings (Jul 2026 snapshot);
      SF rent ~$2,450; ~750 assisted units (13 NHPD properties)
```

### PLAN.md §11 log entry

```
### Session 5 — 2026-07-XX

**Completed:**
- `r/fred.R` → `data/fred.rds`
  - CPI less shelter (CUUR0000SA0L2): XXXX annual observations (2010–XXXX)
  - PMMS 30-yr (MORTGAGE30US): monthly + annual; latest annual avg X.XX%
- `r/acs_costs.R` → `data/acs_costs.rds`
  - 8 point-in-time tables (B25031/63/64/70/71/75/77/91) × county + towns + state
  - Trends: B25064 + B25077 for 2013/2017/2021/2024
  - Fauquier 2024 median rent: $XXX,XXX; median value: $XXX,XXX
- `r/fmr.R` → `data/fmr.rds`
  - FMR for METRO47900M47900: 2BR = $X,XXX
  - SAFMR for 20186/20187/22712: [values]
- `r/nhpd.R` → `data/nhpd.rds`
  - XX Fauquier properties; XXX total assisted units
- `r/costar.R` → `data/costar.rds`
  - XX quarterly periods (20XX Q1 – 20XX QX); XX properties
  - Latest CPI-adj asking rent: $X,XXX/mo
- `r/mls.R` → `data/mls.rds`
  - Monthly: XXX rows (2016–2026); Annual: XX rows (2016–2025)
  - Active listings: XXX (Jul 2026 snapshot); Rentals: XXXX records
  - 2025 annual median price: $XXX,XXX (benchmark ~$645,250)

**Deviations / surprises:**
- [CoStar column positions — note if x9 was correct for units]
- [FMR column name adjustments if any]
- [NHPD property count vs. benchmark of 13]
- [MLS column name aliases needed]
- [GP appendix $sales column names actually found]

**Open questions:**
- [None anticipated — add any that arise during script execution]
```

### Save the plan file to the repo

After plan approval, save this file as `R:\hda\fhfh\plans\session-05-market-data.md`
(matching the `session-0N-<topic>.md` convention used by Sessions 1–4).

### Commit command

```bash
git add r/fred.R r/acs_costs.R r/fmr.R r/nhpd.R r/costar.R r/mls.R \
        data/fred.rds data/acs_costs.rds data/fmr.rds data/nhpd.rds \
        data/costar.rds data/mls.rds \
        plans/session-05-market-data.md PLAN.md
git commit -m "Session 5: market data scripts (FRED, ACS costs, FMR, NHPD, CoStar, MLS)"
```
