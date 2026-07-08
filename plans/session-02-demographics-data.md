# Session 2 (Demographics Data) — FHFH Housing Needs Assessment

Detailed execution plan for PLAN.md §9 **Session 2 — Demographics data**. PLAN.md (repo root)
remains the source of truth; this document is the step-by-step build reference for the session.

## Context

Session 1 (Scaffold) is complete and committed. Status as of planning session 2026-07-08:

| Check | Status |
|---|---|
| renv environment | ✅ dplyr 1.2.1, hdatools 0.1.7, all 14 packages installed + snapshotted |
| GEOIDs | ✅ Warrenton `5183136`, Bealeton `5105336` — in `_common.R` and PLAN.md §4 |
| `quarto render` | ✅ clean, 11 pages in `docs/` |
| `data/` directory | ❌ does not exist yet — created by first script that writes to it |
| `r/` scripts | Only `r/affordcalc.R` exists; the five Session 2 scripts are all new |
| CENSUS_API_KEY | ⚠️ in `C:\Users\JTK\Documents\.Renviron` — R HOME is `C:\Users\JTK` so auto-load may fail; see Step 0 |

This session writes **five R data-collection scripts** (no figures, no chapter edits). All output
goes to `data/*.rds`. Chapters read `.rds` files only — they never call APIs (PLAN.md §2).

### Out of scope (this session)
No QCEW/LODES (Session 3). No housing-stock tables (Session 4). No `acs_stock.R`, `acs_costs.R`,
`acs_workforce.R`. No figure code anywhere.

---

## Shell conventions

Every R invocation from the project root `R:\hda\fhfh` via **Bash**:
```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/<name>.R
```
Per PLAN.md §3 and CLAUDE.md Windows R rule: **never run R inline**. Ad-hoc check scripts go to
the session scratchpad, not the repo.

---

## Step 0 — Verify CENSUS_API_KEY

Write a temp script to the scratchpad:
```r
# {scratchpad}/check_key.R
cat("CENSUS_API_KEY:", nzchar(Sys.getenv("CENSUS_API_KEY")), "\n")
cat("FRED_API_KEY:",   nzchar(Sys.getenv("FRED_API_KEY")),   "\n")
```
Run via `Rscript {scratchpad}/check_key.R`. If either prints `FALSE`, the fallback `readRenviron()`
block in each script (see anatomy below) will fire. **Do not block** — continue writing and running
scripts; the fallback handles it. If the fallback also fails (key still empty after `readRenviron()`),
stop and ask Jonathan to copy `C:\Users\JTK\Documents\.Renviron` to `C:\Users\JTK\.Renviron`.

---

## Script anatomy (all five scripts)

Every script must follow PLAN.md §3:

```r
# <name>.R ----
# What:   <one-line description>
# Tables: <list of source tables/products>
# Source: <package/API>
# Output: data/<name>.rds

## 1. Setup ----
library(tidyverse)
library(tidycensus)   # (or tigris, etc.)
library(janitor)

# Load API keys if not already present (handles ~/Documents/.Renviron path issue)
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

# Ensure output directory exists
dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Geography constants (mirrors _common.R — defined here so scripts run standalone)
fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")
virginia   <- "51"

## 2. Pull <table> ----
...

## N. Write output ----
write_rds(<named_list>, "data/<name>.rds")
message("Wrote data/<name>.rds")

## N+1. Validate ----
stopifnot(...)
```

**Style (per PLAN.md §3):**
- Native pipe `|>`. `janitor::clean_names()` on all imported raw data.
- `.by=` over `group_by()` for one-off grouping. `case_match()` for variable→label recoding
  (dplyr 1.2.1; PLAN.md §3 mentions `recode_values()` but that is not available in this dplyr
  version — `case_match()` is the correct 1.2.x equivalent).
- `map_dfr(years, \(yr) get_acs(..., year = yr) |> mutate(year = yr))` for trend pulls.
- No `install.packages()`. Idempotent (safe to re-run). Forward slashes in all paths.

**Output structure:** each script writes a **named list** of data frames as a single `.rds` file.
Include a `geo_type` column (`"county"`, `"place"`, `"state"`) on all ACS/PEP rows.

