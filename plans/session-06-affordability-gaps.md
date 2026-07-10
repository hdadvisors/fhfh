# Session 6 (Affordability & Gap Computations) — FHFH Housing Needs Assessment

Detailed execution plan for PLAN.md §9 **Session 6 — Affordability & gap computations**
(methodology-heavy — Opus). PLAN.md (repo root) remains the source of truth; this document is the
step-by-step build reference for the session.

## Context

Sessions 1–5 are complete and committed. Session 6 is a **data/computation session**: it writes
`.rds` files and updates one function library. It does **not** touch any `.qmd` chapter — `gaps.qmd`
is built later in Session 10 and `data-notes.qmd` in Session 11 (PLAN.md §9). The data-flow rule
holds: `r/` scripts → `data/*.rds` → chapters `read_rds()` only.

Status as of planning (2026-07-09):

| Check | Status |
|---|---|
| Sessions 2–5 outputs (18 `.rds` in `data/`) | ✅ present |
| `data/raw/hud/hud_fmr_fy2026.xlsx`, `hud_safmr_fy2026.xlsx` | ✅ present |
| **HUD FY2026 Income Limits** file | ❌ **NOT present** — resolved in Step 0 (script-fetch) |
| `r/affordcalc.R` (function library) | ✅ present — needs param refresh (§8) |
| faar sources `R:\hda\faar\r\hud_ami.R`, `chas.R` | ✅ present (copy-adapt) |
| `CENSUS_API_KEY`, `FRED_API_KEY` in `C:\Users\JTK\Documents\.Renviron` | ✅ |
| GP study PDF in `background/` | ✅ present (tax/insurance + gap-direction targets) |
| `data/gp_appendix.rds` | ✅ present (sales/rent reference series) |

### Decisions locked for this session (2026-07-09)

