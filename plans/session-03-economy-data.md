# Session 3 (Economy & Workforce Data) — FHFH Housing Needs Assessment

Detailed execution plan for PLAN.md §9 **Session 3 — Economy & workforce data**. PLAN.md (repo root)
remains the source of truth; this document is the step-by-step build reference for the session.

## Context

Session 2 (Demographics data) is complete and committed. Status as of planning session 2026-07-08:

| Check | Status |
|---|---|
| renv environment | ✅ dplyr 1.2.1, lehdr installed, `httr2` not explicitly listed (see Step 0) |
| `data/geo.rds` | ✅ county/place/state boundaries from Session 2 — required by `r/lodes.R` |
| `data/raw/` | ❌ directory does not exist yet — created by whichever QCEW path is chosen |
| `data/raw/qcew/` | ❌ does not exist — **QCEW path decision required before executing Script 1** |
| Session 3 scripts | All new: `r/qcew.R`, `r/lodes.R`, `r/acs_workforce.R` |
| Census API key | ✅ available via `readRenviron()` fallback (Session 2 pattern); only needed for `r/acs_workforce.R` |

This session writes **three R data-collection scripts** (no figures, no chapter edits). All output goes
to `data/*.rds`. Chapters read `.rds` files only — they never call APIs (PLAN.md §2).

### Out of scope (this session)

No housing-stock tables (`r/acs_stock.R`), no BPS permits (`r/bps.R`), no CHAS, no MLS/CoStar.
No `B25007`/`B18101`/`B11003`/`S1702` — those are `r/acs_specialpop.R` in Session 7.

---

## Shell conventions

Every R invocation from the project root `R:\hda\fhfh` via **Bash**:

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/<name>.R
```

Per PLAN.md §3 and CLAUDE.md Windows R rule: **never run R inline**. Ad-hoc checks go to the
session scratchpad, not the repo.

---

## Step 0 — QCEW path decision

**This gate must be resolved before writing `r/qcew.R`.** Two mutually exclusive paths.

### Path A — Script-fetch from BLS QCEW open-data API

**Precondition:** Jonathan explicitly approves this in the session (required per PLAN.md §3:
"Anything else on a government host (esp. BLS) requires Jonathan's OK or a manual download").

BLS QCEW open-data endpoint — no API key, no account required:
```
https://data.bls.gov/cew/data/api/{year}/a/area/{AREA_CODE}.csv
```
- `/a/` — annual averages period code
- `{AREA_CODE}` — uppercase BLS area code:
  - Fauquier: `51061`
  - Culpeper: `51047`
  - Prince William: `51153`
  - Loudoun: `51107`
  - Virginia: **`51000`** — state code is 2-digit FIPS + "000"; **not `"51"`**
- The URL returns a CSV with all industry/ownership rows for that area and year

**Implementation:** `r/qcew.R` defines a `fetch_qcew_area_year()` helper using `readr::read_csv(url)`
— no `httr2` dependency needed. See Script 1 for full code.

**Adapted from:** `R:\hfv\crater\R\fns\get_qcew_data.R` — same BLS endpoint, same CSV structure.
Key changes for this project: use native pipe `|>`; use `readr::read_csv()` directly instead of
`httr2`; change `http://` → `https://`; area codes include `"51000"` for state-level.

### Path B — Manual download to `data/raw/qcew/`

Jonathan downloads annual average CSV files from BLS.

**Recommended download:** BLS QCEW Downloadable Data → Annual Averages → CSV Files →
"Single File for All Areas" — one zip per year, named `{YEAR}.annual.singlefile.zip`, ~300 MB
unzipped. Downloads available at https://www.bls.gov/cew/downloadable-data.htm

**Expected structure in `data/raw/qcew/`:** one CSV per year, named `{YEAR}.annual.singlefile.csv`
(2015 through latest available). The R script filters in-memory to the 5 relevant area codes.

**Lighter alternative:** Instead of the singlefile, Jonathan can download only the 5 individual area
CSVs per year using the BLS QCEW Data Views tool. If this path is chosen, use naming convention
`{AREA_CODE}_{YEAR}.csv` (e.g., `51061_2022.csv`) and update the Script 1 read loop accordingly.