**ACS pull pattern:** two calls per table — county (filter to relevant GEOIDs) and place (filter to
towns), bind with `bind_rows()`:
```r
bind_rows(
  get_acs(geography = "county", state = "VA", table = "BXXXXX",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% c(fauquier, unname(benchmarks))) |>
    mutate(geo_type = "county"),
  get_acs(geography = "place", state = "VA", table = "BXXXXX",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    filter(GEOID %in% unname(towns)) |>
    mutate(geo_type = "place"),
  get_acs(geography = "state", state = "VA", table = "BXXXXX",
          year = 2024, survey = "acs5", cache_table = TRUE) |>
    mutate(geo_type = "state")
)
```

**Label parsing:**
```r
vars <- load_variables(2024, "acs5", cache = TRUE)
meta <- vars |>
  filter(str_starts(name, "BXXXXX_")) |>
  separate_wider_delim(label, "!!", names = c("est", "total", "col3", "col4"),
                       too_few = "align_start", too_many = "drop")
# Join to data: left_join(data, meta, by = c("variable" = "name"))
```

**Reliability (place-level ACS):** add `cv = (moe / 1.645) / estimate * 100` to all rows. Chapters
use this to flag medium-reliability (CV 15–30%) and suppress or aggregate high-CV (CV > 30%)
estimates per PLAN.md §3.

---

## Script 1 — `r/geo.R` → `data/geo.rds`

Run first — no Census API key required (tigris only).

```r
# geo.R ----
# What:   Study-area boundary files for the orientation map (Ch 1 Fig 1) and any sf joins
# Source: tigris (Census TIGER/Line cartographic boundary files)
# Output: data/geo.rds

## 1. Setup ----
library(tidyverse)
library(tigris)
library(sf)
options(tigris_use_cache = TRUE)

fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")

## 2. County boundaries ----
county_sf <- counties("VA", year = 2023, cb = TRUE) |>
  filter(GEOID %in% c(fauquier, unname(benchmarks)))

## 3. Place boundaries ----
place_sf <- places("VA", year = 2023, cb = TRUE) |>
  filter(GEOID %in% unname(towns))

## 4. Virginia state boundary ----
va_sf <- states(cb = TRUE, year = 2023) |>
  filter(STATEFP == "51")

## 5. Write output ----
write_rds(list(county = county_sf, place = place_sf, state = va_sf), "data/geo.rds")
message("Wrote data/geo.rds")

## 6. Validate ----
geo <- read_rds("data/geo.rds")
stopifnot(
  nrow(geo$county) == 4,   # fauquier + 3 benchmarks
  nrow(geo$place)  == 2,   # warrenton + bealeton
  nrow(geo$state)  == 1    # VA
)
message("geo.R validation passed.")
```

---

## Script 2 — `r/acs_demographics.R` → `data/acs_demographics.rds`

**Tables (ACS 5-year, 2024 anchor, `survey = "acs5"`):**

| Table | Content | Geographies |
|---|---|---|
| B01003 | Total population | county (fauquier + benchmarks), place (towns), state (VA) |
| B01001 | Sex by age | county (fauquier), place (towns), state (VA) |
| B03002 | Race/ethnicity | county (fauquier), place (towns), state (VA) |
| B11001 | Household type | county (fauquier), place (towns), state (VA) |
| B11007 | Households 65+ living alone | county (fauquier), place (towns) |
| B25010 | Average household size | county (fauquier), place (towns), state (VA) |

**B01001 age bands:** Collapse the ~49 variables to 5 readable bands using `case_match()`:
- Under 18: males 003–006 + females 027–030
- 18–34: males 007–011 + females 031–035
- 35–64: males 012–019 + females 036–043
- 65–74: males 020–022 + females 044–046
- 75+: males 023–025 + females 047–049

**B03002 key variables:** Non-Hispanic White alone (003), Non-Hispanic Black alone (004), Non-Hispanic
Asian alone (006), Hispanic/Latino (012), all other/multiracial (aggregate remainder).

**Output:** `list(b01003, b01001, b03002, b11001, b11007, b25010)` → `data/acs_demographics.rds`.

**Validation:**
```r
dem <- read_rds("data/acs_demographics.rds")

pop <- dem$b01003 |> filter(GEOID == fauquier) |> pull(estimate)
stopifnot(between(pop, 70000, 82000))       # GP benchmark: ~75,865

hh <- dem$b11001 |>
  filter(GEOID == fauquier, variable == "B11001_001") |>
  pull(estimate)
stopifnot(between(hh, 24000, 29000))        # GP benchmark: ~26,720

message("acs_demographics.R validation passed.")
```

---

## Script 3 — `r/acs_income.R` → `data/acs_income.rds`