1. **HUD FY2026 Income Limits → script-fetch.** `r/hud_ami.R` downloads the Section 8 Income Limits
   xlsx directly from huduser.gov (pre-approved PLAN §3 line 100, §5 #18; no API token). Saves to
   `data/raw/hud/hud_il_fy2026.xlsx` then reads it. **Manual-drop fallback** if the GET fails or the
   layout differs (`stop()` with a clear instruction).
2. **Ownership affordability assumptions → mirror the GP study.** Extract GP's mortgage/tax/insurance
   assumptions from the GP PDF methodology (pp. ~54–70) so FHFH's ownership gap reconciles with GP
   Figs 27–28. Fall back to current published Fauquier figures if GP is silent. Document rate + pull
   date + tax rate + insurance for Session 11's data-notes.
3. **CHAS vintage → 2018–2022 (locked).** Reconciles with the GP study. `r/chas.R` targets
   `2018thru2022`. Implementer notes in the §11 log whether 2019–2023 has since released (future-
   refresh flag only — do **not** upgrade this session).
4. **DC-metro 80% cap (critical AMI nuance).** Fauquier is in the *Washington-Arlington-Alexandria,
   DC-VA-MD HUD Metro FMR Area* (`METRO47900M47900`), where HUD **caps** the published 80% limit to
   the US median. Per §8: use HUD-**published** 30/50/80% limits as-is (capped values are what
   programs use), and use `calc_ami()` fed the area's **published MFI** only to extend to 100/120%.
   This produces a real "kink" (80→100 gap wider than 50→80) — expected; document it.
5. **Representative household size for band-affordability = 3-person** (per §8(d) example), unless the
   GP methodology used a different size — then mirror GP and state it.

### Out of scope (this session)

No chapter/`.qmd` edits (gaps.qmd = Session 10; data-notes.qmd = Session 11). **No PUMS** (locked out
— PLAN §8, §9; do not port faar's `gap_sandbox.R`/`pums_gap.R`). No production-target model (Session
7). No B19001-based AMI banding where CHAS serves (fallback only, clearly caveated). Scripts write
`.rds` only; assumptions destined for data-notes are recorded in `gaps.rds$assumptions` + the §11 log.

---

## Shell conventions

Every R invocation from the project root `R:\hda\fhfh` via **Bash**:

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/<name>.R
```

Per PLAN.md §3 and CLAUDE.md Windows R rule: **never run R inline.** Ad-hoc inspections (column
headers, dictionary sheet names, row counts) go to the session scratchpad, not the repo. Scripts are
idempotent — downloaded raw files are cached under `data/raw/` and skipped if present.

**dplyr note (carried from Sessions 2–5):** `recode_values(.unmatched = "error")` per PLAN §3 is
**not available in installed dplyr 1.2.1** — use `case_when()`/`case_match()` as prior sessions did.

---

## Step 0 — Prerequisite gate

Resolve before writing script bodies.

1. **HUD FY2026 Income Limits (script-fetch).** `r/hud_ami.R` §2 attempts the download (see Script 1).
   Confirm the FY2026 Section 8 IL file exists on huduser.gov and note the exact URL + sheet name at
   build (HUD occasionally renames; `il2026` dataset page lists files). If the GET fails, `stop()`
   with: *"Manual fallback: download the FY2026 Section 8 Income Limits xlsx from
   huduser.gov/portal/datasets/il.html into data/raw/hud/hud_il_fy2026.xlsx and re-run."*
2. **CHAS vintage recheck.** Confirm `2018thru2022` CHAS is still the current anchor and note if
   2019–2023 has released (log only — stay on 2018–2022 for GP reconciliation).
3. **GP assumptions extraction.** Read the GP study PDF methodology (`background/greater-piedmont-…
   march-20262.pdf`, ~pp. 54–70) and record the mortgage rate basis, down-payment %, RE tax rate,
   insurance figure, and representative household size GP used. These feed `affordcalc.R` + `gaps.R`.
   Fall back to current published Fauquier figures where GP is silent; document either way.

---

## Script anatomy (all scripts)

```r
# <name>.R ----
# What:   <one-line description>
# Source: <data source(s)>
# Output: data/<name>.rds   (function library for affordcalc.R)

## 1. Setup ----
library(tidyverse)
library(readxl)     # as needed
library(janitor)    # as needed
library(httr)       # r/hud_ami.R + r/chas.R downloads (faar pattern)

# (no API key needed for HUD/CHAS; gaps.R needs none — reads local .rds)
dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Geography constants (mirror _common.R — defined here so scripts run standalone)
fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
virginia   <- "51"

## N. <section> ----
# ...

## N+1. Write output ----
write_rds(list(...), "data/<name>.rds")
message("Wrote data/<name>.rds")

## N+2. Validate ----
out <- read_rds("data/<name>.rds")
stopifnot(...)                       # ranges anchored to GP-study benchmarks
message("<name>.R validation passed.")
```

Every script writes a **named `list()` of tibbles** to one `.rds`, then re-reads and validates with
`stopifnot()` + `message()` echoing the GP benchmark. Run order: `hud_ami.R` → `chas.R` →
`affordcalc.R` (edit) → `gaps.R`.

---

## Script 1 — `r/hud_ami.R` → `data/hud_ami.rds`

Copy-adapt from `R:\hda\faar\r\hud_ami.R`. **Key differences from faar:** read the FY2026 file (not
FY24); **drop the PUMS join** (faar lines 151–154); reduce scope to Fauquier's single HUD area; read
the MFI from the file rather than hardcoding. Reuse faar's `calc_ami()` (lines 76–106) **verbatim** —
it is proven (VLIL = MFI×0.5; family-size factors `c(.70,.80,.90,1,1.08,1.16,1.24,1.32)`; rounds to
$50).

Deliverable: the AMI explainer table — FY2026 limits by band (30/50/80/100/120%) × household size
(1–8), for Fauquier's HUD area (Ch4 Fig 1).

```r
# hud_ami.R ----
# What:   FY2026 HUD Income Limits for Fauquier's HUD area, extended to 100/120% AMI
# Source: HUD FY2026 Section 8 Income Limits (huduser.gov); calc_ami() extension (faar)
# Output: data/hud_ami.rds

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
library(httr)

dir.create("data/raw/hud", showWarnings = FALSE, recursive = TRUE)

fauquier      <- "51061"
# Fauquier's HUD area — confirmed Session 5 (PLAN §9). VERIFY against the IL file at build.
hud_area_name <- "Washington-Arlington-Alexandria, DC-VA-MD HUD Metro FMR Area"

## 2. Acquire FY2026 Income Limits (script-fetch, manual fallback) ----
il_path <- "data/raw/hud/hud_il_fy2026.xlsx"
if (!file.exists(il_path)) {
  # VERIFY exact URL + filename at build via huduser.gov/portal/datasets/il.html (il2026 dataset)
  il_url <- "https://www.huduser.gov/portal/datasets/il/il2026/Section8-FY26.xlsx"
  message("Fetching HUD FY2026 Income Limits from ", il_url)
  resp <- tryCatch(
    GET(il_url, write_disk(il_path, overwrite = TRUE),
        user_agent("Mozilla/5.0 (FHFH housing study)")),
    error = function(e) e
  )
  if (inherits(resp, "error") || !file.exists(il_path) || file.size(il_path) < 10000) {
    stop("HUD IL fetch failed. Manual fallback: download the FY2026 Section 8 Income Limits xlsx ",
         "from huduser.gov/portal/datasets/il.html into ", il_path, " and re-run.")
  }
}

## 3. Read + verify Fauquier's HUD area ----
# VERIFY sheet name at build (faar used "Section8-FY24"; expect "Section8-FY26" or similar)
il_raw <- read_excel(il_path, sheet = 1) |> clean_names()   # sheet = 1 or named sheet — confirm

# IL files key rows by fips2010 (e.g. "5106199999") + hud_area_name. Filter to Fauquier county.
fauquier_il <- il_raw |>
  filter(str_starts(as.character(fips2010), fauquier))       # VERIFY col name (fips2010 / fips)

stopifnot(nrow(fauquier_il) == 1)                            # exactly one HUD area row for Fauquier
message("Fauquier HUD area (from file): ", fauquier_il$hud_area_name)
stopifnot(str_detect(fauquier_il$hud_area_name, "Washington-Arlington-Alexandria"))

## 4. Published limits: 30 / 50 / 80% by household size ----
# HUD cols (post clean_names): eli_1..eli_8 (=30% ELI), l50_1..l50_8, l80_1..l80_8, median20xx.
# VERIFY exact col stems at build (HUD ELI floors at poverty guideline; treat ELI as the 30% band
# per faar + GP convention — document the ELI nuance in data-notes).
published <- fauquier_il |>
  select(matches("^(eli|l50|l80)_[1-8]$")) |>
  pivot_longer(everything(),
               names_to = c("level", "hh_size"), names_pattern = "(.*)_([1-8])",
               values_to = "income") |>
  mutate(level = case_match(level, "eli" ~ "ami30", "l50" ~ "ami50", "l80" ~ "ami80"),
         hh_size = paste0(hh_size, "-person"))

# Area MFI (published) — the calc_ami() input. VERIFY col name (median2026 / median).
mfi <- fauquier_il |> pull(matches("^median")) |> as.numeric()
message("Published area MFI: $", format(mfi, big.mark = ","))

## 5. calc_ami() — verbatim from faar (extend to 100/120% only) ----
calc_ami <- function(mfi, area_name, levels = c(30, 50, 80, 100, 120)) {
  vlil <- mfi * 0.5
  fsa  <- c(0.70, 0.80, 0.90, 1, 1.08, 1.16, 1.24, 1.32)
  ami_levels <- sapply(levels, function(level) {
    ami <- round(vlil * (level / 50) / 50) * 50
    round(ami * fsa / 50) * 50
  })
  ami <- tibble(area = area_name, hh_size = paste0(1:8, "-person"))
  for (i in seq_along(levels)) ami[[paste0("ami", levels[i])]] <- ami_levels[, i]
  ami |> pivot_longer(-(1:2), names_to = "level", values_to = "income")
}

extended <- calc_ami(mfi, hud_area_name, levels = c(100, 120)) |> select(hh_size, level, income)

## 6. Combine published (30/50/80) + extended (100/120) ----
band_order <- c("ami30", "ami50", "ami80", "ami100", "ami120")
ami <- bind_rows(published, extended) |>
  mutate(level = factor(level, levels = band_order),
         hh_size = factor(hh_size, levels = paste0(1:8, "-person"))) |>
  arrange(hh_size, level)

## 7. Write output ----
write_rds(
  list(ami       = ami,                 # long: hh_size × level × income
       mfi        = mfi,
       area_name  = hud_area_name,
       area_fips  = fauquier,
       source     = "HUD FY2026 Section 8 Income Limits; 100/120% via calc_ami(MFI)",
       cap_note   = "DC-metro 80% limit is HUD-capped to US median; 100/120% derived from published MFI"),
  "data/hud_ami.rds"
)
message("Wrote data/hud_ami.rds")

## 8. Validate ----
out <- read_rds("data/hud_ami.rds")
ami4 <- out$ami |> filter(hh_size == "4-person")
stopifnot(
  nrow(out$ami) == 40,                                        # 8 sizes × 5 bands
  all(diff(as.numeric(ami4$level[order(ami4$level)])) >= 0),  # bands ordered
  with(ami4, income[level == "ami100"]) >= with(ami4, income[level == "ami80"]),   # monotonic
  abs(with(ami4, income[level == "ami100"]) - out$mfi) / out$mfi < 0.02             # 100% ≈ MFI
)
# Internal check: calc_ami(mfi, 50) should reproduce published 50% (VLIL) within rounding
message("hud_ami.R validation passed.")
message("  MFI: $", format(out$mfi, big.mark = ","),
        " | 4-person 80% (capped): $", format(with(ami4, income[level == "ami80"]), big.mark = ","))
```

**Gotchas:** confirm sheet name + column stems against the FY2026 file (HUD renames between years);
ELI ≠ exactly 30% (poverty floor) — document; the 80% capped value is intentional (do not "fix").

---

## Script 2 — `r/chas.R` → `data/chas.rds`

The biggest new build. faar's `chas.R` only does **sumlevel 050** and tables **7/9/18A–C** — it does
**not** cover T8, T14, T15, or **sumlevel 160**. Generalize faar's download/parse loop (lines 15–80)
into a reusable reader, then run it over the required tables × two sumlevels.

**Tables (2018–2022):** T7 (income × tenure × HH type incl. elderly), T8 (income × tenure × cost
burden), T14A/T14B (rental-unit affordability), T15A/T15B/T15C (renter income × unit affordability —
the "affordable & available" core), T18A/T18B/T18C (rent/value distributions). **VERIFY the exact
letter-variant set** against the 2018–2022 data dictionary at build (sheet list in the dictionary
xlsx). **Sumlevels:** `050` (county → Fauquier `51061`) + `160` (place → Warrenton `5183136`,
Bealeton `5105336`).

```r
# chas.R ----
# What:   HUD CHAS 2018-2022 tables T7/T8/T14/T15/T18 at county (050) + place (160)
# Tables: 7, 8, 14A, 14B, 15A, 15B, 15C, 18A, 18B, 18C   (VERIFY variants vs dictionary)
# Source: huduser.gov CHAS 2018thru2022 (050 + 160 csv zips)
# Output: data/chas.rds

## 1. Setup ----
library(tidyverse)
library(glue)
library(httr)
library(janitor)
library(readxl)

fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
chas_year  <- 2022                    # 2018thru2022 (locked — see Step 0)
sumlevs    <- c("050", "160")
tables     <- c("7", "8", "14A", "14B", "15A", "15B", "15C", "18A", "18B", "18C")  # VERIFY set

dir.create("data/raw/chas", showWarnings = FALSE, recursive = TRUE)

## 2. Download + unzip each sumlevel (cached) ----
walk(sumlevs, function(sl) {
  url  <- glue("https://www.huduser.gov/PORTAL/datasets/cp/{chas_year - 4}thru{chas_year}-{sl}-csv.zip")
  zip  <- file.path("data/raw/chas", basename(url))
  if (!file.exists(zip)) {
    message("Downloading CHAS ", sl, " ...")
    GET(url, write_disk(zip, overwrite = TRUE),
        user_agent("Mozilla/5.0 (FHFH housing study)"))
  }
  exdir <- file.path("data/raw/chas", sl)
  if (!dir.exists(exdir)) unzip(zip, exdir = exdir)
})

## 3. Generalized reader (adapts faar chas.R lines 30-80) ----
# Reads Table{tbl}.csv at sumlevel sl, joins its dictionary sheet, cleans, filters to study geos.
read_chas <- function(tbl, sl) {
  base   <- file.path("data/raw/chas", sl)
  file   <- list.files(base, pattern = glue("Table{tbl}\\.csv$"), recursive = TRUE, full.names = TRUE)[1]
  dict_f <- list.files(base, pattern = "dictionary", recursive = TRUE, full.names = TRUE)[1]
  dict   <- read_excel(dict_f, sheet = glue("Table {tbl}"))       # VERIFY sheet naming at build

  geo_ids <- if (sl == "050") fauquier else unname(towns)

  read_csv(file, col_types = cols()) |>
    clean_names() |>
    mutate(fips = if (sl == "050") str_sub(geoid, 8, 12) else str_sub(geoid, 8)) |>
    filter(fips %in% geo_ids | str_ends(geoid, paste(geo_ids, collapse = "|"))) |>
    pivot_longer(starts_with("t"), names_to = "code", values_to = "value") |>
    mutate(id   = str_extract(code, "\\d+$"),
           type = str_extract(code, "est|moe")) |>
    select(-code) |>
    pivot_wider(names_from = type, values_from = value) |>
    rename(estimate = est, moe = moe) |>
    mutate(code = glue("T{tbl}_est{id}")) |>
    left_join(dict, by = c("code" = "Column Name")) |>       # VERIFY dict key col name
    clean_names() |>
    filter(line_type == "Detail") |>
    mutate(sumlev = sl, geo_type = if (sl == "050") "county" else "place")
}

## 4. Shared dimension recodes (faar T7 strings — proven for this dictionary) ----
recode_income <- function(x) case_when(
  str_detect(x, "less than or equal to 30%")                          ~ "≤30% AMI",
  str_detect(x, "greater than 30% but less than or equal to 50%")     ~ "30-50% AMI",
  str_detect(x, "greater than 50% but less than or equal to 80%")     ~ "50-80% AMI",
  str_detect(x, "greater than 80% but less than or equal to 100%")    ~ "80-100% AMI",
  str_detect(x, "greater than 100%")                                  ~ ">100% AMI"
)
recode_burden <- function(x) case_when(
  str_detect(x, "less than or equal to 30%")                          ~ "Not cost-burdened",
  str_detect(x, "greater than 30% but less than or equal to 50%")     ~ "Cost-burdened",
  str_detect(x, "greater than 50%")                                   ~ "Severely cost-burdened",
  str_detect(x, "no.?negative income|not computed")                  ~ "No or negative income"
)
recode_tenure <- function(x) case_when(
  str_detect(x, "Owner")  ~ "Homeowner",
  str_detect(x, "Renter") ~ "Renter"
)

## 5. Read all tables × sumlevels ----
# grid of (table, sumlev); map, then split into a named list keyed by lower-cased table
grid <- tidyr::expand_grid(tbl = tables, sl = sumlevs)
chas_raw <- purrr::pmap(grid, \(tbl, sl) read_chas(tbl, sl) |> mutate(table = tbl)) |>
  list_rbind()

# Apply recodes where the dimension columns exist (T14/T15/T18 have their own affordability fields —
# VERIFY their dictionary wording at build and add recode_affordability() as needed).
chas_raw <- chas_raw |>
  mutate(across(any_of("tenure"),          recode_tenure),
         across(any_of("household_income"), recode_income),
         across(any_of("cost_burden"),      recode_burden))

chas <- split(chas_raw, tolower(chas_raw$table))   # -> $`7`, $`8`, $`14a`, ... (or rename cleanly)
names(chas) <- paste0("t", names(chas))

## 6. Write output ----
write_rds(chas, "data/chas.rds")
message("Wrote data/chas.rds (", length(chas), " tables)")

## 7. Validate — burden rates vs GP benchmark (the key check) ----
out <- read_rds("data/chas.rds")

# Fauquier county cost-burden share by tenure from T8 (exclude No/neg income)
burden <- out$t8 |>
  filter(geo_type == "county", cost_burden != "No or negative income", !is.na(tenure)) |>
  summarise(burdened = sum(estimate[cost_burden != "Not cost-burdened"]),
            total    = sum(estimate), .by = tenure) |>
  mutate(pct = burdened / total * 100)

renter_pct <- burden$pct[burden$tenure == "Renter"]
owner_pct  <- burden$pct[burden$tenure == "Homeowner"]
message("  Renter burden: ", round(renter_pct, 1), "% (GP ~40.2%) | ",
        "Owner burden: ",  round(owner_pct, 1), "% (GP ~21.5%)")

stopifnot(
  abs(renter_pct - 40.2) < 5,          # tolerance for vintage; GP benchmark PLAN §3
  abs(owner_pct  - 21.5) < 5,
  "t7" %in% names(out), "t8" %in% names(out), "t14a" %in% names(out), "t15a" %in% names(out)
)
# Warn (don't fail) if Bealeton absent at place level — small CDPs may be suppressed in CHAS 160
if (!any(str_ends(out$t8$geoid, towns["bealeton"]))) warning("Bealeton absent in CHAS 160 — note in log")
message("chas.R validation passed.")
```

**Gotchas:** (1) CHAS 160 zip is large (all US places) — cache it. (2) **Bealeton (CDP) may be absent
or high-MOE** at place level — warn, don't fail; note in §11 and caveat downstream. (3) Place-level
estimates carry high MOEs → present with reliability caveats (§3). (4) T14/T15/T18 affordability
fields use their own dictionary wording (RHUD30/50/80 etc.) — build `recode_affordability()` from
their sheets; don't assume the T7 strings. (5) Confirm the `geoid`→`fips` slicing for 160 (place
GEOIDs like `16000USxxxxxxx`).

---

## Script 3 — `r/affordcalc.R` (edit — parameter refresh)

Small, surgical. `affordcalc.R` stays a pure function library (no side effects, no file reads). Update
only the two flagged defaults (lines 13–14) to Session-6 values with dated comments; keep all function
signatures unchanged. Authoritative values flow from `gaps.R` at call time (below); the defaults are
sane fallbacks.

- `.int_rate_default` ← current PMMS 30-yr from `data/fred.rds` (**as a decimal** — fred stores
  percent, e.g. `6.72`, so divide by 100). Comment with the observation date.
- `.tax_ins_monthly` ← GP-mirrored monthly (RE tax on a representative Fauquier value ÷ 12 + monthly
  insurance), per Step 0 extraction. Comment with the derivation + source.

Edit shape (values filled at build from Step 0 + `fred.rds`):

```r
## Mortgage assumption defaults (PLAN.md §8). Updated Session 6 (2026-07-xx).
## Authoritative rate/tax/ins are passed explicitly from r/gaps.R; these are library fallbacks.
.int_rate_default  <- 0.0XXX  # 30-yr PMMS as of <YYYY-MM> (data/fred.rds) — was 0.0694 (2024-05-23)
.tax_ins_monthly   <- XXX     # Fauquier RE tax (<rate> on $<rep value>)/12 + $<ins>/mo ins — GP-mirrored
```

Do **not** change `calc_affordable_rent`, `calc_affordable_sales`, or `calc_income_needed` logic. Note
that `calc_income_needed` defaults `down_pct = 0.05`; **`gaps.R` overrides to `0.10`** to mirror GP.

---

## Script 4 — `r/gaps.R` → `data/gaps.rds`

The synthesis. `source("r/affordcalc.R")` and read the inputs, then compute the four §8 deliverables +
an income-needed summary + an assumptions record. **No PUMS.** All affordability calls pass explicit
`int_rate` (from fred), `down_pct = 0.10`, and `tax_ins_monthly` (GP-mirrored).

```r
# gaps.R ----
# What:   Affordability by AMI band, rental gap, ownership gap, wages-vs-costs matrix
# Source: data/{hud_ami,chas,mls,qcew,fred,acs_costs}.rds + r/affordcalc.R (per PLAN §8)
# Output: data/gaps.rds

## 1. Setup ----
library(tidyverse)
source("r/affordcalc.R")

hud_ami   <- read_rds("data/hud_ami.rds")
chas      <- read_rds("data/chas.rds")
mls       <- read_rds("data/mls.rds")
qcew      <- read_rds("data/qcew.rds")
fred      <- read_rds("data/fred.rds")
acs_costs <- read_rds("data/acs_costs.rds")

rep_size  <- "3-person"                 # §8(d) — state the size (mirror GP if it differs)
down_pct  <- 0.10                        # mirror GP
int_rate  <- tail(fred$pmms_monthly$mortgage_rate_30yr, 1) / 100   # DECIMAL (fred is percent)
rate_date <- tail(fred$pmms_monthly$date, 1)
tax_ins   <- .tax_ins_monthly            # GP-mirrored (set in affordcalc.R Step 0)

## 2. "What each band affords" (Ch4 Fig 2) ----
# Band income ceilings at representative HH size → max rent (30%) + max price (10% down).
afford_by_band <- hud_ami$ami |>
  filter(hh_size == rep_size) |>
  transmute(band = level, income = income) |>
  calc_affordable_rent("income") |>
  calc_affordable_sales("income", dwn_opts = 0.10, int_rate = int_rate, tax_ins_monthly = tax_ins) |>
  rename(max_rent = affordable_rent, max_price = affordable_sales_0.1)

## 3. Rental gap — CHAS T14/T15 "affordable & available" (Ch4 Fig 6, GP Fig 27) ----
# Supply of affordable rental units by rent band (T14A occupied + T14B vacant-for-rent),
# adjusted for availability (T15: affordable units occupied by higher-income HHs are unavailable),
# vs renter households by income band (T7/T15 margin). Gap = available_affordable - renter_HHs.
# VERIFY T14/T15 affordability field wording at build; validate DIRECTION vs GP Fig 27 (deficit at
# lowest bands). See faar chas.R:196-237 for the match/gapcode pattern (fallback only — PLAN mandates
# T14/T15, not T18C).
rental_gap <- {
  # ... build per band: units_affordable, units_available, renter_hh, surplus_deficit ...
  # (structure confirmed against dictionary at build)
}

## 4. Ownership gap — MLS active listings × affordability (Ch4 Fig 7, GP Fig 28) ----
# Active listings priced at/below each band's max_price vs households in band (snapshot).
active <- mls$active
ownership_gap <- afford_by_band |>
  mutate(listings_affordable = map_int(max_price, \(p) sum(active$list_price <= p, na.rm = TRUE))) |>
  # households in/below band from CHAS T7/T8 (owner or all — match GP Fig 28 denominator)
  left_join(hh_by_band, by = "band") |>
  mutate(surplus_deficit = listings_affordable - households)
# Caveat: listings (flow snapshot) vs households (stock) — mirror GP's framing; state in caption.

## 5. Wages-vs-costs matrix (Ch4 Fig 8 — signature chart) ----
# Sector avg wage (QCEW) as 1- and 2-earner income vs income-needed-to-rent / -to-buy thresholds.
med_rent  <- acs_costs$B25064 |> filter(GEOID == "51061") |> pull(estimate)   # VERIFY element/col
med_price <- mls$annual |> slice_max(year, n = 1) |> pull(median_price)

thresholds <- tibble(med_price = med_price, med_rent = med_rent) |>
  calc_income_needed("med_price", "med_rent", int_rate = int_rate,
                     down_pct = down_pct, tax_ins_monthly = tax_ins)   # -> renter_income, buyer_income

wages_costs <- qcew$sector |>
  slice_max(year, n = 1) |>                                # latest year
  transmute(sector, one_earner = avg_annual_pay, two_earner = avg_annual_pay * 2) |>
  mutate(income_needed_rent = thresholds$renter_income,
         income_needed_buy  = thresholds$buyer_income)

## 6. Income-needed summary (narrative/callouts; fact-sheet targets ~$98k rent / ~$183k buy) ----
income_needed <- thresholds |> select(med_rent, med_price, renter_income, buyer_income)

## 7. Assumptions record (for Session 11 data-notes) ----
assumptions <- tibble(
  mortgage_rate = int_rate, rate_pull_date = rate_date, down_payment = down_pct,
  tax_ins_monthly = tax_ins, representative_hh_size = rep_size,
  source = "PMMS via fred.rds; RE tax/insurance mirror GP study methodology"
)

## 8. Write output ----
write_rds(
  list(afford_by_band = afford_by_band, rental_gap = rental_gap,
       ownership_gap = ownership_gap, wages_costs = wages_costs,
       income_needed = income_needed, assumptions = assumptions),
  "data/gaps.rds"
)
message("Wrote data/gaps.rds")

## 9. Validate ----
out <- read_rds("data/gaps.rds")
message("  Income needed — rent: $", format(round(out$income_needed$renter_income), big.mark = ","),
        " (fact-sheet ~$98k) | buy: $", format(round(out$income_needed$buyer_income), big.mark = ","),
        " (fact-sheet ~$183k)")
stopifnot(
  abs(out$income_needed$renter_income - 98000)  / 98000  < 0.20,   # fact-sheet, updated data
  abs(out$income_needed$buyer_income  - 183000) / 183000 < 0.25,
  all(diff(out$afford_by_band$max_price) >= 0)                     # higher band → higher max price
  # + rental_gap deficit at ≤30% band; ownership_gap deficit at low bands (direction vs GP 27/28)
)
message("gaps.R validation passed.")
```

**Gotchas:** (1) **fred PMMS is in percentage points** — divide by 100 for `int_rate`. (2) Use
`down_pct = 0.10` everywhere (GP mirror), overriding `calc_income_needed`'s 0.05 default. (3)
`afford_by_band` uses the `affordable_sales_0.1` column name — confirm the `dwn_opts` value formatting
(`0.1` vs `0.10`). (4) The ~$98k/$183k targets are fact-sheet figures under GP-era data/rates; tune
the assumption set (rate/tax/ins/down) to GP so results reconcile, then widen tolerance for updated
inputs. (5) Rental gap is the hardest piece — budget time to decode T14/T15; validate direction, not
just magnitude.

---

## Execution order

| Step | Script | Depends on | Why this order |
|---|---|---|---|
| 0 | Step 0 gate | — | Resolve IL fetch, CHAS vintage, GP assumptions |
| 1 | `r/hud_ami.R` | HUD IL file | Defines AMI bands `gaps.R` keys on |
| 2 | `r/chas.R` | huduser.gov | Household/burden/unit cross-tabs; independent of Step 1 |
| 3 | `r/affordcalc.R` (edit) | `data/fred.rds`, GP assumptions | Refresh rate/tax/ins before `gaps.R` sources it |
| 4 | `r/gaps.R` | Steps 1–3 + `mls`/`qcew`/`acs_costs`/`fred` | Synthesis |

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/hud_ami.R
Rscript r/chas.R
# edit r/affordcalc.R (values from Step 0 + fred.rds), then:
Rscript r/gaps.R
```

**Expected runtime:** `hud_ami` ~20s (one xlsx); `chas` ~3–6 min (two large zips, first run only, then
cached); `gaps` ~15s. Steps 1 and 2 are independent and may run in either order.

---

## Known gotchas (consolidated)

1. **HUD IL file layout drift.** Verify sheet name + column stems (`eli_*`, `l50_*`, `l80_*`,
   `median*`, `fips2010`) against the FY2026 file; HUD renames between years.
2. **DC-metro 80% cap is intentional.** Published 80% is capped to US median; the 80→100 "kink" is
   real. Use published 30/50/80; `calc_ami()` for 100/120 from published MFI. Document; don't "fix."
3. **ELI ≠ exactly 30% AMI** (poverty floor / VLIL ceiling). Using ELI as the 30% band matches faar +
   GP — note the nuance in data-notes.
4. **CHAS T8/T14/T15 recodes are new.** Only the T7 income/tenure/burden strings are proven (faar).
   Build affordability recodes (RHUD30/50/80) from each table's dictionary sheet.
5. **Bealeton (CDP) may be absent/high-MOE in CHAS 160.** Warn, don't fail; caveat downstream.
6. **fred PMMS is percent, not decimal.** Divide by 100 before feeding `affordcalc`.
7. **Down payment = 10%** to mirror GP (override `calc_income_needed`'s 0.05 default).
8. **Rental gap direction, not just magnitude.** Validate against GP Fig 27 (deficit at ≤30%).
9. **`data/` is gitignored** — `.rds` outputs are local-only; commit the `r/` scripts + plan + PLAN.md.

---

## End-of-session hygiene

### PLAN.md §9 checkboxes to tick

```
- [x] `r/hud_ami.R`: adapt faar — read FY2026 limits, verify Fauquier's HUD area, extend to 100/120% via calc_ami() fed HUD's MFI
- [x] `r/chas.R`: download/clean T7, T8, T14, T15, T18 at 050 + 160
- [x] `r/gaps.R`: rental gap (T14/T15), ownership gap (listings × affordcalc), wages-vs-costs matrix, "what each band affords" — all per §8
- [x] Validation: CHAS burden rates vs ACS B25070/B25091 ballpark; gap direction sanity vs GP Figs 27–28
```
(Also flip the §9 status-table row: `| 6 | Affordability & gaps | complete <date> (Opus) | | |`.)

### PLAN.md §11 log entry (fill placeholders)

```
- **2026-07-XX** — Session 6 (Affordability & gap computations) complete (Opus 4.8). Scripts:
  `r/hud_ami.R`, `r/chas.R`, `r/gaps.R`; edited `r/affordcalc.R`. **HUD IL:** script-fetch from
  huduser.gov (URL: XXX); Fauquier HUD area verified = Washington-Arlington-Alexandria DC-VA-MD HMFA;
  FY2026 MFI $XXX. **DC 80% cap:** published 80% capped to US median; 100/120% via calc_ami(MFI).
  **CHAS 2018-2022** (2019-2023 released? XXX). **Burden validation:** Fauquier renters XX.X%
  (GP 40.2%), owners XX.X% (GP 21.5%). **Bealeton place-level:** present / absent (XXX). **Afford
  assumptions (mirror GP):** rate XX% (pull XXXX-XX), 10% down, RE tax XXX, insurance $XXX/mo,
  rep HH size 3-person. **Income needed:** rent $XXk (fact-sheet ~$98k), buy $XXXk (~$183k).
  **Gap direction:** rental deficit at ≤30% ✔ / ownership XXX (vs GP Figs 27–28). **Deviations:** XXX.
  **Open questions:** XXX.
```

### Commit command

```bash
git add r/hud_ami.R r/chas.R r/gaps.R r/affordcalc.R plans/session-06-affordability-gaps.md PLAN.md
git commit -m "Session 6: affordability & gap computations (HUD AMI, CHAS, gaps)"
```
(No Claude/Anthropic co-author lines — PLAN §3 / CLAUDE.md.)

### Save the plan file to the repo

After plan approval, save this document as
`R:\hda\fhfh\plans\session-06-affordability-gaps.md` (matching the `session-0N-<topic>.md` convention).

---

## Verification (Definition of Done)

- [x] `r/hud_ami.R`, `r/chas.R`, `r/gaps.R` run clean end-to-end via `Rscript`; `r/affordcalc.R`
      sources without error.
- [x] `data/hud_ami.rds`, `data/chas.rds`, `data/gaps.rds` written; each validation block passes (or
      variances documented in §11).
- [x] Fauquier HUD area verified from the IL file (not assumed); MFI read from file ($166,100).
- [x] CHAS burden rates sanity-checked: CHAS T8 renter 32.9% / owner 20.1% printed alongside the ACS
      ballpark (renter 40.2% / owner 21.5% = GP headline, reproduced exactly); benchmark re-anchored
      to CHAS ranges (Jonathan-approved); total HH 25,944 vs GP ~26,720.
- [x] Income-needed-to-rent / -to-buy reconcile with fact-sheet ($98k exact / $190,586 vs ~$183k, within
      tolerance) under GP-mirrored assumptions.
- [x] Rental (deficit at ≤30%) & ownership (8 of 218 listings affordable below ~100% AMI) gap
      **directions** match GP Figs 27–28.
- [x] Affordability assumptions (rate + pull date, tax, insurance, down %, HH size) recorded in
      `gaps.rds$assumptions` and the §11 log for Session 11's data-notes.
- [x] §9 checkboxes ticked, §9 status row + §11 log updated, committed.

**Build deviations (see PLAN.md §11 for detail):** (1) QCEW re-pulled — plan's Fig 8 needed ownership
(Local Government) + 2-digit sector wages absent from the Session 3 `qcew.rds`; `r/qcew.R` filter
relaxed to agglvl 71/74 (Jonathan-approved). (2) CHAS burden benchmark re-anchored — GP's 40.2%/21.5%
is the ACS figure, not CHAS (Jonathan-approved). (3) HUD IL URL is `il26/` + needs browser headers.
(4) CHAS dictionary is a separate download, not inside the zip. (5) median rent from MLS ($2,450), not
ACS B25064. (6) PMMS `tail()` → last non-NA (July 2026 is NA). (7) `case_when()` over deprecated `case_match()`.