### `httr2` check (only relevant if adapting the crater function directly)

The crater `get_qcew_data()` function uses `httr2`. This project's `r/qcew.R` uses `readr::read_csv()`
instead, so `httr2` is not required. If for any reason `httr2` is needed:

```r
# {scratchpad}/check_httr2.R
cat("httr2 available:", requireNamespace("httr2", quietly = TRUE), "\n")
# If FALSE: renv::install("httr2"); renv::snapshot()
```

---

## Script anatomy (all three scripts)

Follows PLAN.md §3 and the Session 2 convention:

```r
# <name>.R ----
# What:   <one-line description>
# Source: <API/package>
# Output: data/<name>.rds

## 1. Setup ----
library(tidyverse)
library(janitor)
# + source-specific libraries

# API key fallback (only needed for tidycensus scripts)
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Geography constants (mirrors _common.R — defined here so scripts run standalone)
fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")
virginia   <- "51"
```

**Output structure:** each script writes a **named list** of tibbles as a single `.rds` file.

---

## Script 1 — `r/qcew.R` → `data/qcew.rds`

```r
# qcew.R ----
# What:   Employment + avg wages, total + 2-digit NAICS, county/benchmarks/VA 2015–2025
# Source: BLS QCEW open-data CSVs (data.bls.gov/cew/data/api/) or data/raw/qcew/
# Output: data/qcew.rds
```

**Area codes and years:**
```r
## 1. Setup ----
library(tidyverse)
library(janitor)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier   <- "51061"
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")
# BLS area codes: 5-digit FIPS for counties; 2-digit state FIPS + "000" for state
area_codes <- c("51061", "51047", "51153", "51107", "51000")
years      <- 2015:2025
```

### agglvl_code discovery (run in scratchpad before main fetch)

The CSV contains all aggregation levels for the area. Run this once to identify the correct
`agglvl_code` values before the main pull — do not commit this check to the repo:

```r
# {scratchpad}/check_agglvl.R
library(tidyverse)
test <- read_csv("https://data.bls.gov/cew/data/api/2022/a/area/51061.csv",
                 na = " ", show_col_types = FALSE)
distinct(test, agglvl_code) |> arrange(agglvl_code) |> print(n = Inf)
# Expected: 70 = county total (all ownerships), 75 = county 2-digit NAICS (all ownerships)
# Adjust agglvl_code filter in the main script based on actual output.
```

Expected codes (verify — not hard-coded in the plan):
- **70** — County, all ownerships, all industries total
- **71–74** — County, individual ownership tiers (federal/state/local/private)
- **75** — County, all ownerships, NAICS supersector (2-digit) ← sector breakdown
- **76** — County, private only, NAICS supersector

Use `agglvl_code %in% c("70", "75")` for total + 2-digit NAICS all-ownerships. Adjust if discovery
shows different codes.

### Path A — script-fetch

```r
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
```

### Path B — read from `data/raw/qcew/`

```r
## 2. Read local files (Path B) ----
# Expects: data/raw/qcew/{YEAR}.annual.singlefile.csv — one file per year
qcew_files <- list.files("data/raw/qcew", pattern = "\\.csv$", full.names = TRUE)
if (length(qcew_files) == 0) stop("No QCEW files in data/raw/qcew/. See Step 0 in the plan.")

raw <- map_dfr(qcew_files, \(f) {
  yr <- as.integer(str_extract(basename(f), "\\d{4}"))
  read_csv(f, na = " ", show_col_types = FALSE,
           col_types = cols(.default = "c")) |>
    mutate(year_fetched = yr)
}) |>
  filter(area_fips %in% area_codes)
```

### Shared post-fetch processing (both paths)