**Tables:**

| Table | Content | Geographies | Vintage |
|---|---|---|---|
| B19013 | Median household income | county (fauquier), place (towns), state (VA) | 2010–2024 trend |
| B19001 | HH income distribution | county (fauquier), place (towns), state (VA) | 2024 only |
| S1701 | Poverty status | county (fauquier), place (towns), state (VA) | 2024 only |

**B19013 trend (PLAN.md §4: "trend tables back to 2010 for income"):**
```r
b19013_trend <- map_dfr(2010:2024, \(yr)
  bind_rows(
    get_acs(geography = "county", state = "VA", table = "B19013",
            year = yr, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID == fauquier) |> mutate(geo_type = "county"),
    get_acs(geography = "place", state = "VA", table = "B19013",
            year = yr, survey = "acs5", cache_table = TRUE) |>
      filter(GEOID %in% unname(towns)) |> mutate(geo_type = "place"),
    get_acs(geography = "state", state = "VA", table = "B19013",
            year = yr, survey = "acs5", cache_table = TRUE) |>
      mutate(geo_type = "state")
  ) |> mutate(year = yr)
)
```

**B19001 income distribution:** Aggregate 17 brackets to 6 bands with `case_match()`:
`"<$25k"`, `"$25–50k"`, `"$50–75k"`, `"$75–100k"`, `"$100–150k"`, `"$150k+"`.

**S1701 (subject table):** Pull with `table = "S1701"`, keep poverty rate row(s) at the summary
level. Subject tables have a different variable structure — parse label hierarchy the same way.

**Output:** `list(b19013_trend, b19001, s1701)` → `data/acs_income.rds`.

**Validation:**
```r
inc <- read_rds("data/acs_income.rds")

inc_2024 <- inc$b19013_trend |>
  filter(GEOID == fauquier, year == 2024) |>
  pull(estimate)
stopifnot(between(inc_2024, 115000, 145000))    # GP benchmark: ~$130,189

message("acs_income.R validation passed.")
```

---

## Script 4 — `r/decennial.R` → `data/decennial.rds`

**Tables:**

| Year | Sumfile | Population table | Units table | Tenure table |
|---|---|---|---|---|
| 2020 | `dhc` | P1 | H1 | H4 |
| 2010 | `sf1` | P001 | H001 | H004 |
| 2000 | `sf1` | P001 | H001 | H004 |

Include 2000 to support the 1990–2025 population trend chart (Ch 2 Fig 1). If tidycensus does not
support `year = 2000` for a particular table, log in §11 and hardcode 2000 county pop (~55,139) as
a tibble row in the output. 1990 is similarly uncertain via API — use Census QuickFacts value
(~47,286) hardcoded if needed; note clearly in §11.

**Geographies:** county (fauquier only — decennial for Culpeper/PW/Loudoun not needed per §9)
+ places (towns GEOIDs).

**Pull pattern (example for 2020):**
```r
p1_2020_county <- get_decennial(
  geography = "county", state = "VA", table = "P1",
  year = 2020, sumfile = "dhc"
) |> filter(GEOID == fauquier) |> mutate(year = 2020, geo_type = "county")

p1_2020_place <- get_decennial(
  geography = "place", state = "VA", table = "P1",
  year = 2020, sumfile = "dhc"
) |> filter(GEOID %in% unname(towns)) |> mutate(year = 2020, geo_type = "place")
```

**Tidy output:** Combine all years into long-format data frames with `year`, `GEOID`, `NAME`,
`geo_type`, `variable`, `value`. Output list elements: `pop` (total population rows from P1/P001),
`units` (total units rows from H1/H001), `tenure` (owner/renter rows from H4/H004).

**Output:** `list(pop, units, tenure)` → `data/decennial.rds`.

**Validation:**
```r
dec <- read_rds("data/decennial.rds")

p2020 <- dec$pop |> filter(GEOID == fauquier, year == 2020, str_detect(variable, "001")) |>
  pull(value)
stopifnot(between(p2020, 70000, 78000))       # Census DHC 2020: ~73,895

p2010 <- dec$pop |> filter(GEOID == fauquier, year == 2010, str_detect(variable, "001")) |>
  pull(value)
stopifnot(between(p2010, 62000, 68000))       # Census SF1 2010: ~65,203

message("decennial.R validation passed.")
```

---

## Script 5 — `r/pep.R` → `data/pep.rds`

**Pulls (tidycensus `get_estimates()`, vintage 2025):**

