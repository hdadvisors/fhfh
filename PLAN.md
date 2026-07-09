# PLAN.md — FHFH Housing Needs Assessment Build Plan

**This file is the source of truth for building the technical report.** It was produced 2026-07-08 from the scope of work, the Greater Piedmont background study, the stakeholder interview synthesis (including Jonathan's margin comments), and the `R:\hda\faar` template project. Future Claude sessions execute this plan; they do not renegotiate decisions recorded here. Propose amendments to Jonathan instead.

**How to use this file in a session:** read § 1–4 (durable context + conventions), then only the § 9 block for the session you're running. Don't re-read source PDFs or Google Docs unless a task says to. At session end: tick your checkboxes, add a dated entry to § 11, commit.

---

## 1. Project context

| | |
|---|---|
| Client | Fauquier Habitat for Humanity (FHFH), funded by the PATH Foundation |
| Study area | Fauquier County, VA + Town of Warrenton + Bealeton CDP |
| Consultant | HDAdvisors (Jonathan Knopf) |
| This repo's deliverable | **Technical report**: Quarto book → interactive webpage (GitHub Pages) + PDF (route deferred; see § 9 Session 12) |
| Explicitly out of scope | Summary handout, summary slidedeck, presentations (scope items 3–5), and everything in § 10 |

### Key references

- `scope/scope-of-work.pdf` — full scope. Technical report must cover: inventory & production; demographic/socioeconomic drivers; ownership & rental market dynamics; affordability gaps by income/household type/tenure; special-needs populations; projected future needs.
- `background/greater-piedmont-regionhousing-gap-analysis-march-20262.pdf` (GP study, March 2026, sponsored by Greater Piedmont REALTORS) — 4-county regional gap analysis including Fauquier. **County-level only — no Warrenton/Bealeton data. Town-level analysis is this study's differentiator.** Its appendix (pp. 54–70) supplies validation targets (§ 3) and its methodology (§ 8) is deliberately mirrored so numbers reconcile.
- `background/fauquier-county-fact-sheet.pdf` — 1-page GP fact sheet; the wages-vs-housing-costs chart is replicated in Ch. 4.
- Report skeleton (Google Doc `1kdugvmdoh1YfGvwZ3lVOFet2zfKQOyUIwO4ThkDjSk8`) — chapter spine, locked in § 7.
- Interview synthesis (Google Doc `1UVLvMCxzeUsx5VlDCVybPUJhjYUMz0oZWDvLb3XfvH0`) — 6 interviews / 9 participants; 4 themes; Jonathan's comments drive the § 6 crosswalk.
- `R:\hda\faar` — the pattern library. Copy-adapt these specific files rather than writing from scratch:
  - `_quarto.yml`, `_common.R` (global opts, `hda_pal`, `acs_cap()` caption helper, `fct_wrap()`)
  - `r/hud_ami.R` (`calc_ami()`), `r/affordcalc.R` (`calc_affordable_rent/sales`, `calc_income_needed`)
  - `r/bps.R` (permits), `r/chas.R` (CHAS download/clean), `r/costar.R` (CoStar clean + CPI-adjustment pattern)
  - `data-notes.qmd` (methodology appendix text), `.gitignore`/`.renvignore`/`.Rprofile`/`.nojekyll`

### Decisions locked with Jonathan (2026-07-08)

1. **Bright MLS**: Jonathan exports raw files to `data/raw/mls/` (spec in § 5).
2. **Rental data**: ACS is the baseline; **CoStar export** (Jonathan supplies) covers the true multifamily market.
3. **Gap engine**: **CHAS + ACS summary tables** at county *and* place level. **No PUMS** — Fauquier's PUMA blends in neighboring counties and is too expansive for county-pure estimates.
4. **Narrative**: chapters contain **figures, tables, takeaway titles, bullet findings, and callouts only**. Humans write all connecting prose later.
5. **Benchmarks**: Virginia + commute-shed neighbors (Culpeper, Prince William, Loudoun), used selectively — not on every chart.
6. **Vulnerable populations**: ACS + HUD PIT counts + VDOE McKinney-Vento student counts.
7. **Publishing**: GitHub Pages, faar-style (`docs/` output), from Session 1.
8. **PDF**: deferred to Session 12 (typst render vs. manual assembly).

---

## 2. Architecture

Quarto **book** project mirroring faar. Data flows one way: `r/` collection scripts → `data/*.rds` → chapters `read_rds()` only. **Chapters never call APIs.**

```
fhfh/
├── _quarto.yml            # book config: freeze: auto, execute-dir: project, output-dir: docs
├── _common.R              # sourced by every chapter: libs, hda_pal, fips/geoids, caption helpers
├── .Rprofile              # source("renv/activate.R")
├── renv.lock / renv/      # R >= 4.4; dplyr >= 1.2.0; hdatools from GitHub hdadvisors/hdatools
├── CLAUDE.md              # session conventions (written in Session 1)
├── PLAN.md                # this file
├── README.md
├── index.qmd              # about the study
├── exec-sum.qmd           # stub until Session 12
├── inventory.qmd          # Ch 1  Current Inventory & Recent Production Trends
├── demographics.qmd       # Ch 2  Demographic Shifts & Socioeconomic Factors
├── market-ownership.qmd   # Ch 3a Ownership Market Dynamics
├── market-rental.qmd      # Ch 3b Rental Market Dynamics
├── gaps.qmd               # Ch 4  Affordability Gaps
├── populations.qmd        # Ch 5  Vulnerable Populations
├── projections.qmd        # Ch 6  Projected Housing Needs
├── conclusions.qmd        # Ch 7  Conclusions
├── data-notes.qmd         # Appendix: data & methodology (adapt from faar)
├── r/                     # collection/prep scripts — COMMITTED to git (deviation from faar)
├── data/                  # outputs (.rds) — gitignored (MLS/CoStar licensing)
│   └── raw/               # Jonathan's manual drops (mls/, costar/, qcew/, hud/, wcoop/, nhpd/, pit/, vdoe/)
├── docs/                  # rendered site (committed; GitHub Pages serves this)
├── _freeze/               # committed (keeps renders fast and reproducible)
└── scope/, background/    # existing PDFs (unchanged)
```

- Repo: new GitHub repo under `hdadvisors` (suggest `hdadvisors/fhfh`), Pages from `docs/` on main, `.nojekyll`.
- Theming: `hdatools::theme_hda()` + `hda_pal` everywhere. Static ggplot2 charts; `kableExtra` tables; static `sf` maps (no leaflet/ggiraph in MVP).
- Chapter anatomy (copy from faar `market-rental.qmd`): `# Title {#sec-slug}` → setup chunk (`source("_common.R")`, `read_rds()` calls, caption strings) → alternating figure/table chunks (`#| label: fig-*`, `#| fig-cap:`) and bullet blocks → `:::{.callout-note}` boxes for town spotlights and caveats.

---

## 3. R standards & session conventions

### Code style

- Native pipe `|>`; tidyverse style guide; `janitor::clean_names()` on all imported raw data.
- **dplyr ≥ 1.2 idioms** (pin in renv): `.by=` over `group_by()` for one-off grouping; `across()`; `join_by()`; `filter_out()` for exclusion logic; **`recode_values()` with `.unmatched = "error"` for all ACS variable→label recoding** (supersedes soft-deprecated `case_match()`; the error default catches table-structure changes across vintages); `replace_values()`/`replace_when()` for partial updates; `when_any()`/`when_all()` over nested boolean parens; `reframe()` for multi-row summaries.
- `purrr::map()`/`map_dfr()` over `for` loops (faar pattern: `map_dfr(years, \(yr) get_acs(..., year = yr) |> mutate(year = yr))`).
- Script anatomy: header comment (what/source/output), `## 1. Setup ----` numbered sections, ends with `write_rds()` then a **validation block**. No inline `install.packages()`. Idempotent — safe to re-run.
- Validation blocks: `stopifnot()`/warning checks against GP-study benchmarks where comparable (allow tolerance for vintage differences): Fauquier 2024 ACS — pop ~75,865; ~26,720 households; ~78.8% owner; median HH income ~$130,189. MLS 2025 median price ~$645,250. Assisted units ~750. Permits 2020–25 avg ~241/yr. Cost burden: renters ~40.2%, owners ~21.5%.
- tidycensus calls: `get_acs(geography = ..., state = "VA", table = "BXXXXX", year = 2024, survey = "acs5", cache_table = TRUE)`; pull whole tables, not variable lists; build label lookups from `load_variables()` + `separate_wider_delim(label, "!!")`.

### Execution (Windows — critical for Claude sessions)

- **Never run R inline.** Write the script to `r/<name>.R`, then run `Rscript r/<name>.R` from the project root (renv activates via `.Rprofile`). Same for ad-hoc checks: write a temp script, run via Rscript.
- Render with `quarto render` (or `quarto render <file>.qmd` for one chapter) from project root.
- Use forward slashes in R code paths; all paths relative to project root.
- API keys: `CENSUS_API_KEY` and `FRED_API_KEY` live in the user `.Renviron` (verified in Session 1). Never print or commit them.
- **Data-fetch rule**: tidycensus/tigris/lehdr/fredr package downloads are approved. Direct fetches from census.gov file servers (BPS text files, SUB-EST CSVs) and huduser.gov (CHAS zips) are approved with manual fallback. **Anything else on a government host (esp. BLS) requires Jonathan's OK or a manual download** — each § 9 session lists its prerequisite files.

### Chart & table conventions

- `theme_hda()` + `hda_pal`; `add_zero_line()`; horizontal bars use `theme_hda(flip_gridlines = TRUE)`.
- **Titles are takeaway sentences** ("Housing costs have risen much faster than incomes"), subtitle = geography/units/years, caption via source helper (adapt faar `acs_cap()`; add `chas_cap()`, `mls_cap()`, `qcew_cap()` variants).
- For 2–3 series, prefer color-coded bold words in the subtitle (ggtext spans with `hda_pal` hexes) over legends.
- Currency: label with `scales::label_dollar()`; note nominal vs. inflation-adjusted in subtitle. Percent: `label_percent(accuracy = 1)` unless precision matters.
- Tables: `kbl() |> kable_styling(c("condensed", "striped"))`; `formattable::comma`/`percent` for cell formatting.
- Place-level (Warrenton/Bealeton) ACS estimates always carry reliability treatment: compute CV from MOE, flag with `hdatools::add_reliability()`, footnote medium-reliability values, suppress or aggregate away CV > 30%.
- Every figure gets alt text (`#| fig-alt:`) — use the posit-dev alt-text skill.

### Narrative rule

Chapters ship with: takeaway chart titles, 2–5 bullet findings per section (plain statements of what the data shows, each traceable to a figure/table), and callout boxes (town spotlights, data caveats, interview-theme tie-ins quoted briefly). **No drafted paragraphs.** Bullets should be specific enough that a human can expand them into prose without reopening the data.

### Agent skills

- Session 1: Jonathan runs one-time installs — `/plugin marketplace add posit-dev/skills` then `/plugin install quarto@posit-dev-skills` (authoring, brand-yml, alt-text).
- Optional, not preinstalled: `arthurgailes/r-package-skills` — its `r-package-skill` generator can mint a tidycensus or hdatools skill later if sessions repeatedly fumble a package API.

### Session hygiene

- Start: read `CLAUDE.md` + your § 9 session block (+ § 5–8 rows relevant to your tasks). Verify prerequisite raw files exist before writing code that needs them; if missing, do the tasks that don't need them and list the blockers in § 11.
- End: tick checkboxes in § 9, add a dated § 11 log entry (deviations, data surprises, open questions), update README/CLAUDE.md if conventions changed, commit with a concise message (no Claude/Anthropic co-author).

---

## 4. Geography & vintages

### Geographies

| Geography | GEOID | Role |
|---|---|---|
| Fauquier County | `51061` | Primary unit of analysis |
| Town of Warrenton | `5183136` (resolved via `tigris::places("VA", year=2023)`, Session 1) | Town breakout |
| Bealeton CDP | `5105336` (resolved via `tigris::places("VA", year=2023)`, Session 1) | Town breakout |
| Culpeper `51047`, Prince William `51153`, Loudoun `51107` | | Commute-shed benchmarks (selective) |
| Virginia `51` | | Statewide benchmark |

Define once in `_common.R`: `fauquier <- "51061"`, `towns <- c(warrenton = "...", bealeton = "...")`, `benchmarks <- c(...)`, plus `town_zips <- c(warrenton = c("20186","20187"), bealeton = "22712")`.

### Small-geography strategy (the study's differentiator)

- **ACS 5-year place-level** for both towns, always with reliability flags (§ 3). Bealeton CDP estimates will be noisy — prefer counts over rates where MOEs allow, and lean on decennial for anything structural.
- **Decennial 2010/2020** (P1 population, H1 units, tenure) for clean town trend points.
- **CHAS place-level** (sumlevel 160) for AMI-band × tenure × burden in towns.
- **LODES block-level aggregation** to town boundaries for jobs/commute (blocks assigned via `sf::st_within` town polygons).
- **Zip-level** for market data: MLS cuts by 20186/20187/22712; HUD SAFMRs by the same zips. Note in data-notes: zips ≠ town boundaries (Warrenton zips extend beyond town limits).
- **Sub-county population estimates** (Census SUB-EST CSV) for annual town population if needed.

### Vintages (as of July 2026 — record actual vintages used in data-notes.qmd)

| Source | Vintage |
|---|---|
| ACS 5-year (anchor) | **2020–2024** (trend tables back to 2010 for tenure, income, rent, value, population only) |
| Decennial | 2010 SF1 + 2020 DHC |
| PEP | Vintage 2025 (county totals + components) |
| CHAS | **2018–2022** (2019–2023 not yet released; upgrade only if it drops before Session 6) |
| LODES | LODES8, latest year available (2022 or 2023) |
| BPS permits | 2000–2025 annual |
| QCEW | 2015–2025 annual averages |
| HUD Income Limits / FMR / SAFMR | **FY2026** |
| Weldon Cooper projections | 2024 official release (2030/2040/2050) |
| Bright MLS | 2016 – present |
| CoStar | 2015 – present quarterly |
| PIT counts | 2015–2026 |
| FRED CPI (`CUUR0000SA0L2`, less shelter) & PMMS (`MORTGAGE30US`) | through current |

---

## 5. Dataset inventory

### A. API / package pulls (no manual step)

| # | Dataset | Access | Geography | Script → output |
|---|---|---|---|---|
| 1 | ACS demographics: B01001 age/sex, B01003 pop, B03002 race/eth, B11001 HH type, B11007 65+ living alone, B25010 HH size | tidycensus | county, towns, VA, benchmarks (selective) | `r/acs_demographics.R` → `data/acs_demographics.rds` |
| 2 | ACS income & poverty: B19013 median HH income (trend 2010–2024), B19001 income distribution, S1701 poverty | tidycensus | county, towns, VA | `r/acs_income.R` → `data/acs_income.rds` |
| 3 | ACS housing stock: B25001 units, B25002/B25004 occupancy/vacancy, B25003 tenure (trend), B25024 structure type, B25032 tenure × structure, B25034/B25035/B25036 year built, B25041/B25042 bedrooms, B25014 crowding, B25047 plumbing, B25051 kitchen | tidycensus | county, towns, VA | `r/acs_stock.R` → `data/acs_stock.rds` |
| 4 | ACS costs & burden: B25064 median rent (trend), B25063 rent distribution, B25077 median value (trend), B25075 value distribution, B25070 rent burden, B25091 owner burden, B25106 tenure × income × burden, B25118 tenure × income | tidycensus | county, towns, VA | `r/acs_costs.R` → `data/acs_costs.rds` |
| 5 | ACS workforce/commute: B08303 travel time, B08007 place of work; B25007 tenure × age; B18101 disability × age; B11003 family type w/ children; S1702 family poverty | tidycensus | county (+towns where reliable) | `r/acs_workforce.R`, `r/acs_specialpop.R` → `data/acs_*.rds` |
| 6 | Decennial 2010/2020: P1 pop, H1 units, tenure | tidycensus | county + towns | `r/decennial.R` → `data/decennial.rds` |
| 7 | PEP: county totals + components of change (births/deaths/migration) | tidycensus `get_estimates(vintage = 2025)`; SUB-EST CSV for town totals if needed | county (+towns) | `r/pep.R` → `data/pep.rds` |
| 8 | LODES (OD, WAC, RAC) | `lehdr` | county + block-aggregated towns | `r/lodes.R` → `data/lodes.rds` |
| 9 | Boundaries: county, places, (tracts if needed) | `tigris` + `sf` | study area | `r/geo.R` → `data/geo.rds` |
| 10 | CHAS 2018–2022, sumlevels 050 + 160 — tables T7 (income × tenure × HH type incl. elderly), T8 (income × tenure × burden), T14A/B + T15A/B/C (unit affordability × vacancy/occupancy, for the rental gap), T18 (rent/value distributions) | script download from huduser.gov (faar `chas.R` pattern; manual fallback) | county + towns | `r/chas.R` → `data/chas.rds` |
| 11 | BPS permits 2000–2025, by structure type | census.gov text files (faar `bps.R` pattern) | county (+ Warrenton place-level if present in BPS place files; Bealeton is county-issued — cannot isolate) | `r/bps.R` → `data/bps.rds` |
| 12 | FRED: CPI less shelter + 30-yr PMMS | `fredr` | national | `r/fred.R` → `data/fred.rds` |

### B. Manual downloads by Jonathan → `data/raw/`

| # | Dataset | Spec | Needed by |
|---|---|---|---|
| 13 | **Bright MLS closed sales** | Fauquier County residential, Jan 2016–present: close date/price, list price, DOM, property type, new-construction flag, year built, beds, baths, sqft, zip. Yearly CSV chunks OK → `data/raw/mls/` | Session 5 |
| 14 | **Bright MLS active listings snapshot** | All active residential, county: list price, type, beds, zip; note pull date in filename | Session 5 |
| 15 | **Bright MLS rentals** (if available) | Closed leases 2016–present county: rent, type, beds, zip | Session 5 |
| 16 | **CoStar multifamily** | Fauquier County: inventory (properties/units/year built), vacancy, asking rent per unit — quarterly history 2015–present + property list → `data/raw/costar/` | Session 5 |
| 17 | **QCEW** | Annual averages 2015–2025, total + 2-digit NAICS, for 51061/51047/51153/51107 + VA. Either Jonathan approves script-fetch of QCEW open-data CSVs (`data.bls.gov/cew/data/api/...`) in Session 3, or downloads files → `data/raw/qcew/` | Session 3 |
| 18 | **HUD FY2026 Income Limits** | huduser.gov xlsx (or approve script fetch); note Fauquier's HUD area assignment → `data/raw/hud/` | Session 6 |
| 19 | **HUD FY2026 FMR + SAFMR** | FMR area values + SAFMRs for 20186/20187/22712 → `data/raw/hud/` | Session 5 |
| 20 | **Weldon Cooper 2024 projections** | Locality xlsx: total pop 2030/40/50 + age/sex projections → `data/raw/wcoop/` | Session 7 |
| 21 | **NHPD** | Active + inconclusive properties, VA extract (NHPD account): units by program (LIHTC/S8/USDA/HUD), target population, earliest expiration → filter Fauquier → `data/raw/nhpd/` | Session 5 |
| 22 | **HUD PIT counts** | PIT by CoC xlsx, 2015–2026. First confirm which CoC covers Fauquier (likely VA Balance of State; Foothills Housing Network is the local group — verify, don't assume) → `data/raw/pit/` | Session 7 |
| 23 | **VDOE McKinney-Vento** | Homeless student counts, Fauquier County Public Schools, last ~5 school years (Project HOPE-Virginia reports) → `data/raw/vdoe/` | Session 7 |
| 24 | **Fauquier comp plan / planning docs** | PDF(s) with conservation-easement acreage and service-district stats → `background/` (Jonathan's doc comment: "See if latest comp plan or any other planning docs have stats on this") | Session 4 |

### C. Stretch only (do not build unless promoted per § 10)

DCR Conservation Lands GIS layer (easement acreage + map), IRS SOI migration flows, HMDA, PUMS, Zillow, H+T index, eviction data, place-level PEP beyond totals.

---

## 6. Interview-theme → data crosswalk

Each claim below must be quantified in the report; bullets in the relevant chapter should explicitly confirm, nuance, or complicate the interview claim. (Themes: jobs/housing mismatch; land & easements & tax base; infrastructure & missing middle; anti-development attitudes.)

| Interview claim (Jonathan's comment) | Validating metric(s) | Chapter |
|---|---|---|
| Workforce split — most residents commute out, most workers commute in ("LEHD commute patterns; ACS travel time") | LODES OD: share of county jobs held by residents (GP: 35.4%), inflow/outflow counts, top origin/destination localities; B08303 travel-time distribution | Ch 2 |
| Low-wage local job base; higher-paying employers pushed out ("County vs region wage growth — jobs, not residents") | QCEW average wage by sector and total, Fauquier vs Culpeper/PW/Loudoun/VA, levels + 2015–2025 growth | Ch 2 |
| Workers can't afford to both work and live here ("Resident/household wages vs housing costs") | Sector wages vs income-needed-to-rent ($98k) and income-needed-to-buy ($183k) — fact-sheet replication with updated data | Ch 4 |
| April 2026: only 3 for-sale listings < $350k; 2 of 19 rentals < $1,700; quality doesn't match price ("Avg age of stock; production trends; current prices") | MLS active-listing snapshot by price band; rental listing distribution; median year built; stock age by tenure | Ch 1, 3 |
| Missing middle — no ADUs/studios/starter homes; only large homes on large lots ("Permits/production by type; attributes of new construction from MLS") | BPS permits by structure type 2000–2025; MLS new-construction median size/price vs resale; ACS structure mix county vs towns | Ch 1 |
| Conservation easements constrain developable land and shift the tax base ("See if latest comp plan has stats") | Comp-plan easement acreage share + service-district land stats (manual extract); DCR GIS layer = stretch | Ch 1 |
| Aging in place / downsizing seniors and returning young people have no options | Senior suite (Ch 5); bedrooms mix vs household size; 65+ projections | Ch 5, 6 |

---

## 7. Chapter content plan

Figure lists are the MVP target (~45 figures/tables/callouts total). Takeaway titles shown here are placeholders — final titles come from the actual numbers. Every chapter: (a) opens with a 1-line purpose comment, (b) includes at least one Warrenton/Bealeton callout box, (c) ends with a "What the interviews said vs. what the data shows" callout where § 6 applies.

### Ch 1 — Current Inventory & Recent Production Trends (`inventory.qmd`)

1. Study-area map: county + Warrenton + Bealeton boundaries (static ggplot/sf) — the report's orientation figure
2. Housing units by structure type, county vs towns vs VA (B25024, stacked bar) — single-family detached dominance (GP: 84.8%)
3. Year built by tenure (B25036) + median year built callouts (B25035) — aging-stock validation
4. Tenure trend 2010–2024 county (B25003, line) + town tenure snapshot
5. Permits by structure type 2000–2025 (BPS, stacked columns) with 2020–25 avg/yr annotation — missing-middle validation (expect ~all 1-unit)
6. New-construction vs resale attributes from MLS (median price, size) — "large homes on large lots" validation
7. Callouts: vacancy (B25004), mobile-home count/share (Bealeton spotlight), conservation-easement land share (comp plan stat)

### Ch 2 — Demographic Shifts & Socioeconomic Factors (`demographics.qmd`)

1. County population 1990–2025 (decennial + PEP, line); town populations 2010/2020/latest (decennial + ACS/SUB-EST, small bars)
2. Components of change 2020–2025 (PEP, diverging bars: natural change vs migration)
3. Age structure county vs VA (B01001) + 65+ share trend callout
4. Households by type + size (B11001/B25010) county/towns
5. Median household income: county/towns/benchmarks (B19013, bar) + real income trend 2010–2024 (CPI-adjusted line)
6. Income distribution county vs towns (B19001) — expect Bealeton materially lower than Warrenton/county
7. Poverty (S1701) callouts county/towns/VA
8. At-place employment 2015–2025, county vs benchmarks (QCEW, indexed line)
9. Average annual wage by sector + total, county vs benchmarks with growth rates (QCEW) — **the wage-growth validation chart**
10. Live/work flows (LODES): jobs held by residents %, inflow/outflow, top destination/origin localities (bar)
11. Travel time to work (B08303) + % 45-min+ callout

### Ch 3a — Ownership Market (`market-ownership.qmd`)

1. Annual sales 2016–2026 (MLS, columns)
2. Median sold price, nominal + real, county and town zips (MLS + CPI, line)
3. Price / monthly payment / income index, 2016 = 100 (MLS + PMMS + B19013) — GP Fig 9 replication (GP: price +79%, payment +127%, income +35%)
4. Sales by price band over time (MLS, stacked share) — collapse of the entry-level segment (GP: <$250k sales 27.8% → 3.0%)
5. Days on market + active inventory + months of supply (MLS)
6. Income needed to buy the median home vs actual median income (affordcalc callout)
7. Active listings < $350k callout — interview validation (3 as of April 2026)

### Ch 3b — Rental Market (`market-rental.qmd`)

1. Renter households: count/share, county + towns (B25003)
2. Median gross rent trend, nominal + real, county + towns (B25064) and CoStar asking rents on the same canvas
3. Gross rent distribution county vs towns (B25063)
4. CoStar: multifamily inventory, vacancy, asking-rent trend — how thin the professional market is
5. Rental stock by structure type (B25032 renter side) — single-family's outsized rental role
6. FY2026 FMR/SAFMR vs actual rents, county + town zips (dot/range)
7. Assisted inventory (NHPD): properties/units by program + earliest subsidy expiration (kbl table) — preservation-risk framing
8. Rentals-under-$1,700 callout — interview validation (2 of 19 listings)

### Ch 4 — Affordability Gaps (`gaps.qmd`)

1. AMI explainer table: FY2026 limits by band × household size (calc_ami extension of HUD-published limits, kbl)
2. "What each band affords": max rent + max purchase price by AMI band (affordcalc, kbl)
3. Households by AMI band × tenure, county + towns (CHAS T7/T8, stacked bars)
4. Cost burden by tenure: trend (B25070/B25091 county) + town snapshots — expect renters ~40%, owners ~22%
5. **Core chart**: cost burden by AMI band × tenure (CHAS T8), county + town small multiples
6. Rental gap: renter households vs affordable + available units by band (CHAS T14/T15, diverging surplus/deficit bars) — GP Fig 27 analog, county-specific
7. Ownership gap: active listings affordable to each AMI band vs households in band (MLS snapshot + affordcalc) — GP Fig 28 analog
8. Wages vs costs matrix: sector wages (1- and 2-earner) vs income-to-rent / income-to-buy (QCEW + affordcalc) — **fact-sheet replication, the report's signature chart**
9. Town callouts: Warrenton/Bealeton burden and gap headline stats

### Ch 5 — Vulnerable Populations (`populations.qmd`)

1. Senior suite: 65+/75+ growth (ACS + WC), seniors living alone (B11007), older-householder tenure (B25007), elderly cost burden (CHAS T7) — 2–3 figures
2. Disability by age (B18101) + housing-implication bullets
3. Single-parent families with children (B11003) + family poverty (S1702)
4. Homelessness: PIT trend for Fauquier's CoC + VDOE McKinney-Vento counts for Fauquier schools (line/col) — with strong small-count caveats
5. Housing quality: incomplete plumbing/kitchen (B25047/B25051), overcrowding (B25014) — Habitat repair-program hook
6. Manufactured-housing residents (B25024/B25032) — Bealeton spotlight

### Ch 6 — Projected Housing Needs (`projections.qmd`)

1. WC population projections 2030/40/50, county (columns)
2. Household projections: constant 2024 headship ratio applied to WC totals (age-adjusted headship = stretch) — "+X households by 2050" (GP: +7,737)
3. **Annual production need vs actual pace**: WC households + 3% vacancy allowance → units/yr vs 2020–25 permits (refresh GP's 307 vs 241)
4. 65+ population projection (WC age detail) — senior-housing demand signal
5. Needs-allocation table: forward need split by tenure/AMI/price point using current CHAS distribution + Ch 4 gap results (kbl; assumptions documented in data-notes)

### Ch 7 — Conclusions (`conclusions.qmd`)

Bullet synthesis only, organized by the scope's needs framing (by income level, tenure, household type, geography) + a short "needs by segment" summary table. References Ch 1–6 stats; no new data.

### Appendix — Data notes (`data-notes.qmd`)

Adapt faar: source & vintage table (§ 4 actuals), AMI methodology (§ 8), affordability calculation assumptions, gap methodology, projection model, MOE/reliability policy, zip≠town caveat, interview methodology (6 interviews / 9 participants, sectors), GP-study relationship note.

---

## 8. Methodology specs

- **AMI framework (no PUMS — locked decision)**: (a) Band thresholds come straight from HUD-published FY2026 Income Limits (30/50/80% by household size) plus HUD's published Median Family Income for Fauquier's HUD area — **verify the area assignment from the FY2026 file at build; never assume**. faar's `calc_ami(mfi, ...)` is reused only to extend published limits to 100%/120% bands — it takes MFI as an input, so feed it HUD's published MFI. (b) All household-by-AMI cross-tabs come from CHAS HAMFI bands (≤30 / 30–50 / 50–80 / 80–100 / >100%); accept no 120% granularity. (c) B19001-based AMI banding is a clearly-caveated fallback only (brackets misalign with cutpoints; no household-size adjustment). (d) Market gap tests key off band income ceilings at representative household sizes (state the size used, e.g., 3-person).
- **Cost burden**: >30% of income = burdened; >50% = severely burdened; exclude zero/negative-income and no-cost households (CHAS convention).
- **Rental affordability**: max affordable rent = 30% × monthly income. Income needed for median rent = (median rent × 12) / 0.30.
- **Ownership affordability** (mirrors GP so results reconcile): payment ≤ 28% of monthly income; 10% down; 30-year fixed at current PMMS average (record the rate + pull date); plus Fauquier real-estate tax rate and average homeowner's insurance (document both in data-notes). Implement via faar `affordcalc.R` (`FinCal`-based), parameterized.
- **Rental gap**: renter households by CHAS band vs rental units affordable + available to that band (CHAS T14/T15) → surplus/deficit per band.
- **Ownership gap**: MLS active-listing snapshot binned by the max-affordable price per band vs households per band.
- **Production target**: WC household growth (constant-headship) + 3% vacancy allowance → annualized units needed vs 2020–2025 BPS average.
- **Real dollars**: FRED CPI less shelter (`CUUR0000SA0L2`), latest-period benchmark, faar `costar.R` pattern. Label adjusted series explicitly.
- **Reliability**: place-level ACS always CV-flagged (§ 3); PIT/VDOE small counts presented as counts with volatility caveats, never rates.

---

## 9. Session plan

Twelve bounded sessions. Merge two only if the first finishes light; never split a session's outputs across an unfinished pipeline. Suggested models: Sonnet for data sessions (2–5, 7), Opus for methodology- and judgment-heavy sessions (1, 6, 8–12).

**Common DoD for data sessions (2–7):** scripts run clean end-to-end via `Rscript`, outputs written to `data/`, validation blocks pass (or documented variances in § 11), committed.

### Session 1 — Scaffold
Prereqs: Jonathan runs the posit-dev skills install (§ 3); confirms GitHub repo name.
- [x] `git init`; create GitHub repo (`hdadvisors/fhfh` suggested); first commit — **pre-done before Session 1**
- [x] Quarto book skeleton: `_quarto.yml` (adapted from faar: freeze auto, output-dir docs, chapter list per § 2), all chapter stubs with `{#sec-}` anchors, index.qmd
- [x] renv init; install tidyverse (dplyr ≥ 1.2), tidycensus, tigris, sf, janitor, kableExtra, formattable, ggtext, scales, fredr, lehdr, readxl, FinCal, hdatools (`renv::install("hdadvisors/hdatools")`); snapshot — dplyr 1.2.1, hdatools 0.1.7
- [x] `_common.R`: adapt from faar — global chunk opts, `hda_pal`, caption helpers (`acs_cap` + new variants), geography constants incl. GEOID resolution via `tigris::places("VA")` (Warrenton town `5183136`, Bealeton CDP `5105336` — recorded in § 4)
- [x] Copy-adapt `r/affordcalc.R` from faar
- [x] Verify `CENSUS_API_KEY`/`FRED_API_KEY` via a temp Rscript check — keys present in `~/Documents/.Renviron`; R HOME mismatch logged in § 11 (fix: copy file to `~/.Renviron` or set `R_ENVIRON_USER`)
- [x] `CLAUDE.md`: condensed §§ 2–4 conventions + run commands + repo map; `README.md` (quick-start first); `.gitignore` (data/, .Rproj.user, .quarto; NOT r/ or docs/), `.renvignore`, `.nojekyll`
- [x] Render, publish to GitHub Pages — **render clean (docs/ + _freeze/ produced); Pages deferred (private repo + GitHub Free org — see § 11)**
- [x] Delete `STARTUP.md` (superseded by CLAUDE.md + this plan)
- DoD: skeleton site renders and is live on Pages.
- Don't: pull any data yet; build any figures.

### Session 2 — Demographics data
Prereqs: none (all API).
- [x] `r/acs_demographics.R`, `r/acs_income.R` (incl. 2010–2024 trend pulls for B19013)
- [x] `r/decennial.R` (2010/2020 pop, units, tenure for county + towns)
- [x] `r/pep.R` (county totals + components; SUB-EST town totals if straightforward)
- [x] `r/geo.R` (boundaries for the study-area map)
- [x] Validation vs GP appendix (pop, households, income)
- Don't: touch QCEW/LODES (Session 3); build figures.

### Session 3 — Economy & workforce data
Prereqs: QCEW files in `data/raw/qcew/` **or** Jonathan's recorded OK to script-fetch QCEW CSVs.
- [x] `r/qcew.R`: jobs + avg wages, total + 2-digit NAICS, county/benchmarks/VA 2015–2025
- [x] `r/lodes.R`: OD (live/work shares, top flows), WAC/RAC; block-aggregate to towns
- [x] `r/acs_workforce.R`: B08303, B08007
- [x] Validation: Fauquier ~24,138 jobs (2025), avg wage ~$64,272, ~35.4% of jobs held by residents

### Session 4 — Housing stock & production data
Prereqs: comp plan PDF(s) in `background/`.
- [x] `r/acs_stock.R` (all § 5 row-3 tables, county + towns + VA)
- [x] `r/bps.R`: county 2000–2025 by structure type; check whether Warrenton appears in BPS place files
- [x] Extract easement/service-district stats from comp plan → `data/easements.rds` (simple tibble of cited stats + page references)
- [x] Validation: structure mix (84.8% SFD), permits 2020–25 avg ~241/yr

### Session 5 — Market data
Prereqs: MLS exports (§ 5 #13–15), CoStar export (#16), HUD FMR/SAFMR (#19), NHPD extract (#21) in `data/raw/`.
- [ ] `r/mls.R`: clean sales (dedupe, type filters, zip cuts, new-construction flag), listings snapshot, rentals if present
- [ ] `r/costar.R`: adapt faar pattern incl. CPI adjustment
- [ ] `r/acs_costs.R` (rents/values/burden tables incl. trends)
- [ ] `r/fred.R` (CPI + PMMS series); `r/fmr.R` (FMR/SAFMR tidy)
- [ ] `r/nhpd.R`: Fauquier properties/units by program + expirations
- [ ] Validation: 2025 median price ~$645,250; ~174 active listings (3/2026); SF rent ~$2,450; ~750 assisted units

### Session 6 — Affordability & gap computations (methodology-heavy — Opus)
Prereqs: HUD FY2026 Income Limits (#18) in `data/raw/hud/`; Sessions 2–5 outputs.
- [ ] `r/hud_ami.R`: adapt faar — read FY2026 limits, **verify Fauquier's HUD area**, extend to 100/120% via `calc_ami()` fed HUD's MFI
- [ ] `r/chas.R`: download/clean T7, T8, T14, T15, T18 at 050 + 160
- [ ] `r/gaps.R`: rental gap (T14/T15), ownership gap (listings × affordcalc), wages-vs-costs matrix, "what each band affords" — all per § 8
- [ ] Validation: CHAS burden rates vs ACS B25070/B25091 ballpark; gap direction sanity vs GP Figs 27–28
- Don't: swap in B19001 banding where CHAS serves; introduce PUMS.

### Session 7 — Projections & special-populations data
Prereqs: Weldon Cooper xlsx (#20), PIT (#22 — CoC confirmed first), VDOE (#23) in `data/raw/`.
- [ ] `r/wcoop.R`: projections; constant-headship household conversion; 3% vacancy production model vs permits
- [ ] `r/acs_specialpop.R`: B18101, B11003, S1702, B11007, B25007
- [ ] `r/pit.R`, `r/vdoe.R`: small tidy series with source notes
- [ ] Validation: household growth vs GP +7,737; production need vs GP 307/yr (explain variances in § 11)

### Sessions 8–11 — Chapter builds (report order; ~2 chapters each)
S8: `inventory.qmd` + `demographics.qmd` · S9: `market-ownership.qmd` + `market-rental.qmd` · S10: `gaps.qmd` + `populations.qmd` · S11: `projections.qmd` + `conclusions.qmd` + `data-notes.qmd`.
Per chapter:
- [ ] Setup chunk (`_common.R`, `read_rds()` only), figures/tables per § 7 list with takeaway titles, alt text, captions
- [ ] Bullet findings per section (§ 3 narrative rule); town callout box(es); § 6 interview-validation callout
- [ ] `quarto render <chapter>.qmd` clean; spot-check reliability flags on town figures
- DoD: chapter renders in the book, all § 7 figures present or § 11-logged as deferred.
- Don't: write prose paragraphs; add figures beyond § 7 without a § 11 note and Jonathan's OK.

### Session 12 — Assembly & QA (Opus)
- [ ] Full `quarto render`; fix cross-refs, numbering, freeze issues
- [ ] Number sweep: every § 3 validation benchmark and § 6 crosswalk claim checked against rendered output; internal consistency (same stat = same value everywhere)
- [ ] Reliability/caveat review of all town-level figures; alt-text completeness pass
- [ ] `exec-sum.qmd`: bullet skeleton of headline findings (humans write prose)
- [ ] Publish; confirm live site
- [ ] **PDF decision** (deferred by design): prototype `format: typst` render vs. scope a manual-assembly route; present both to Jonathan with samples
- DoD: site live and internally consistent; PDF route chosen and logged.

---

## 10. MVP guardrails — out of scope

No session builds these without Jonathan approving a plan amendment (log the request in § 11):

- Summary handout, slidedeck, presentations (separate scope items — not in this repo's plan)
- PUMS pipeline (locked out — see § 8)
- HMDA, eviction data, H+T index, Zillow/ZORI, IRS SOI migration, ALICE
- DCR conservation-lands GIS analysis/map (stretch; comp-plan stats are the MVP source)
- Interactive charts (ggiraph/plotly), leaflet maps, scrollytelling
- Per-locality fact sheets (faar had them; FHFH scope doesn't)
- Age-adjusted headship projections (constant-ratio is the MVP model)
- New datasets or figures beyond §§ 5 + 7

Rule of thumb: if it isn't needed to render a § 7 figure or satisfy a § 6 validation, it's scope creep.

---

## 11. Progress log

### Session status

| # | Session | Status | Date | Model |
|---|---|---|---|---|
| 1 | Scaffold | complete | 2026-07-08 | Sonnet 4.6 |
| 2 | Demographics data | complete | 2026-07-08 | Sonnet 4.6 |
| 3 | Economy & workforce data | complete | 2026-07-08 | Sonnet 4.6 |
| 4 | Housing stock & production | complete | 2026-07-08 | Sonnet 4.6 |
| 5 | Market data | not started | | |
| 6 | Affordability & gaps | not started | | |
| 7 | Projections & special pops | not started | | |
| 8 | Ch: inventory + demographics | not started | | |
| 9 | Ch: ownership + rental | not started | | |
| 10 | Ch: gaps + populations | not started | | |
| 11 | Ch: projections + conclusions + data notes | not started | | |
| 12 | Assembly & QA | not started | | |

### Log

- **2026-07-08** — PLAN.md created (Fable planning session). Decisions locked per § 1. No code built yet. Open items for Jonathan before Session 3+: batch the § 5-B downloads; run the posit-dev skills install; decide QCEW fetch-vs-download.
- **2026-07-08** — Jonathan initialized the git repo and pushed to the hdadvisors org. Session 1 skips `git init`/repo creation; GitHub Pages still needs configuring.
- **2026-07-08** — Session 1 (Scaffold) complete (Sonnet 4.6). Files created: `_quarto.yml`, `index.qmd`, `exec-sum.qmd`, 8 chapter stubs, `data-notes.qmd`, `_common.R`, `r/affordcalc.R`, `CLAUDE.md`, `README.md`, `.gitignore` (rewritten), `.renvignore`, `.Rprofile`, `.nojekyll`. renv initialized (bare), all 14 packages installed (dplyr 1.2.1, hdatools 0.1.7 from GitHub), snapshot written (`type = "all"`). GEOIDs resolved via `tigris::places("VA", year=2023)`: Warrenton town `5183136`, Bealeton CDP `5105336`. `quarto render` clean — 11 pages produced in `docs/`. **Deviations:** (1) `town_zips` stored as a named list not `c(...)` (flat vector would drop nested warrenton zips). (2) `.renvignore` omits `/r/` vs faar (deliberate — r/ is committed pipeline code; renv should track its deps). (3) `affordcalc.R` cleaned: side-effect code removed, `calc_affordable_sales` takes `dwn_opts` vector, `renter_income` returned numeric. (4) renv `type="all"` snapshot shows data-pull packages (tigris, sf, etc.) as `used=n` — expected since r/ scripts don't exist yet. **Pages deferred:** repo is private + hdadvisors org on GitHub Free (Pages requires public repo or paid plan). To enable later: `gh api -X POST repos/hdadvisors/fhfh/pages -f "source[branch]=main" -f "source[path]=/docs"` (after making repo public or upgrading org), or Settings → Pages → Deploy from branch → `main` `/docs`. URL will be `https://hdadvisors.github.io/fhfh/`. **API key path issue (action needed):** `CENSUS_API_KEY`/`FRED_API_KEY` exist in `~/Documents/.Renviron` but R's HOME = `C:\Users\JTK`, so R doesn't auto-load them at startup. Fix before Session 2: copy `~/Documents/.Renviron` to `C:\Users\JTK\.Renviron`, or set system env var `R_ENVIRON_USER=C:\Users\JTK\Documents\.Renviron`.
- **2026-07-08** — Session 2 (Demographics data) complete (Sonnet 4.6). Scripts: `r/geo.R`, `r/acs_demographics.R`, `r/acs_income.R`, `r/decennial.R`, `r/pep.R`. All five `data/*.rds` files written. **Validation vs GP benchmarks (ACS 5-year 2024 vintage):** Fauquier pop 74,577 (GP ~75,865; −1.7% — ACS 2024 vs GP's 2023 vintage); HH count 26,720 (exact match); median HH income $130,189 (exact match). Decennial 2020 pop 72,972 (GP/Census ~73,895; −923 from differential privacy noise in 2020 DHC); 2010 pop 65,203 (exact). PEP most-recent county pop 75,865 (vintage 2024, July 1 2024). **PEP API change (breaking):** post-2020 PEP API now requires `vintage` argument; `year = 2025` silently defaults to vintage 2024. Fixed `pep.R` to use `vintage = 2024` for components and place calls. Components (vintage 2024): BIRTHS 755, DEATHS 617, NATURALCHG 138, NETMIG 474. **Bealeton CDP:** not covered by PEP (CDP by design); chapters use ACS/decennial for Bealeton population. Warrenton PEP: 10,224. **Decennial 2000:** county data retrieved (55,139); Bealeton returned 0 rows (GEOID "5105336" may not match 2000 vintage). **1990:** hardcoded 48,741 (Census 1990 SF1; plan reference "47,286" appears incorrect — actual 1990 count was 48,741). **Style:** used `case_match()` throughout (`recode_values()` per §3 not available in dplyr 1.2.1).
- **2026-07-08** — Session 3 (Economy & workforce data) complete (Sonnet 4.6). Scripts: `r/lodes.R`, `r/acs_workforce.R`, `r/qcew.R`. **Path taken:** QCEW Path A (script-fetch from BLS open-data API; Jonathan approved in session). **agglvl_code discovery:** confirmed 70 (county total) and 75 (county 2-digit NAICS) as expected. **Deviation from plan:** plan did not account for state-level agglvl_codes — Virginia (51000) uses codes 50 (state total) and 55 (state 2-digit NAICS), not 70/75 (county-only codes). Filter in `qcew.R` updated to `agglvl_code %in% c("50","55","70","75")`; `qcew_total` and `qcew_sector` split accordingly. **lehdr 1.1.4 breaking change:** county-level OD (`agg_geo = "county"`) returns `w_county`/`h_county` columns, not `w_geocode`/`h_geocode`. Fixed by adding `rename(w_geocode = w_county, h_geocode = h_county)` immediately after each county-level OD `grab_lodes()` call. **QCEW validation (2025):** Fauquier jobs 23,910 (GP benchmark 24,138; −1% — within noise), avg annual pay $68,000 (GP benchmark $64,272; +6% — expected wage growth 2023→2025), all 5 areas present, sector coverage OK. **LODES validation (2023):** residency share 35.4% (exact GP benchmark match), total jobs 23,349 (GP 24,138; −3% — LODES 2023 vs GP 2025 vintage), LODES year 2023 confirmed. **acs_workforce:** `cache_table` deprecation warning (harmless — same as Session 2). `B08303_001` (workers 16+ not WFH) and `B08007_001` (all workers 16+) both pass range checks for Fauquier.
- **2026-07-08** — Session 4 (Housing stock & production) complete (Sonnet 4.6). Scripts: `r/bps.R`, `r/acs_stock.R`, `r/easements.R`. **r/bps.R → data/bps.rds:** County series 2000–2025 × 4 structure types. BPS 2025 annual URL (co2025a.txt) confirmed live. BPS avg permits 2020–25: 266/yr (GP benchmark ~241; within expected range 100–500). Warrenton place-level check: BPS place file (pl2024a.txt) returned HTTP 524 (Cloudflare gateway timeout) on both attempts — `warrenton_in_bps = NA`. URL is structurally valid (confirmed from faar pattern); 524 is a transient server-side timeout, not a 404. Action if needed: retry in a future session. `as_tibble.matrix()` and `parse_bps_col_names` compatibility warning — harmless (tibble 2.0.0 column name repair). **r/acs_stock.R → data/acs_stock.rds:** 13 point-in-time tables (B25001–B25051) for Fauquier + Warrenton + Bealeton + VA (2020-2024 ACS 5-year). B25003 tenure trend: 2013, 2017, 2021, 2024. `cache_table` deprecation warnings (harmless, same as Sessions 2–3). **Validation:** Fauquier total housing units 28,621 (benchmark ~30,000; within ±5k ✓); SFD detached share 85.1% (GP benchmark 84.8%; within ±7pp ✓); both towns present; all 13 tables non-empty; 4 trend years present. **r/easements.R → data/easements.rds:** 67 rows across 8 categories (service_district_buildout, housing_production, bealeton_sd_acreages, remington_sd_acreages, warrenton_sd_stats, conservation_easement, utility_capacity, service_district_geography) extracted from 4 comp plan chapter PDFs (ch1b, ch3b, ch6-bealeton, ch6-warrenton). Comp plan PDFs were absent at session-plan time but present at execution — easements task completed. Key stats: build-out capacity 19,776 units (8,381 unbuilt as of 2010); Bealeton SD 2,593 acres total; Remington SD 2,374 acres total; St. Leonard's Farm conservation easement 800 acres (Virginia Outdoor Foundation). Acreage cross-checks passed (parts sum to table totals). **Open question:** does the GP benchmark SFD share of 84.8% count 1-unit detached only, or include attached? (Affects interpretation of the B25024_002 / B25024_001 validation check; our 85.1% is detached-only.)