```r
## 3. Filter and type-convert ----
qcew_clean <- raw |>
  clean_names() |>
  filter(
    area_fips %in% area_codes,
    agglvl_code %in% c("70", "75")   # adjust if discovery step shows different codes
  ) |>
  mutate(
    across(c(annual_avg_estabs, annual_avg_emplvl, total_annual_wages,
             annual_avg_wkly_wage, avg_annual_pay), as.numeric),
    year = coalesce(as.integer(year), year_fetched)
  ) |>
  select(-any_of("year_fetched"))

## 4. Split into named list elements ----
qcew_total  <- qcew_clean |> filter(agglvl_code == "70")
qcew_sector <- qcew_clean |> filter(agglvl_code == "75")

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
stopifnot(between(fauquier_jobs, 17000, 33000))   # wide tolerance for vintage difference

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
```

**Expected output columns in `qcew$total` / `qcew$sector`:**
`area_fips`, `year`, `own_code`, `industry_code`, `agglvl_code`, `annual_avg_estabs`,
`annual_avg_emplvl`, `total_annual_wages`, `annual_avg_wkly_wage`, `avg_annual_pay`

---

## Script 2 — `r/lodes.R` → `data/lodes.rds`

```r
# lodes.R ----
# What:   LODES8 OD commute flows (county-level) + WAC/RAC (block-level, town-aggregated)
# Source: lehdr package (LODES8 — Census LEHD Origin-Destination Employment Statistics)
# Output: data/lodes.rds
```

**Key design decisions:**
- OD: use `agg_geo = "county"` — the VA block-level OD file is ~250 MB; county-level is tiny
  and sufficient for all report charts (top flows, residency share)
- WAC/RAC: use `agg_geo = "block"` — required to aggregate to Warrenton/Bealeton via spatial join
- LODES8 uses **2020 Census block GEOIDs** — `tigris::blocks(year = 2020)` matches

```r
## 1. Setup ----
library(tidyverse)
library(lehdr)
library(sf)
library(tigris)
library(janitor)
options(tigris_use_cache = TRUE)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier <- "51061"
towns    <- c(warrenton = "5183136", bealeton = "5105336")
```

### LODES year

LODES8 2023 is confirmed available (verified at lehd.ces.census.gov/data/). Use 2023 directly:

```r
## 2. Set LODES year ----
lodes_year <- 2023   # confirmed at lehd.ces.census.gov/data/ — 2026-07-08
message("Using LODES year: ", lodes_year)
```

### OD — county-level commute flows

```r
## 3. OD — Origin-Destination (county aggregation) ----
# main: both home and workplace in Virginia
od_main_county <- grab_lodes("va", lodes_year, lodes_type = "od", job_type = "JT00",
                              state_part = "main", agg_geo = "county") |>
  filter(h_geocode == fauquier | w_geocode == fauquier)

# aux: one end is out-of-state (e.g., DC/MD/WV workers commuting in)
# Note: if agg_geo = "county" fails for aux, fall back to block-level with filter
od_aux_county <- tryCatch(
  grab_lodes("va", lodes_year, lodes_type = "od", job_type = "JT00",
             state_part = "aux", agg_geo = "county") |>
    filter(h_geocode == fauquier | w_geocode == fauquier),
  error = function(e) {
    message("OD aux county-level failed (", conditionMessage(e),
            "). Fetching block-level and filtering.")
    grab_lodes("va", lodes_year, lodes_type = "od", job_type = "JT00",
               state_part = "aux", agg_geo = "block") |>
      filter(str_starts(h_geocode, fauquier) | str_starts(w_geocode, fauquier)) |>
      mutate(h_geocode = str_sub(h_geocode, 1, 5),
             w_geocode = str_sub(w_geocode, 1, 5)) |>
      summarise(S000 = sum(S000), .by = c(h_geocode, w_geocode))
  }
)

od_county <- bind_rows(od_main_county, od_aux_county)
```

### Derive live/work metrics from OD