**1. County population time series 2020–2025:**
```r
pep_pop <- tryCatch(
  get_estimates(geography = "county", state = "VA", year = 2025,
                product = "population", time_series = TRUE) |>
    filter(GEOID == fauquier),
  error = function(e) {
    message("time_series=TRUE failed, falling back to map_dfr: ", conditionMessage(e))
    map_dfr(2020:2025, \(yr)
      get_estimates(geography = "county", state = "VA", year = yr,
                    product = "population") |>
        filter(GEOID == fauquier) |> mutate(year = yr)
    )
  }
)
```

**2. Components of change, county, 2020–2025:**
```r
pep_comp <- get_estimates(geography = "county", state = "VA", year = 2025,
                          product = "components") |>
  filter(GEOID == fauquier)
```

**3. Place population totals (Warrenton incorporated town only):**
```r
pep_places <- tryCatch(
  get_estimates(geography = "place", state = "VA", year = 2025,
                product = "population") |>
    filter(GEOID %in% unname(towns)),
  error = function(e) {
    message("PEP place-level failed (", conditionMessage(e), "). ",
            "Note: Bealeton is a CDP — not covered by PEP. ",
            "Warrenton place estimate unavailable this vintage.")
    NULL
  }
)
```

Note: **Bealeton CDP is not covered by the Census Population Estimates Program** (PEP covers only
incorporated places). Even if the API call succeeds, Bealeton will return no rows. Chapters will use
ACS 5-year estimates or decennial for Bealeton population. Log this in §11.

**Output:** `list(pop = pep_pop, components = pep_comp, places = pep_places)` → `data/pep.rds`.
`places` may be `NULL` — that is a valid output, not an error.

**Validation:**
```r
pep <- read_rds("data/pep.rds")

pop_latest <- pep$pop |>
  filter(if ("year" %in% names(pep$pop)) year == max(year) else DATE_CODE == max(DATE_CODE)) |>
  pull(value)
stopifnot(between(pop_latest, 73000, 83000))    # Fauquier trending ~76–78k for 2025

message("pep.R validation passed.")
```

(The `DATE_CODE` fallback handles the case where `time_series = TRUE` returns the Census's internal
`DATE_CODE` column instead of a `year` column.)

---

## Execution order

1. Step 0: API key check (scratchpad temp script)
2. `r/geo.R` — no Census key needed; fastest; confirms tigris cache works
3. `r/acs_demographics.R` — largest table set; run next to catch API issues early
4. `r/acs_income.R`
5. `r/decennial.R`
6. `r/pep.R`

---

## End-of-session (PLAN.md §3 hygiene)

After all five scripts run clean:

**Tick §9 Session 2 checkboxes in PLAN.md:**
```
- [x] r/acs_demographics.R, r/acs_income.R
- [x] r/decennial.R
- [x] r/pep.R
- [x] r/geo.R
- [x] Validation vs GP appendix (pop, households, income)
```

**Update §11 status table:**
Row 2: `complete | 2026-07-08 | Sonnet 4.6`

**Add §11 log entry** (dated 2026-07-08) noting:
- Actual validation values vs GP benchmarks (pop, HH count, median income)
- Any tolerance variances and explanation (vintage diff ACS 2024 vs GP vintage)
- Bealeton CDP not covered by PEP — logged here
- Whether 2000/1990 decennial required hardcoded fallback, and values used
- Any API call failures or unexpected table structures

**Commit and push:**
```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
git add r/acs_demographics.R r/acs_income.R r/decennial.R r/pep.R r/geo.R PLAN.md
git commit -m "Session 2: demographics + geography data scripts"
git push origin main
```

---

## Verification (Definition of Done)

- [ ] All five scripts run via `Rscript r/<name>.R` with exit code 0 (no errors, no warnings that
      indicate data issues)
- [ ] `data/acs_demographics.rds`, `data/acs_income.rds`, `data/decennial.rds`, `data/pep.rds`,
      `data/geo.rds` all exist and `file.size() > 0`
- [ ] Validation blocks pass: pop ~75,865 (±~10%); HH ~26,720 (±~10%); median income ~$130,189 (±~10%)
- [ ] §9 Session 2 checkboxes ticked in PLAN.md
- [ ] §11 log entry added; any variances explained
- [ ] Scripts + PLAN.md committed and pushed to `origin main`
- [ ] No figure code, no chapter edits, no QCEW/LODES scripts
