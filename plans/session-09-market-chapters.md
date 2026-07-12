# Session 9 (Ownership + Rental Market chapters) — FHFH Housing Needs Assessment

This plan builds Chapter 3a (`market-ownership.qmd`) and Chapter 3b (`market-rental.qmd`). `PLAN.md` remains the source of truth; this file is the step-by-step execution reference, modeled on `plans/session-08-inventory-demographics.md`.

## Context

- **Targets:** 15 §7 deliverables total — Ch 3a = 7 figures/callouts (F1–F7), Ch 3b = 8 (F1–F8). Report order slots both chapters between `demographics.qmd` and `gaps.qmd` (already wired in `_quarto.yml`; `@sec-market-ownership` is already cross-referenced from Ch 1 and Ch 2).
- **Narrative rule (§3):** takeaway chart titles + 2–5 bullet findings per section + callouts only. **No drafted prose paragraphs.**
- **Data-flow rule:** `r/` scripts → `data/*.rds` → chapters `read_rds()` only. Chapters never call APIs.
- **Per-chapter DoD:** setup chunk (`source("_common.R")` + `read_rds()`), all §7 figures with takeaway titles + `#| fig-alt:` + caption helpers, bullet findings, ≥1 Warrenton/Bealeton callout, closing §6 interview-validation callout, `quarto render <chapter>.qmd` clean, reliability spot-checked on town figures.
- **Model:** Opus (judgment-heavy chapter build, per §9 line 333).
- **Natural split point (optional, mirrors Session 8):** Part 1 = Phase 0 (caption helpers + `r/mls.R` additions) + `market-ownership.qmd`; Part 2 = `market-rental.qmd` + session close.

### Chapter → dataset map (`read_rds` inputs)

| Chapter | `data/*.rds` inputs |
|---|---|
| `market-ownership.qmd` | `mls.rds` (+ new frames from Phase 0b), `fred.rds`, `gaps.rds`, `acs_income.rds` (median HH income trend) |
| `market-rental.qmd` | `acs_stock.rds`, `acs_costs.rds`, `costar.rds`, `fmr.rds`, `nhpd.rds`, `fred.rds` |

## Decisions locked for this session (2026-07-12)

1. **MLS granularity — targeted `mls.rds` additions + scope-down (Jonathan-approved).** Phase 0b adds three small *aggregate* frames to `mls.rds` (town-zip annual median price 2022+; days-on-market summary 2022+; sales-by-price-band counts 2022+), then re-runs `r/mls.R`. Active-inventory / months-of-supply stay a **current snapshot** (a retroactive inventory time series cannot be reconstructed) and are footnoted. No raw transaction-level frame is written.
2. **Ch 3a Fig 6 reuses `gaps.rds`, does not recompute.** Income-needed-to-buy comes from `gaps$income_needed$buyer_income` (~$190,586) with parameters from `gaps$assumptions` (rate 6.49% PMMS 2026-06, 10% down, 28% front-end, tax+ins $697/mo). This reconciles Ch 3 with Ch 4. Do **not** re-source `affordcalc.R` in the chapter.
3. **NHPD assisted inventory lives in Ch 3b (F7), not Ch 1** — carried forward from Session 8 Decision 7.
4. **Town-zip price series is MLS-only (2022+).** The county monthly series splices VAR (2016–2021) → MLS (2022+); VAR is county-only, so town zips begin 2022. State this in Ch 3a F2 subtitle/caption.
5. **Price-band chart scoped to 2022+ (MLS only)** — locked 2026-07-09. GP's historical entry-level collapse (<$250k: 27.8% → 3.0%) is cited in caption/bullets, not re-plotted.
6. **Real-dollar deflation:** county sale prices deflate by `fred$cpi` (CPI less shelter, `CUUR0000SA0L2`); CoStar asking rents are already CPI-adjusted in `costar$quarterly$asking_rent_adj` (uses `CUUR0000SEHA`). Label every adjusted series explicitly and add `cpi_cap()`.
7. **Reliability:** all place-level (Warrenton/Bealeton) ACS cells get CV treatment via `flag_reliability()` (0–100 CV, High ≤15 / Medium ≤30 / Low >30). Suppress Low (`—` in tables, `NA` in charts); footnote Medium. Bealeton floor: prefer counts over rates. Never `hdatools::add_reliability()`.
8. **New caption helpers** added to `_common.R` in Phase 0a: `costar_cap()`, `fmr_cap()`, `nhpd_cap()`, `pmms_cap()`. `mls_cap()` and `cpi_cap()` already exist — do not redefine.