```r
## 4. Live/work summary ----
# Jobs located in Fauquier (workers commuting IN + residents working locally)
total_fauquier_jobs <- od_county |>
  filter(w_geocode == fauquier) |>
  summarise(S000 = sum(S000)) |> pull(S000)

# Jobs held by Fauquier residents working in Fauquier (both ends in county)
resident_held <- od_county |>
  filter(h_geocode == fauquier, w_geocode == fauquier) |>
  summarise(S000 = sum(S000)) |> pull(S000)

# Residency share — GP benchmark: 35.4%
residency_share <- resident_held / total_fauquier_jobs

# Top destination counties for Fauquier residents commuting OUT
top_destinations <- od_county |>
  filter(h_geocode == fauquier, w_geocode != fauquier) |>
  arrange(desc(S000)) |>
  slice_head(n = 15)

# Top origin counties for workers commuting INTO Fauquier
top_origins <- od_county |>
  filter(h_geocode != fauquier, w_geocode == fauquier) |>
  arrange(desc(S000)) |>
  slice_head(n = 15)
```

### WAC and RAC — block-level for town aggregation

```r
## 5. WAC — Workplace Area Characteristics (block-level) ----
# C000 = total jobs; CNS01–CNS20 = jobs by NAICS sector
wac_block <- grab_lodes("va", lodes_year, lodes_type = "wac", job_type = "JT00",
                         segment = "S000", agg_geo = "block") |>
  filter(str_starts(w_geocode, fauquier)) |>
  clean_names()

## 6. RAC — Residence Area Characteristics (block-level) ----
# C000 = workers living in each block (all jobs they hold, regardless of workplace)
rac_block <- grab_lodes("va", lodes_year, lodes_type = "rac", job_type = "JT00",
                         segment = "S000", agg_geo = "block") |>
  filter(str_starts(h_geocode, fauquier)) |>
  clean_names()
```

### Block → town crosswalk

```r
## 7. Build block-to-town crosswalk ----
# LODES8 uses 2020 Census block GEOIDs (15-digit: state 2 + county 3 + tract 6 + block 4)
# tigris::blocks() with year = 2020 returns GEOID20 column for 2020 blocks
fauquier_blocks <- blocks("VA", county = "061", year = 2020)

# Verify block GEOID column name (may be GEOID20 or GEOID depending on tigris version)
block_id_col <- if ("GEOID20" %in% names(fauquier_blocks)) "GEOID20" else "GEOID"

geo <- read_rds("data/geo.rds")
town_sf <- geo$place  # Warrenton + Bealeton polygons (from Session 2)

# Use block centroids for point-in-polygon assignment
# (block polygons can straddle town boundaries; centroid gives cleaner assignment)
block_centroids <- st_centroid(fauquier_blocks)
block_town_join <- st_join(
  block_centroids,
  town_sf |> select(town_geoid = GEOID, town_name = NAME),
  join = st_within
) |>
  st_drop_geometry() |>
  select(block_geoid = !!block_id_col, town_geoid, town_name)
# Blocks not within any town get town_geoid = NA — county-level only for those blocks

## 8. Aggregate WAC to towns ----
wac_town <- wac_block |>
  left_join(block_town_join, by = c("w_geocode" = "block_geoid")) |>
  filter(!is.na(town_geoid)) |>
  summarise(across(where(is.numeric), sum), .by = c(town_geoid, town_name))
# c000 in wac_town = total jobs with workplace in each town's block footprint

## 9. Write output ----
write_rds(
  list(
    od_county        = od_county,
    wac_block        = wac_block,
    rac_block        = rac_block,
    block_town       = block_town_join,
    wac_town         = wac_town,
    live_work        = tibble(
      total_jobs       = total_fauquier_jobs,
      resident_held    = resident_held,
      residency_share  = residency_share
    ),
    top_destinations = top_destinations,
    top_origins      = top_origins,
    lodes_year       = lodes_year
  ),
  "data/lodes.rds"
)
message("Wrote data/lodes.rds")

## 10. Validate ----
lodes <- read_rds("data/lodes.rds")

# Block coverage
stopifnot(nrow(lodes$wac_block) > 300)   # Fauquier has 500+ populated blocks

# Residency share — GP benchmark: 35.4% (±10pp for LODES year vs GP vintage)
stopifnot(between(lodes$live_work$residency_share, 0.20, 0.55))

# Total jobs (WAC-equivalent from OD) — GP: ~24,138 (±30% for year diff)
stopifnot(between(lodes$live_work$total_jobs, 15000, 35000))

# Top flows non-empty
stopifnot(nrow(lodes$top_destinations) >= 5)
stopifnot(nrow(lodes$top_origins) >= 5)

# Block-town crosswalk touches both towns
stopifnot(all(unname(towns) %in% unique(lodes$block_town$town_geoid[!is.na(lodes$block_town$town_geoid)])))

message("lodes.R validation passed.",
        " | Residency share: ", round(lodes$live_work$residency_share * 100, 1), "%",
        " | Total jobs: ", lodes$live_work$total_jobs,
        " | LODES year: ", lodes$lodes_year)
```

