# Session 7 (Projections & Special-Populations Data) — FHFH Housing Needs Assessment

Detailed execution plan for PLAN.md §9 **Session 7 — Projections & special-populations data**.
PLAN.md (repo root) remains the source of truth; this document is the step-by-step build reference
for the session.

## Context

Sessions 1–6 are complete and committed. Session 7 is a **data/computation session**: it writes
four `.rds` files and touches **no `.qmd` chapter** (`projections.qmd` = Session 11,
`populations.qmd` = Session 10). The data-flow rule holds: `r/` scripts → `data/*.rds` → chapters
`read_rds()` only.

Status as of planning (2026-07-10):

| Check | Status |
|---|---|
| `data/raw/wcoop/` — `VAPopProjections_Total_2030-2050_1July2025.xlsx`, `…_AgeSex_…xlsx`, `…_LargeTowns_…xlsx` (+ methodology docx) | ✅ present & inspected |
| `data/raw/vdoe/` — 5 xlsx (2020-21 … 2024-25) | ✅ present & inspected |
| `data/raw/pit/fhn_2025_pit_summary.pdf` | ✅ present & fully transcribed (values below) |
| Session 2 output `data/acs_demographics.rds` (`b11001`, `b01003`, `b25010`, `b01001`, `b11007`) | ✅ present |
| Session 4 output `data/bps.rds` (`bps_county`) | ✅ present |
| Session 6 outputs `data/chas.rds` (`t7`), `data/hud_ami.rds` (`ami`), `data/gaps.rds` | ✅ present |
| `CENSUS_API_KEY` in `C:/Users/JTK/Documents/.Renviron` | ✅ (only `acs_specialpop.R` needs it) |
| New downloads required | ❌ none — all raw sources supplied; only `acs_specialpop.R` calls an API (Census) |

### Raw-data facts already extracted (so the implementer need not re-inspect)

**Weldon Cooper — Total (`…_Total_…`), Fauquier `51061`:** 2030 = 77,588 · 2035 = 81,200 ·
2040 = 84,812 · 2045 = 88,992 · 2050 = 93,171 (floats — round). Two sheets:
`Total_2030,2040,2050` and `Total_2035,2045,2055`. Virginia `51000` 2050 = 10,343,481.

**Weldon Cooper — LargeTowns (`…_LargeTowns_…`), Warrenton town `5183136`:** 2030 = 10,693 ·
2040 = 11,689 · 2050 = 12,841. One sheet. **Bealeton is absent** (CDP — WC town projections cover
"large towns" only; a footnote row sits at the bottom). Warrenton is the only Fauquier town present.

**Weldon Cooper — AgeSex (`…_AgeSex_…`):** three sheets `2030` / `2040` / `2050`. Header layout
(0-based row index): row 0 title, row 1 producer, **row 2 = section labels**, **row 3 = age-band
labels**, row 4+ = data. Section labels sit at columns: `Projected Age, YYYY (Total)` at **col 3**,
`(Female)` at **col 21**, `(Male)` at **col 39** — i.e. section order is **Total, Female, Male**
(Female before Male). Each section = 18 five-year bands `0 to 4 … 85 and Over`. So (0-based):
cols 0–2 = FIPS / Geography Name / Total Population; **cols 3–20 = Total section**; 21–38 = Female;
39–56 = Male. County **65+** = Total-section bands `65 to 69`,`70 to 74`,`75 to 79`,`80 to 84`,
`85 and Over` (cols 16–20). **75+** = last three (cols 18–20). Fauquier is the `51061` FIPS row.

**PIT — FHN 2025 (transcribed from the PDF; counting night Jan 22, 2025):** region =
**Culpeper, Fauquier, Madison, Orange, Rappahannock** (Orange & Rappahannock had **0** in 2025).
Historical region-wide totals:

| year | individuals | adults | children | households |
|---|---|---|---|---|
| 2025 | 191 | 135 | 56 | 128 |
| 2024 | 274 | 181 | 93 | 172 |
| 2023 | 275 | 183 | 92 | 160 |
| 2022 | 280 | 221 | 63 | 174 |
| 2021 | 236 | 138 | 98 | 142 |
| 2020 | 213 | 108 | 105 | 85 |
| 2019 | 162 | 91 | 71 | 89 |
| 2018 | 146 | 93 | 53 | 77 |

2025 **location split** (only 2025 is broken out by county): Fauquier = 53 adults / 43 children /
**96 total** (50.3% of the 191); Culpeper = 67 / 9 / 76; Madison = 15 / 4 / 19.