### Out of scope

No prose paragraphs. No figures beyond the §7 list without a §11 note + Jonathan's OK. No changes to `gaps.rds` / affordability math (Session 6, locked). No new API pulls in chapters. No `data-notes.qmd` content (Session 11). No CHAS burden charts here (those are Ch 4 / `gaps.qmd`) — Ch 3b uses ACS renter burden (B25070) only as a bullet stat, not a full figure.

---

## Shell & code conventions

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/mls.R                 # after Phase 0b edits
quarto render market-ownership.qmd
quarto render market-rental.qmd
quarto render                   # full book at session end
```

- Native pipe `|>`; tidyverse style; dplyr ≥ 1.2 idioms (`.by=`, `across()`, `join_by()`).
- **`recode_values()`/`case_match()` are NOT available in the installed dplyr 1.2.1 — use `case_when()`.** (Carried deviation, every recent session.)
- `theme_hda()` (+ `flip_gridlines = TRUE` for horizontal bars); `scale_fill_hda()` / `scale_*_manual()` on `blue/green/yellow/coral <- hda_pal[1:4]`; `add_zero_line()`.
- Titles = takeaway sentences (duplicate the `#| fig-cap:` into `labs(title=)`); subtitle = geography/units/years; for 2–3 series prefer ggtext `<span style='color:#...'>` bold words over legends (then drop legend).
- Currency: `label_dollar()`; percent: `label_percent(accuracy = 1)`. Note nominal vs. adjusted in subtitle.
- Tables: `kbl(col.names=, align=) |> kable_styling(c("condensed","striped"), full_width = FALSE) |> footnote(general=, general_title="", footnote_as_chunk=TRUE)`.
- Every figure: `#| label: fig-*`, `#| fig-cap:`, `#| fig-alt:`. Tables: `#| label: tbl-*`, `#| tbl-cap:`.

---

## Step 0 — Prerequisite gate

Resolve before writing chapter bodies (temp check scripts go in scratchpad, not the repo):

1. **All input `.rds` load:** `mls, fred, gaps, acs_stock, acs_costs, costar, fmr, nhpd, acs_income`.
2. **`acs_income.rds` has an annual median-HH-income series (B19013)** for the Ch 3a F3 index. If only point-in-time, fall back to two anchors (2016 + latest ACS $130,189) or cite GP's +35% directly — decide and note in §11.
3. **`gaps$income_needed$buyer_income` and `gaps$assumptions`** present and readable (Ch 3a F6).
4. **`costar$quarterly$vacancy_rate` NA-status** — if all `NA`, drop the vacancy panel in Ch 3b F4 and footnote "vacancy not reported in CoStar extract."
5. **`acs_stock$vars$b25032`** label frame exists (Ch 3b F5 structure-type recode) — mirror inventory's `stock$vars$b25024` pattern. If absent, build the label map inline from `tidycensus::load_variables()` cache or hardcode B25032 renter-side variables.
6. **`acs_stock$b25003_trend`** is the only tenure frame (no point-in-time `b25003`) — Ch 3b F1 filters `year == 2024`.
7. **Raw MLS files present** in `data/raw/mls/` (`mls_sales_*.csv`, `mls_active_*.csv`, `mls_rentals_*.csv`, `var_*.xlsx`) so Phase 0b re-run succeeds.

---

## Phase 0 — Shared infrastructure (do first)

### 0a. `_common.R` additions — new caption helpers

Add after the existing helpers (do **not** touch `acs_cap/chas_cap/mls_cap/qcew_cap/cpi_cap/...`, all present):

```r
costar_cap <- function()
  "**Source:** CoStar multifamily market data, quarterly."

fmr_cap <- function(year = "FY2026")
  paste0("**Source:** HUD Fair Market Rents and Small Area FMRs, ", year, ".")

nhpd_cap <- function()
  "**Source:** National Housing Preservation Database (NHPD)."

pmms_cap <- function()
  "**Source:** Freddie Mac Primary Mortgage Market Survey (PMMS), 30-year fixed rate, via FRED."
```

Update `CLAUDE.md` (Chapter helpers caption-helper list) and `README.md` to list the four new helpers. Confirm `cpi_cap()` is appended where CPI-adjusted series are shown.

### 0b. Upstream data edits (approved) + re-run — `r/mls.R`