---

## Script 3 — `r/acs_workforce.R` → `data/acs_workforce.rds`

```r
# acs_workforce.R ----
# What:   B08303 travel time to work + B08007 place of work, for Ch 2 commute charts
# Tables: B08303, B08007
# Source: tidycensus (ACS 5-year 2024)
# Output: data/acs_workforce.rds
```

```r
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
```

**B08303 — Travel time to work:**

Universe: workers 16+ who did not work from home.

```r
## 2. B08303 — Travel time to work ----
b08303 <- pull_acs_bind("B08303")

# Label lookup (for chapters to use when collapsing time bands)
# Key variables:
#   _001: Total | _002–_004: <15 min | _005–_007: 15–29 min
#   _008–_010: 30–44 min | _011: 45–59 min | _012: 60–89 min | _013: 90+ min
# Report metric: % with 45+ min commute = sum(_011 + _012 + _013) / _001
vars_b08303 <- load_variables(2024, "acs5", cache = TRUE) |>
  filter(str_starts(name, "B08303_")) |>
  separate_wider_delim(label, "!!", names = c("est", "total", "time_band"),
                       too_few = "align_start", too_many = "drop")
```

**B08007 — Place of work by state and county:**

Universe: workers 16 years and over.

```r
## 3. B08007 — Place of work ----
# IMPORTANT: verify variable labels via load_variables() before using variable codes
# directly in chapter code. The label hierarchy in 2024 ACS 5-year:
#   _001: Total workers
#   _002: Worked in state of residence (subtotal)
#   _003:   Worked in county of residence       ← "local workers" (complement of out-commuters)
#   _004:   Worked in different county, same state
#   _005: Worked outside state (subtotal)
#   _006:   Different state
#   _007:   Abroad
# Key metric for Ch 2: B08007_003 / B08007_001 = share of workers employed in home county
b08007 <- pull_acs_bind("B08007")

vars_b08007 <- load_variables(2024, "acs5", cache = TRUE) |>
  filter(str_starts(name, "B08007_")) |>
  separate_wider_delim(label, "!!", names = c("est", "total", "col3", "col4"),
                       too_few = "align_start", too_many = "drop")
```

**Note:** B08007 variable labels shift across ACS vintages — always confirm B08007_003 is
"worked in county of residence" via `vars_b08007` before using it in chapter calculations.
Place-level (Warrenton/Bealeton) estimates for B08007 will have high CVs (small populations);
chapters apply the standard CV > 30% suppression rule.

```r
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

# B08303 total row for Fauquier (workers 16+ not WFH)
b08303_total <- wf$b08303 |>
  filter(GEOID == fauquier, variable == "B08303_001") |>
  pull(estimate)
stopifnot(between(b08303_total, 20000, 45000))

# B08007 total row for Fauquier (all workers 16+)
b08007_total <- wf$b08007 |>
  filter(GEOID == fauquier, variable == "B08007_001") |>
  pull(estimate)
stopifnot(between(b08007_total, 30000, 55000))

# All 4 county geographies present
n_counties_b08303 <- wf$b08303 |> filter(geo_type == "county") |> distinct(GEOID) |> nrow()
n_counties_b08007 <- wf$b08007 |> filter(geo_type == "county") |> distinct(GEOID) |> nrow()
stopifnot(n_counties_b08303 == 4, n_counties_b08007 == 4)   # fauquier + 3 benchmarks

message("acs_workforce.R validation passed.")
```

---

## Execution order