**VDOE McKinney-Vento — Fauquier County Public Schools (LEA 030):** 2020-21 = **191** · 2021-22 =
**135** · 2022-23 = **101** · 2023-24 = **100** · 2024-25 = **92** (clear decline). Suppression flags
`<` and `*` appear for other small divisions (Fauquier is never suppressed).

**Baselines (already in `data/acs_demographics.rds`, all 2020-2024 ACS 5-year, county row):**
households `b11001` `B11001_001` = **26,720**; population `b01003` `B01003_001` = **74,577**;
average household size `b25010` `B25010_001` (read at build; Fauquier ≈ 2.70); age base `b01001`
bands `"65-74"` + `"75+"`. Permit pace `data/bps.rds$bps_county` 2020–2025 mean = **266/yr**
(sum `units` over the 4 `type`s per year, then mean).

### Decisions locked for this session (2026-07-10)

1. **Household-projection method → compute BOTH, feature the GP-reconciling one.** PLAN §7/§8 say
   "constant 2024 headship ratio applied to WC totals." Two defensible ratios exist and they tell
   different stories:
   - **Headship on total population**: `26,720 / 74,577 = 0.3583`; 2050 → ~33,386 households
     (**+6,666**); production need ~264/yr. (Conservative — production roughly keeps pace.)
   - **Constant average household size**: `WC pop ÷ B25010 avg HH size (≈2.70)`; 2050 → ~34,300
     households (**≈+7,600**); production need ~305/yr. **This reconciles with GP (+7,737, 307/yr).**

   `wcoop.R` computes and stores **both**; the §9 validation benchmarks the avg-HH-size route against
   GP and prints the headship route as the conservative alternative. **Headline choice is left to the
   Ch 6 build (Session 11)** with full documentation. Age-adjusted headship stays out of scope (§10).