Add three small aggregate frames to the `write_rds(list(...))` at the end of `r/mls.R` (§9 in the script). All derive from the existing `sales` transaction frame (2022+), keep the script idempotent, and preserve current validation:

```r
# Town-zip annual median price (MLS 2022+). town_zips already defined in script.
annual_zip <- sales |>
  filter(year >= 2022, zip %in% town_zips) |>        # verify zip column name in export
  mutate(town = case_when(
    zip %in% c("20186", "20187") ~ "Warrenton",
    zip == "22712"               ~ "Bealeton",
    TRUE ~ NA_character_)) |>
  filter(!is.na(town)) |>
  summarize(median_price = median(close_price, na.rm = TRUE), n = n(),
            .by = c(year, town))

# Days-on-market summary (2022+). Prefer an export DOM column; else close_date - list_date.
dom_annual <- sales |>
  filter(year >= 2022) |>
  mutate(dom = as.integer(close_date - list_date)) |>   # or parse_number(dom_field) if present
  filter(!is.na(dom), dom >= 0) |>
  summarize(median_dom = median(dom, na.rm = TRUE), n = n(), .by = year)

# Sales by price band (2022+). Bands aligned to affordability narrative.
band_brks <- c(-Inf, 250e3, 350e3, 500e3, 750e3, Inf)
band_labs <- c("<$250k", "$250–350k", "$350–500k", "$500–750k", "$750k+")
sales_bands <- sales |>
  filter(year >= 2022) |>
  mutate(band = cut(close_price, band_brks, band_labs, right = FALSE)) |>
  summarize(n = n(), .by = c(year, band)) |>
  mutate(share = n / sum(n), .by = year)
```

Add these to the output list (`annual_zip = annual_zip, dom_annual = dom_annual, sales_bands = sales_bands`) and extend the validation block (row counts > 0; bands sum to 1 per year). Then re-run:

```bash
export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"
Rscript r/mls.R
```

> **Verify at build:** the raw MLS export's zip column name (`zip`? `postal_code`?) and whether a native days-on-market field exists. Adjust the two `# verify` lines accordingly before running.

---

## Phase 1 — `market-ownership.qmd` (Ch 3a)