1. **Step 0** — QCEW path decision in session chat; scratchpad `agglvl_code` check
2. **`r/lodes.R`** — no Census key required; run first to confirm `lehdr` works (LODES year fixed at 2023)
3. **`r/acs_workforce.R`** — standard ACS pattern; validates Census key is working
4. **`r/qcew.R`** — run last; depends on Step 0 path decision and `agglvl_code` check

---

## API / data gotchas for this session

| Gotcha | Detail |
|---|---|
| **BLS state area code** | Virginia's area code in QCEW is `"51000"`, not `"51"`. Passing `"51"` silently returns 0 rows with no error. |
| **QCEW 2025 availability** | ✅ Confirmed available (verified at bls.gov/cew/downloadable-data-files.htm 2026-07-08). `years <- 2015:2025` is correct as written. |
| **QCEW agglvl_code for NAICS** | The plan assumes `agglvl_code = "75"` for 2-digit NAICS (all ownerships). Run the scratchpad discovery step before the full fetch — BLS may change these codes across file vintages. |
| **PEP API precedent** | Session 2 found that the post-2020 PEP API silently returned 0 rows when called without `vintage`. Same silent-empty-return pattern is possible with BLS CSV fetches — always check `nrow()` before `stopifnot()`. |
| **LODES OD aux** | Without the "aux" file, cross-state commuters (DC, MD, WV workers entering Fauquier) are missing from inflow counts. The script fetches aux; if county-level aggregation fails for aux, there's a block-level fallback. |
| **LODES block GEOID column** | `tigris::blocks(year = 2020)` returns `GEOID20`, not `GEOID`. The script handles both via column-name check. |
| **LODES OD file size** | VA block-level OD file is ~250 MB — this is why the script uses `agg_geo = "county"` for OD. WAC/RAC block-level files for VA are much smaller. |
| **B08007 label drift** | B08007 variable numbering can shift between ACS vintages. Always confirm `vars_b08007` lookup before using variable codes in chapter code. |

---

## End-of-session (PLAN.md §3 hygiene)

After all three scripts run clean:

**Tick §9 Session 3 checkboxes in PLAN.md:**
```
- [x] r/qcew.R: jobs + avg wages, total + 2-digit NAICS, county/benchmarks/VA 2015–2025
- [x] r/lodes.R: OD (live/work shares, top flows), WAC/RAC; block-aggregate to towns
- [x] r/acs_workforce.R: B08303, B08007
- [x] Validation: Fauquier ~24,138 jobs (2025), avg wage ~$64,272, ~35.4% of jobs held by residents
```

**Update §11 status table:**
Row 3: `complete | {date} | Sonnet 4.6`

**Add §11 log entry** noting:
- QCEW path taken (A or B)
- agglvl_code values confirmed from discovery step (record actual codes)
- Actual Fauquier job count, avg wage, residency share vs GP benchmarks; explain any variance
- LODES year: 2023 (confirmed)
- Any zero-row returns, API failures, or unexpected table structures

**Commit and push:**
```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
git add r/qcew.R r/lodes.R r/acs_workforce.R PLAN.md
git commit -m "Session 3: economy + workforce data scripts"
git push origin main
```

---

## Definition of done

- [ ] All three scripts run via `Rscript r/<name>.R` with exit code 0
- [ ] `data/qcew.rds`, `data/lodes.rds`, `data/acs_workforce.rds` all exist with `file.size() > 0`
- [ ] QCEW: jobs + wages present for all 5 areas, years 2015–2025; 15+ NAICS sectors for Fauquier
- [ ] LODES: `live_work$residency_share` between 20% and 55% (GP: 35.4%); `top_destinations` and `top_origins` non-empty; `wac_town` has rows for both town GEOIDs
- [ ] ACS: B08303 + B08007 for Fauquier + 3 benchmark counties + 2 towns; validation blocks pass
- [ ] §9 Session 3 checkboxes ticked in PLAN.md
- [ ] §11 log entry added; QCEW path + agglvl_code + any variances explained
- [ ] No figure code, no chapter edits, no Session 4 tables (no `acs_stock.R`, `bps.R`)