2. **Needs-allocation table (Ch 6 Fig 5) → built in `wcoop.R` now** (confirmed with Jonathan). A
   `needs_allocation` frame: current CHAS **T7** tenure × AMI shares applied to projected household
   growth, joined to `gaps.rds` gap directions. Honors the read_rds-only rule; keeps all
   projection-derived numbers in one file. (§7 Ch6 item 5 lists it as a figure, so it is in scope
   even though the §9 checkbox doesn't enumerate it — flag this in the §11 log.)

3. **B11007 → reuse, do not re-pull** (confirmed with Jonathan). `acs_demographics.R` already wrote
   `b11007` (Fauquier + towns, no VA). `acs_specialpop.R` pulls only the **four net-new** tables
   **B18101, B11003, S1702, B25007**; Ch 5 reads B11007 from `acs_demographics.rds$b11007`.

4. **PIT → transcribe the PDF into hardcoded tibbles.** The FHN summary has no machine-readable
   companion; the committed PDF is the source of record. Present the region-wide 2018–2025 trend +
   the 2025 Fauquier location split + a compact 2025 region demographic frame. **Strong caveats**
   (baked into the frames and source note): the trend is a **5-county region**, only **2025** has a
   Fauquier breakout, Orange/Rappahannock were 0 in 2025. Counts only, never rates (§8).

5. **VDOE → per-file reader** (layouts drift year to year). Filter to "Fauquier County Public
   Schools" (LEA 030); coerce `<`/`*` suppression to `NA`. Fauquier is never suppressed.

6. **WC senior/age detail is county-only.** The AgeSex file has no town age detail and LargeTowns is
   totals-only (Warrenton). Bealeton has no WC projection at all.

### Out of scope (this session)

No `.qmd` edits. **No new caption helpers this session** — `_common.R` has only
`acs_cap`/`chas_cap`/`mls_cap`/`qcew_cap`; `wc_cap`/`pit_cap`/`vdoe_cap` are a **chapter concern**
(add in Sessions 10–11) — note it forward, don't build it here. No age-adjusted headship (§10). No
PUMS. No new datasets or figures beyond §§5 + 7. Scripts write `.rds` only.

---

## Shell conventions

Every R invocation from the project root `R:\hda\fhfh` via **Bash**:

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/<name>.R
```

Per PLAN.md §3 / CLAUDE.md Windows R rule: **never run R inline.** Ad-hoc inspections (sheet names,
header rows, column positions) go to the session scratchpad, not the repo. Scripts are idempotent.
`acs_specialpop.R` needs `CENSUS_API_KEY` (readRenviron guard); `wcoop.R`/`pit.R`/`vdoe.R` need no
keys (local files only).

**dplyr note (carried from Sessions 2–6):** `recode_values(.unmatched="error")` per PLAN §3 is **not
available in installed dplyr 1.2.1**. Current convention (Session 6): use **`case_when()`** — avoids
the `case_match()` deprecation warning.

---

## Step 0 — Prerequisite gate

Resolve before writing script bodies.

1. **Verify raw files present** (all confirmed above): 3 WC xlsx, 5 VDOE xlsx, 1 PIT PDF.
2. **Verify upstream `.rds` present**: `acs_demographics.rds` (`b11001`,`b01003`,`b25010`,`b01001`),
   `bps.rds` (`bps_county`), `chas.rds` (`t7`), `hud_ami.rds` (`ami`), `gaps.rds`. If any missing,
   the dependent frames in `wcoop.R` cannot build — stop and log.
3. **Confirm the AgeSex section order at build** (Total/Female/Male, cols 3/21/39) by reading header
   rows 2–3 — the recipe below assumes it; re-verify since it's load-bearing.

---

## Script anatomy (all scripts)

```r
# <name>.R ----
# What:   <one-line description>
# Source: <data source(s)>
# Output: data/<name>.rds

## 1. Setup ----
library(tidyverse)
library(readxl)     # wcoop, vdoe
library(janitor)    # wcoop, acs_specialpop, vdoe
library(tidycensus) # acs_specialpop only

# (acs_specialpop only) API-key guard — identical block used across all ACS scripts
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- "C:/Users/JTK/Documents/.Renviron"
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Geography constants (mirror _common.R — defined here so scripts run standalone)
fauquier <- "51061"
towns    <- c(warrenton = "5183136", bealeton = "5105336")
virginia <- "51"

## N. <section> ----
## N+1. Write output ----
write_rds(list(...), "data/<name>.rds"); message("Wrote data/<name>.rds")
## N+2. Validate ----
out <- read_rds("data/<name>.rds"); stopifnot(...); message("<name>.R validation passed.")
```

Every script writes a **named `list()` of tibbles** to one `.rds`, then re-reads and validates with
`stopifnot()` + `message()` echoing the GP benchmark. Output element names lowercase (matches
`acs_stock.R`/`acs_demographics.R`).

---

## Script 1 — `r/wcoop.R` → `data/wcoop.rds`  (the core build)

Reads the three WC xlsx + five upstream `.rds`. Produces population/household/production projections,
the senior-age detail, and the needs-allocation table.

**Inputs:** `data/raw/wcoop/*.xlsx`; `acs_demographics.rds` (`b11001`,`b01003`,`b25010`,`b01001`);
`bps.rds` (`bps_county`); `chas.rds` (`t7`); `gaps.rds`; `hud_ami.rds` (`ami`).

**Output list (`data/wcoop.rds`):**

| element | shape | contents |
|---|---|---|
| `pop_county` | tibble | Fauquier `51061` total pop, years 2030/35/40/45/50 (+ VA `51000` for benchmark). cols: `geoid,name,year,population` |
| `pop_town` | tibble | Warrenton `5183136` 2030/40/50. cols: `geoid,name,year,population`. (Bealeton absent — documented) |
| `age_county` | tibble | Fauquier Total-section age bands × 2030/40/50 (long), plus derived `senior_65plus`,`senior_75plus` totals per year |
| `households` | tibble | per year: `wc_pop`, `hh_headship`, `hh_avgsize`, `growth_headship`, `growth_avgsize` (from 2024 base) |
| `production` | tibble | per horizon (2024→2030/40/50): `years_out`, `units_needed_*`, `units_per_year_*` (both methods), `bps_2020_25_avg` (=266) |
| `needs_allocation` | tibble | tenure × AMI band forward need = current CHAS-T7 share × total projected growth (to 2050), joined to gap direction |
| `assumptions` | tibble | base year/pop/HH, headship, avg HH size, vacancy allowance 0.03, bps avg, sources |

**Parsing recipe (verified against the files):**

```r
## 2. WC total population (county + VA) ----
wc_total_a <- read_excel(wcoop_total, sheet = "Total_2030,2040,2050", skip = 4,
                         col_names = c("fips","geography","pop_2030","pop_2040","pop_2050"))
wc_total_b <- read_excel(wcoop_total, sheet = "Total_2035,2045,2055", skip = 4,
                         col_names = c("fips","geography","pop_2035","pop_2045","pop_2055"))
# skip=4 drops: 2 title rows + FIPS header + year sub-header; data begins at Virginia (51000).
pop_county <- list(wc_total_a, wc_total_b) |>
  reduce(full_join, by = c("fips","geography")) |>
  filter(fips %in% c(fauquier, "51000")) |>
  pivot_longer(starts_with("pop_"), names_to = "year", names_prefix = "pop_",
               names_transform = as.integer, values_to = "population") |>
  mutate(population = round(population),
         geoid = fips, name = geography, .keep = "unused")   # tidy names

## 3. WC large-town (Warrenton) ----
pop_town <- read_excel(wcoop_towns, sheet = 1, skip = 4,
                       col_names = c("fips","town","parent_county","pop_2030","pop_2040","pop_2050")) |>
  filter(str_detect(fips, "^\\d")) |>                 # drops the trailing "Note:" text row
  filter(fips == towns[["warrenton"]]) |>
  pivot_longer(...) |> mutate(population = round(population))

## 4. WC age/sex — Total section only, 65+/75+ ----
age_labels <- c("0 to 4","5 to 9","10 to 14","15 to 19","20 to 24","25 to 29","30 to 34",
                "35 to 39","40 to 44","45 to 49","50 to 54","55 to 59","60 to 64",
                "65 to 69","70 to 74","75 to 79","80 to 84","85 and Over")   # 18 bands
read_agesex <- function(sheet) {
  read_excel(wcoop_agesex, sheet = sheet, skip = 4, col_names = FALSE) |>
    select(1:3, 4:21) |>                               # id cols + Total section (cols 4–21, 1-based)
    set_names(c("fips","geography","total_pop", age_labels)) |>
    filter(fips == fauquier) |>
    pivot_longer(all_of(age_labels), names_to = "age_band", values_to = "population") |>
    mutate(year = as.integer(sheet), population = round(population))
}
age_county <- map_dfr(c("2030","2040","2050"), read_agesex)
senior <- age_county |>
  summarise(senior_65plus = sum(population[age_band %in% age_labels[14:18]]),
            senior_75plus = sum(population[age_band %in% age_labels[16:18]]), .by = year)

## 5. Baselines + headship ----
dem <- read_rds("data/acs_demographics.rds")
pull1 <- \(tbl, v) dem[[tbl]] |> filter(GEOID == fauquier, variable == v, geo_type == "county") |> pull(estimate)
base_hh   <- pull1("b11001", "B11001_001")     # 26,720
base_pop  <- pull1("b01003", "B01003_001")     # 74,577
avg_hh    <- pull1("b25010", "B25010_001")     # ≈ 2.70
base_year <- 2024L
headship  <- base_hh / base_pop                # 0.3583

## 6. Household + production frames ----
vac <- 0.03
households <- pop_county |> filter(geoid == fauquier) |>
  transmute(year, wc_pop = population,
            hh_headship = round(wc_pop * headship),
            hh_avgsize  = round(wc_pop / avg_hh),
            growth_headship = hh_headship - base_hh,
            growth_avgsize  = hh_avgsize  - base_hh)
bps_avg <- read_rds("data/bps.rds")$bps_county |>
  filter(year >= 2020) |> summarise(t = sum(units, na.rm = TRUE), .by = year) |>
  summarise(mean(t)) |> pull()                 # 266
production <- households |>
  filter(year %in% c(2030, 2040, 2050)) |>
  transmute(horizon = year, years_out = year - base_year,
            units_per_year_avgsize  = growth_avgsize  * (1 + vac) / years_out,
            units_per_year_headship = growth_headship * (1 + vac) / years_out,
            bps_2020_25_avg = bps_avg)

## 7. Needs-allocation (tenure × AMI × forward growth) ----
# Crosswalk (verbatim from gaps.R so bands align with hud_ami + Ch4 gap):
ami_from_income <- c("≤30% AMI"="ami30","30-50% AMI"="ami50","50-80% AMI"="ami80",
                     "80-100% AMI"="ami100",">100% AMI"="ami120")
chas <- read_rds("data/chas.rds"); gaps <- read_rds("data/gaps.rds")
shares <- chas$t7 |>
  filter(geo_type == "county", !is.na(tenure), household_income %in% names(ami_from_income)) |>
  summarise(hh = sum(estimate, na.rm = TRUE), .by = c(tenure, household_income)) |>
  mutate(share = hh / sum(hh), band = unname(ami_from_income[household_income]))
total_growth <- households |> filter(year == 2050) |> pull(growth_avgsize)   # primary method
needs_allocation <- shares |>
  mutate(forward_need = round(share * total_growth)) |>
  left_join(gaps$rental_gap,    by = c("band")) |>   # attach existing gap direction where keys match
  left_join(gaps$ownership_gap, by = c("band"))       # (join keys VERIFY vs gaps.rds column names)
```

**Validation (§9):**
```r
out <- read_rds("data/wcoop.rds")
g_avg <- out$households$growth_avgsize[out$households$year == 2050]
g_hs  <- out$households$growth_headship[out$households$year == 2050]
pyr   <- out$production$units_per_year_avgsize[out$production$horizon == 2050]
message("  HH growth to 2050 — avg-size: +", g_avg, " (GP +7,737) | headship: +", g_hs, " (conservative)")
message("  Production need/yr (avg-size, to 2050): ", round(pyr), " (GP ~307) vs BPS pace 266")
stopifnot(
  out$pop_county |> filter(geoid == fauquier, year == 2050) |> pull(population) |> between(88000, 98000),
  between(g_avg, 6000, 9500),          # avg-size route reconciles with GP +7,737
  between(pyr,   240, 360),            # near GP 307/yr
  nrow(out$pop_town) >= 1,             # Warrenton present
  tail(out$age_county$year, 1) == 2050,
  sum(out$needs_allocation$forward_need) |> between(0.9 * g_avg, 1.1 * g_avg)  # allocation ≈ total growth
)
```

**Gotchas:** (1) WC values are floats — `round()`. (2) `skip = 4` is correct for all three files
(2 title rows + 2 header rows); re-confirm at build. (3) AgeSex section order is Total/Female/Male —
take **cols 4–21** (1-based) for Total; do not grab Female by mistake. (4) LargeTowns has a trailing
non-data "Note:" row — drop it via `str_detect(fips, "^\\d")`. (5) `needs_allocation` join keys onto
`gaps.rds` frames must be verified against actual column names (`gaps$rental_gap`/`ownership_gap` use
`band` on the `ami30…ami120` scale). (6) `>100% AMI → ami120` is approximate (CHAS has no 120%
granularity — per PLAN §8b).

---

## Script 2 — `r/acs_specialpop.R` → `data/acs_specialpop.rds`

Net-new script. **Closest template = `r/acs_stock.R`** (no-benchmark geography set; whole-table pulls
+ `extract_vars()` label lookups stored under `vars`). Reuse its `pull_acs_bind()` helper **verbatim**:

```r
pull_acs_bind <- function(table) {
  bind_rows(
    get_acs(geography="county", state="VA", table=table, year=2024, survey="acs5", cache_table=TRUE) |>
      filter(GEOID == fauquier) |> mutate(geo_type = "county"),
    get_acs(geography="place",  state="VA", table=table, year=2024, survey="acs5", cache_table=TRUE) |>
      filter(GEOID %in% unname(towns)) |> mutate(geo_type = "place"),
    get_acs(geography="state",  state="VA", table=table, year=2024, survey="acs5", cache_table=TRUE) |>
      mutate(geo_type = "state")
  ) |>
    mutate(cv = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_))   # guarded form
}
```

**Tables (2024 ACS 5-year, point-in-time — no trend):**
- **B18101** — Sex by Age by Disability Status. Collapse to **age band × disability status** (sum
  male + female; `estimate = sum(estimate)`, `moe = sqrt(sum(moe^2))`).
- **B11003** — Family Type by Presence/Age of Own Children. Derive **single-parent-with-own-children**
  (female-hh + male-hh, own children < 18) for §7 Ch5 item 3.
- **S1702** — Poverty Status of Families (**subject table**). Pulls fine via
  `get_acs(table="S1702", survey="acs5", cache_table=TRUE)` (S1701 precedent, `acs_income.R:93`).
- **B25007** — Tenure by Age of Householder. Owner/renter × age band; supports older-householder
  tenure (Ch5) and cross-checks the senior projection.

Follow `acs_stock.R`'s per-table assignment + `set_names` list output. Label lookups via
`extract_vars(prefix)` mapped over the **detail** tables; build the S-table lookup separately.

```r
## Label lookups
vars_detail  <- load_variables(2024, "acs5", cache = TRUE)
vars_subject <- load_variables(2024, "acs5/subject", cache = TRUE)   # NO in-repo precedent — verify
extract_vars <- function(v, prefix) v |> filter(str_starts(name, prefix)) |>
  separate_wider_delim(label, "!!", names = c("est","col2","col3","col4"),
                       too_few = "align_start", too_many = "drop")
vars_list <- list(b18101 = extract_vars(vars_detail, "B18101_"),
                  b11003 = extract_vars(vars_detail, "B11003_"),
                  b25007 = extract_vars(vars_detail, "B25007_"),
                  s1702  = extract_vars(vars_subject, "S1702_"))   # tune names= depth for subject shape

## Output
write_rds(list(b18101 = b18101, b11003 = b11003, s1702 = s1702, b25007 = b25007,
               vars = vars_list), "data/acs_specialpop.rds")
```

**Validation:** Fauquier `B25007_001` (total occupied HH) ≈ 26,720; `B11003_001` = total families
(range check); `B18101_001` ≈ county population; S1702 total-families cell within range. Print each.

**Gotchas:** (1) **S1702 is a subject table** — `load_variables(2024, "acs5/subject")`; variables are
`S1702_C0X_YYY` (the `C01/C02/C03` **column dimension** matters — key on the full `variable`, not just
the trailing 3-digit line; `str_extract(variable,"\\d+$")` alone drops the `C0X`). No in-repo
precedent for the subject label split — verify the `separate_wider_delim` depth at build.
(2) Use `case_when()` not `case_match()`. (3) `cache_table` deprecation warning is harmless.
(4) **Do not re-pull B11007** (reuse `acs_demographics.rds$b11007`). (5) Bealeton CDP cells for
B18101/S1702 will be thin — the guarded `cv` (`if_else(estimate>0,…,NA)`) is the safeguard; no
suppression in the data layer (chapters apply `hdatools::add_reliability()` at render).

---

## Script 3 — `r/pit.R` → `data/pit.rds`

No API/download. **Transcribe** `data/raw/pit/fhn_2025_pit_summary.pdf` into hardcoded tibbles (values
in Context above). No CV/rates — counts with volatility caveats (§8).

```r
# pit.R ----
# What:   Foothills Housing Network (FHN) Point-in-Time counts — region trend + 2025 Fauquier split
# Source: data/raw/pit/fhn_2025_pit_summary.pdf  (transcribed; PDF is the source of record)
# Output: data/pit.rds
#   NOTE: FHN region = Culpeper, Fauquier, Madison, Orange, Rappahannock. Trend is REGION-WIDE;
#   only 2025 is broken out by county. Orange & Rappahannock = 0 in 2025. Refresh = re-read the PDF.

trend <- tribble(
  ~year, ~individuals, ~adults, ~children, ~households,
  2018, 146, 93, 53, 77,   2019, 162, 91, 71, 89,   2020, 213, 108, 105, 85,
  2021, 236, 138, 98, 142, 2022, 280, 221, 63, 174, 2023, 275, 183, 92, 160,
  2024, 274, 181, 93, 172, 2025, 191, 135, 56, 128
)
location_2025 <- tribble(
  ~county,     ~adults, ~children, ~total,
  "Fauquier",  53, 43, 96,  "Culpeper", 67, 9, 76,  "Madison", 15, 4, 19
)
# Optional compact 2025 region demographics for Ch5 callouts (gender/race/shelter/age/veterans/
# disability/reason) as a tidy long frame: category, subcategory, count, base_of. (cheap; include.)
demographics_2025 <- tribble(~category, ~subcategory, ~count, ~base, ... )

write_rds(list(trend = trend, location_2025 = location_2025,
               demographics_2025 = demographics_2025,
               meta = list(region = c("Culpeper","Fauquier","Madison","Orange","Rappahannock"),
                           count_date = as.Date("2025-01-22"),
                           source = "FHN 2025 Point-in-Time Count Summary (PDF)",
                           caveat = "Region-wide trend; only 2025 has a Fauquier split")),
          "data/pit.rds")

## Validate
out <- read_rds("data/pit.rds")
stopifnot(nrow(out$trend) == 8,
          with(out$trend[out$trend$year==2025,], adults + children == individuals),  # 135+56=191
          out$location_2025$total[out$location_2025$county=="Fauquier"] == 96)
```

**Gotcha:** hardcoded — a future PIT vintage means re-reading the PDF and editing the tribble. The
"Fauquier CoC trend" that Ch5 shows is really the **FHN 5-county region** trend — state this in the
frame's `meta$caveat` and (Session 10) in the chart caption.

---

## Script 4 — `r/vdoe.R` → `data/vdoe.rds`

Five xlsx with **drifting layouts**. Per-file config, filter to Fauquier (LEA 030), coerce `<`/`*`
→ `NA`.

```r
# vdoe.R ----
# What:   VDOE (Project HOPE-VA) McKinney-Vento homeless student counts — Fauquier County Public Schools
# Source: data/raw/vdoe/*.xlsx (one file per school year; layouts differ)
# Output: data/vdoe.rds

files <- tribble(
  ~school_year, ~path,                                       ~sheet,                  ~skip,
  "2020-21", "data/raw/vdoe/2020-21-child-count.xlsx",       "Total VA Child Counts", 1L,   # title row 0
  "2021-22", "data/raw/vdoe/LEA-totals-2021-22.xlsx",        1,                       0L,
  "2022-23", "data/raw/vdoe/LEA-totals-to-post-2022-23.xlsx",1,                       0L,
  "2023-24", "data/raw/vdoe/LEA-totals-to-post-2023-24.xlsx",1,                       0L,
  "2024-25", "data/raw/vdoe/2024-25-LEA-MV-Counts-for-posting.xlsx", 1,               0L
)
read_vdoe <- function(school_year, path, sheet, skip) {
  raw <- read_excel(path, sheet = sheet, skip = skip) |> clean_names()
  # division-name col = col 2; count col = col 3 (position-stable across the varying headers)
  raw |>
    rename(division = 2, count_raw = 3) |>
    filter(str_detect(division, regex("fauquier county public schools", ignore_case = TRUE))) |>
    transmute(school_year, division,
              students = suppressWarnings(parse_number(as.character(count_raw))))  # "<"/"*" -> NA
}
fauquier <- pmap_dfr(files, read_vdoe)

# Optional: statewide long frame (all divisions) for context — same reader minus the Fauquier filter.

write_rds(list(fauquier = fauquier,
               source = "VDOE Project HOPE-Virginia, McKinney-Vento LEA counts"),
          "data/vdoe.rds")

## Validate — exact expected series
out <- read_rds("data/vdoe.rds")
expected <- c(`2020-21`=191, `2021-22`=135, `2022-23`=101, `2023-24`=100, `2024-25`=92)
got <- setNames(out$fauquier$students, out$fauquier$school_year)
stopifnot(nrow(out$fauquier) == 5, all(got[names(expected)] == expected))
message("VDOE Fauquier: ", paste(names(got), got, collapse = " | "))
```

**Gotchas:** (1) 2020-21 is a different report ("child count", 3 sheets, a **title row 0** → `skip=1`;
use sheet **"Total VA Child Counts"**). (2) Column **headers vary** (`LEA Number`/`LEA #`/`Division #`;
count header changes yearly) — rename **by position** (cols 2 & 3), not by name. (3) `<` and `*` mark
suppressed small counts — `parse_number` yields `NA` (Fauquier never suppressed, so the `==` check is
safe). (4) LEA `030` has a leading zero (character). (5) `**`/`*` after some division names are
footnote markers — the `str_detect` on "fauquier county public schools" ignores them.

---

## Execution order

| Step | Script | Depends on | Notes |
|---|---|---|---|
| 1 | `r/wcoop.R` | WC xlsx + `acs_demographics`/`bps`/`chas`/`gaps`/`hud_ami` `.rds` | biggest; core projections + needs-allocation |
| 2 | `r/acs_specialpop.R` | Census API | independent; ~3–6 min (4 tables × 3 geos) |
| 3 | `r/pit.R` | PDF (transcribed) | independent; instant |
| 4 | `r/vdoe.R` | 5 xlsx | independent; ~15s |

Steps 2–4 are independent of Step 1 and each other. Run `wcoop.R` first (most complex; surfaces any
missing-upstream issues early).

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/wcoop.R
Rscript r/acs_specialpop.R
Rscript r/pit.R
Rscript r/vdoe.R
```

---

## Known gotchas (consolidated)

1. **WC header layout** — 2 title + 2 header rows; `skip = 4`; assign column names by position.
   Values are floats → `round()`.
2. **AgeSex section order = Total, Female, Male** (Female before Male). Total section = cols 4–21
   (1-based); 65+ = last 5 bands, 75+ = last 3.
3. **Household-method fork** — two ratios, materially different (+6,666/264 vs ≈+7,600/305). Store
   both; avg-HH-size reconciles GP; headline chosen at Session 11.
4. **Bealeton has no WC projection** (CDP); WC towns = Warrenton only.
5. **Needs-allocation join** onto `gaps.rds` — verify key column names (`band`).
6. **B11007 reuse** — do not re-pull.
7. **S1702 subject table** — `load_variables("acs5/subject")`; `C0X` column dimension; verify the
   label split (no in-repo precedent).
8. **PIT hardcoded from PDF** — region ≠ Fauquier; only 2025 has a Fauquier split; counts not rates.
9. **VDOE layout drift** — position-based rename; 2020-21 special sheet/skip; `<`/`*` → NA.
10. **`case_when()` over `case_match()`**; `cache_table` warning harmless.
11. **No new caption helpers this session** — flag `wc_cap`/`pit_cap`/`vdoe_cap` for Sessions 10–11.
12. **`data/` is gitignored** — commit the `r/` scripts + plan + PLAN.md, not the `.rds`.

---

## End-of-session hygiene

### PLAN.md §9 checkboxes to tick
```
- [x] `r/wcoop.R`: projections; constant-headship household conversion; 3% vacancy production model vs permits
- [x] `r/acs_specialpop.R`: B18101, B11003, S1702, B11007, B25007
- [x] `r/pit.R`, `r/vdoe.R`: small tidy series with source notes
- [x] Validation: household growth vs GP +7,737; production need vs GP 307/yr (explain variances in §11)
```
(Also flip the §9 status row: `| 7 | Projections & special pops | complete 2026-07-XX | Sonnet/Opus |`.)
Note in the checkbox area that **B11007 was reused** (not re-pulled) and the **needs-allocation table**
was built in `wcoop.R` (extends the literal checkbox per Jonathan's confirmation).

### PLAN.md §11 log entry (fill placeholders)
```
- **2026-07-XX** — Session 7 (Projections & special-populations data) complete (<model>). Scripts:
  `r/wcoop.R`, `r/acs_specialpop.R`, `r/pit.R`, `r/vdoe.R`. **WC:** Fauquier pop 2050 = 93,171;
  Warrenton town 2050 = 12,841 (Bealeton absent — CDP). **Household method:** stored BOTH —
  avg-HH-size (WC pop ÷ B25010 ≈X.XX) → +X,XXX by 2050 (~XXX units/yr, reconciles GP +7,737/307);
  total-pop headship (0.3583) → +6,666 (~264/yr, conservative). Headline deferred to Session 11.
  Production pace (BPS 2020-25) = 266/yr. **Needs-allocation** built in wcoop.R (tenure×AMI × growth).
  **acs_specialpop:** B18101/B11003/S1702/B25007 (B11007 reused from acs_demographics, not re-pulled);
  S1702 subject-table label split = <notes>. **PIT:** transcribed FHN 2025 PDF — region (5 counties)
  trend 2018–2025; 2025 Fauquier split 96/191; caveats logged. **VDOE:** Fauquier 191→135→101→100→92.
  **Deviations:** needs-allocation extends §9 checkbox (Jonathan-approved); <others>. **Open questions:**
  household-projection headline (avg-size vs headship) to be finalized in Session 11 + data-notes.
```

### Commit command
```bash
git add r/wcoop.R r/acs_specialpop.R r/pit.R r/vdoe.R plans/session-07-projections-populations.md PLAN.md
git commit -m "Session 7: projections & special-populations data (Weldon Cooper, ACS special pops, PIT, VDOE)"
```
(No Claude/Anthropic co-author lines — PLAN §3 / CLAUDE.md.)

### Save the plan file to the repo
After approval, save this document as
`R:\hda\fhfh\plans\session-07-projections-populations.md` (matching the `session-0N-<topic>.md`
convention).

---

## Verification (Definition of Done)

- [x] `r/wcoop.R`, `r/acs_specialpop.R`, `r/pit.R`, `r/vdoe.R` run clean end-to-end via `Rscript`.
- [x] `data/wcoop.rds`, `data/acs_specialpop.rds`, `data/pit.rds`, `data/vdoe.rds` written; each
      validation block passes (variances documented in §11).
- [x] `wcoop$households` stores **both** growth methods. **NOTE:** avg-HH-size 2050 growth is +6,795
      (real B25010 = 2.78, not the plan's assumed ~2.70), so it does **not** reconcile GP's +7,737 —
      both methods land ~264-269/yr, below GP. Divergence documented; headline deferred to Session 11.
- [x] `wcoop$production` per-year need (avg-size, to 2050 = ~269/yr) prints alongside GP ~307 and BPS pace 266.
- [x] `wcoop$needs_allocation` sums (=6,795) to total projected growth; bands align with `hud_ami`/`gaps`
      via a tenure-aware join (owner→ownership_gap ami-scale, renter→rental_gap collapsed-band scale).
- [x] Warrenton town projection present (2050 = 12,841); Bealeton absence documented (CDP).
- [x] `acs_specialpop` has B18101/B11003/S1702/B25007 (+`vars`); **B11007 not duplicated**; place-level
      `cv` computed (guarded); S1702 subject pull verified (depth-7 label split, `C0X` in `variable`).
- [x] `pit$trend` = 8 region-wide years; 2025 Fauquier split = 96/191; region caveat recorded.
- [x] `vdoe$fauquier` = 191/135/101/100/92 for 2020-21…2024-25.
- [x] §9 checkboxes ticked, §9 status row + §11 log updated, committed.