Title: `# The For-Sale Market {#sec-market-ownership}` (keep the slug exact — already cross-referenced). Add the purpose/narrative-rule HTML comment (copy inventory's, reference "PLAN.md §7 Ch 3a").

**Build order:** setup → F1 → F2 → F3 → F4 → F5 → F6 → F7 (interview-validation close).

**Setup chunk** (`#| label: setup`, `#| include: false`): `source("_common.R")`; `read_rds` for `mls, fred, gaps, acs_income`; define `blue/green/yellow/coral <- hda_pal[1:4]`; pre-compute inline scalars (2025 median price, price/payment/income growth %, income-to-buy gap) for prose bullets.

**F1 — Annual sales volume, 2016–2026 (columns).** Source `mls$annual` (`year, sales_count, median_price, source`). Columns of `sales_count` by year; annotate the GP→MLS splice at 2021/2022; `add_zero_line("y")`. **Reliability:** n/a. **Caveat (required):** 2026 is partial-year (YTD) — annotate or drop the bar. `caption = mls_cap("2016–2026")`. *Takeaway:* sales cooled from the 2020–21 peak. *Bullets:* peak year + count; recent decline; splice sources.

**F2 — Median sold price, nominal + real, county + town zips (line).** County trend from `mls$monthly` (VAR 2016–2021 → MLS 2022+); town zips from new `mls$annual_zip` (Warrenton, Bealeton; 2022+ only). Real = deflate `median_price` by `fred$cpi` to latest period. Color nominal vs real via ggtext spans; direct-label town-zip lines. `caption = paste0(mls_cap("2016–2026"), " ", cpi_cap())`. **Caveat:** town-zip series begins 2022 (VAR is county-only); thin Bealeton counts → footnote. *Takeaway:* real prices up sharply, towns track county. *Bullets:* county nominal & real %; Warrenton vs Bealeton levels.

**F3 — Price / payment / income index, 2016 = 100 (line) — GP Fig 9 replication.** Price = `mls$annual` median; payment = monthly P&I from that year's median price × `fred$pmms_annual$mortgage_rate_30yr` (10% down, 30-yr) — compute in-chunk with `FinCal`-free formula or a small local fn; income = annual median HH income from `acs_income` (B19013 trend; fallback per Step 0 #2). Index all three to 2016 = 100; direct-label. `caption = paste0(mls_cap(), " ", pmms_cap(), " ", acs_cap("B19013"))`. **Reliability:** n/a (county). *Takeaway:* monthly payments rose far faster than incomes. *Bullets:* price +~79%, payment +~127%, income +~35% (state actuals vs GP).

**F4 — Sales by price band, 2022–2026 (stacked share).** Source new `mls$sales_bands` (`year, band, n, share`). 100% stacked columns by year; `scale_fill_hda()`; `theme_hda(flip_gridlines = FALSE)`. **Scope caveat (required):** 2022+ only (MLS); GP's historical <$250k collapse (27.8% → 3.0%) cited in caption. **Reliability:** n/a. *Takeaway:* the entry-level band has all but vanished. *Bullets:* current <$250k & <$350k shares; upward drift of the median band.

**F5 — Days on market + current inventory / months of supply.** DOM trend line from new `mls$dom_annual` (median DOM by year, 2022+). Active inventory = `nrow(mls$active)` (~218, single July 2026 snapshot); months of supply = active ÷ recent avg monthly sales (from `mls$monthly` 2025). Render the DOM trend as the figure + a `::: {.callout-note}` current-snapshot box (inventory + MoS). **Footnote (required):** inventory/MoS are point-in-time, not a trend. *Takeaway:* fast market, thin supply. *Bullets:* DOM trend; current MoS = seller's market (<X months).

**F6 — Income needed to buy the median home vs actual median income (callout / bar).** Reuse `gaps$income_needed$buyer_income` (~$190,586) and `gaps$assumptions` (rate, down, front-end, tax+ins); actual Fauquier median HH income $130,189. Two-bar comparison or a `::: {.callout-note}` box. Cross-ref `@sec-gaps`. `caption` cites the reused affordability parameters. *Takeaway:* buying the median home takes ~$60k more than the median household earns. *Bullets:* income needed vs actual; assumptions one-liner; forward-ref to Ch 4.

**F7 — Active listings < $350k callout — interview validation (§6, required).** Source `mls$active` (`list_price`). Count active listings < $350k in the July 2026 snapshot; contrast with the interview's "3 for-sale listings < $350k, April 2026." Closing `::: {.callout-important}` "What the interviews said vs. what the data shows": entry-level scarcity + quality-vs-price mismatch, tagged *Confirmed.* / *Confirmed and nuanced.*, cross-referencing F1–F4/F7.

---

## Phase 2 — `market-rental.qmd` (Ch 3b)

Title: `# The Rental Market {#sec-market-rental}`. Purpose/narrative-rule comment ("PLAN.md §7 Ch 3b").

**Build order:** setup → F1 → F2 → F3 → F4 → F5 → F6 → F7 (table) → F8 (interview-validation close).

**Setup chunk:** `source("_common.R")`; `read_rds` for `acs_stock, acs_costs, costar, fmr, nhpd, fred`; `blue/green/yellow/coral`; a `structure_cat()` helper for B25032 (mirror inventory's B25024 collapse); pre-compute renter-share and rent-gap scalars for bullets.

**F1 — Renter households: count & share, county + towns (B25003).** Source `acs_stock$b25003_trend` filtered `year == 2024` (owner `_002`, renter `_003`, total `_001`). Renter share by geography (county, Warrenton, Bealeton, VA); optional 2013→2024 trend note. **Reliability:** town cells CV-flagged (`cv = (moe/1.645)/estimate*100 |> flag_reliability()`), suppress Low, footnote Medium; Bealeton counts-not-rates. `caption = acs_cap("B25003")`. *Takeaway:* county majority owner; towns markedly more renter. *Bullets:* renter share county vs towns vs VA.

**F2 — Median gross rent trend, nominal + real, county + towns; + CoStar asking rents (line).** Source `acs_costs$trend_rent` (B25064; 2013/17/21/24; county+towns+VA) nominal; real via `fred$cpi`. Overlay `costar$quarterly$asking_rent_adj` (CPI-adjusted MF asking rent) on the same canvas. ggtext spans for ACS-median vs CoStar-asking vs real. `caption = paste0(acs_cap("B25064"), " ", costar_cap(), " ", cpi_cap())`. **Reliability:** town rent cells CV-flagged. *Takeaway:* rents up in real terms; professional asking rents sit above the ACS median. *Bullets:* county rent real/nominal growth; town levels; CoStar–ACS gap.

**F3 — Gross rent distribution, county vs towns (B25063).** Source `acs_costs$b25063`. Collapse rent brackets to ~6 bands; grouped/stacked share, county vs towns. **Reliability:** town cells. `caption = acs_cap("B25063")`. *Takeaway:* where the rental stock actually prices. *Bullets:* modal band; share above/below key thresholds.

**F4 — CoStar multifamily: inventory, vacancy, asking-rent trend (line/columns) — a thin professional market.** Source `costar$quarterly` (`year, qtr, market_units, asking_rent_avg, vacancy_rate, n_properties, asking_rent_adj`) + `costar$properties` (~41 MF properties). Asking-rent trend line (adj); vacancy panel **only if `vacancy_rate` is non-NA** (Step 0 #4) else drop + footnote. `caption = paste0(costar_cap(), " ", cpi_cap())`. **Reliability:** n/a. *Takeaway:* the professional apartment market is small and tight. *Bullets:* n_properties / market_units; latest adj asking rent ($1,604 benchmark); vacancy if available.

**F5 — Rental stock by structure type (B25032 renter side) — single-family's outsized role (bar).** Source `acs_stock$b25032` (tenure × units-in-structure), renter-occupied only; collapse via `structure_cat()` (SFD / SF attached / 2–4 / 5–19 / 20+ / mobile). Share of rental units by structure, county (+ towns if reliable). Labels from `acs_stock$vars$b25032` (Step 0 #5). **Reliability:** town cells. `caption = acs_cap("B25032")`. *Takeaway:* much of the rental stock is single-family — why the apartment market looks thin. *Bullets:* SF share of rentals; apartment (5+) share.

**F6 — FY2026 FMR/SAFMR vs actual rents (dot/range).** Source `fmr$fmr` (`fmr_0br…fmr_4br`, county HMFA) + `fmr$safmr` (3 town zips, `safmr_*br`) vs actual median gross rent by bedroom from `acs_costs$b25031`; optionally MLS SF rent $2,450 reference line. Dot plot by bedroom size: FMR vs SAFMR (town zips) vs ACS actual. `caption = paste0(fmr_cap(), " ", acs_cap("B25031"))`. **Caveat:** SAFMR zip 20186 filtered to the HMFA code. *Takeaway:* FMRs lag the going market at family bedroom sizes. *Bullets:* 2BR FMR vs actual; SAFMR spread across town zips.

**F7 — Assisted inventory (NHPD) table — preservation risk (kbl).** Source `nhpd$properties` (13 props, ~874 assisted units) + `nhpd$programs` (program names per property). Table columns: property_name, city, total_units, total_assisted_units, active program(s), `earliest_expiration` — **sorted by earliest_expiration** to foreground preservation risk. `kbl() |> kable_styling(c("condensed","striped"), full_width = FALSE) |> footnote(...)`; `caption`/footnote via `nhpd_cap()`. **Reliability:** n/a (administrative). *Takeaway:* a meaningful share of assisted units face subsidy expiration within X years. *Bullets:* total assisted units; soonest expirations; program mix. Add a `::: {.callout-note}` Warrenton/Bealeton town spotlight if properties concentrate there.

**F8 — Rentals under $1,700 callout — interview validation (§6, required).** Source `mls$rentals` (`lease_price`; 2025). Count recent rentals < $1,700 vs total; contrast with the interview's "2 of 19 rentals < $1,700." Closing `::: {.callout-important}` "What the interviews said vs. what the data shows": affordable-rental scarcity (F8), thin professional market (F4), preservation risk (F7) — tagged *Confirmed.* / *Confirmed and nuanced.*, cross-referencing figures. Median SF rent $2,450 anchor.

---

## Known gotchas (consolidated)

1. **`recode_values()`/`case_match()` unavailable (dplyr 1.2.1)** — use `case_when()` everywhere.
2. **Renamed output columns** — reference the *renamed* names, not the raw export names: `mls$active$list_price`, `mls$rentals$lease_price`, `fmr$fmr$fmr_2br`, `fmr$safmr$zip`, `nhpd$properties$earliest_expiration` / `nhpd_id` / `address`. (Raw names like `hud_area_code`, `zip_code`, `nhpd_property_id`, `property_address` only exist pre-rename inside the scripts.)
3. **No point-in-time B25003** — Ch 3b F1 uses `acs_stock$b25003_trend` filtered to 2024.
4. **Town-zip price series is 2022+ only** (VAR is county-only); Bealeton (22712) transaction counts are thin → annual grain + footnote/suppress low-n cells.
5. **`costar$quarterly$vacancy_rate` may be all-NA** — check first; drop the vacancy panel + footnote if so.
6. **CoStar column quirks** — market-level series lives in `costar$quarterly`; property-level in `costar$quarterly_prop` (`period, building_class, address, units`=`x9`, `building`); subtotal/grand-total rows already excluded.
7. **`mls$annual` is a GP↔MLS splice** (source flag "GP"/"MLS"); `mls$monthly` is VAR↔MLS. Annotate the splice; don't average medians across the boundary.
8. **2026 is partial-year (YTD)** in `mls$annual`/`mls$monthly` — annotate or exclude the final point.
9. **CV scale is 0–100** in the `.rds` frames — use `flag_reliability()`; never `hdatools::add_reliability()` (expects 0–1 `*_cv`, mislabels town cells "Low").
10. **Ch 3a F6 reuses `gaps.rds`** — do not source `affordcalc.R` or recompute; pull `gaps$income_needed$buyer_income` + `gaps$assumptions`.
11. **`acs_income` annual median** may not exist as a full series — confirm at Step 0; fallback to endpoint anchors for the F3 income line.
12. **`freeze: auto`** — re-render requires the chunk to change or the freeze to be cleared; run `quarto render <chapter>.qmd` per chapter, then `quarto render` for the book.
13. **`_quarto.yml` `execute-dir: project`** — `read_rds("data/...")` paths are relative to project root, not the `.qmd`.
14. **Phase 0b re-run of `r/mls.R`** must keep existing validations green (2025 median ~$645k, active ≥100, monthly 2016→2025+) and the new frames non-empty.

---

## End-of-session hygiene

### PLAN.md §9 checkboxes (tick for both chapters)

```
[ ] Setup chunk (_common.R, read_rds only), figures/tables per §7 with takeaway titles, alt text, captions
[ ] Bullet findings per section (§3 narrative rule); town callout box(es); §6 interview-validation callout
[ ] quarto render <chapter>.qmd clean; spot-check reliability flags on town figures
```

### PLAN.md §11 log entry

Add a dated Session 9 entry (Opus 4.8): scripts/files touched (`r/mls.R` +3 frames; new `_common.R` caption helpers; two chapters); validation numbers vs GP (2025 median $650k vs ~$645,250; price/payment/income growth vs +79/+127/+35; CoStar adj rent ~$1,604; assisted units ~874/13 props; 2BR FMR); every **deviation from plan** (numbered, note the MLS scope-down decision + any direction-flips discovered at build); reliability spot-check results; deferrals; and **Open questions** (e.g. `acs_income` annual series availability; CoStar vacancy NA-status). Flip the §11 status table row for Session 9 to `complete 2026-07-XX | Opus 4.8`.

### Commit

```bash
git add r/mls.R _common.R market-ownership.qmd market-rental.qmd CLAUDE.md README.md \
        docs/ _freeze/ PLAN.md plans/session-09-market-chapters.md
git commit -m "Session 9: ownership & rental market chapters"
```

(If splitting: Part 1 commit "Session 9 (part 1): market infra + ownership chapter"; Part 2 "Session 9 (part 2): rental chapter + session close".)

### Save this plan to the repo

Copy this file to `plans/session-09-market-chapters.md`.

---

## Verification (Definition of Done)

- [ ] `Rscript r/mls.R` re-runs clean; `mls.rds` now has `annual_zip`, `dom_annual`, `sales_bands`; existing validations pass.
- [ ] Four new caption helpers in `_common.R`; `CLAUDE.md` + `README.md` updated.
- [ ] `quarto render market-ownership.qmd` clean — F1–F7 present with takeaway titles, `#| fig-alt:`, caption helpers; F6 reuses `gaps.rds`; F7 closes with §6 interview-validation callout.
- [ ] `quarto render market-rental.qmd` clean — F1–F8 present; NHPD table (F7) sorted by expiration; F8 closes with §6 callout; vacancy panel handled per NA-status.
- [ ] Both chapters carry ≥1 Warrenton/Bealeton callout; town ACS figures show reliability treatment (Low suppressed, Medium footnoted).
- [ ] `quarto render` (full book) clean; both chapters appear in report order between demographics and gaps.
- [ ] `@sec-market-ownership` / `@sec-market-rental` cross-references resolve.
- [ ] PLAN.md §9 ticked, §11 logged, committed.
