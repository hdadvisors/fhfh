# Session 11b — Conclusions (`conclusions.qmd`; §7 Ch 7 / rendered Chapter 8) + Appendix Data notes (`data-notes.qmd`)

> Second of two execution sessions split from PLAN.md §9 Session 11. Companion:
> `session-11a-projections.md`. **Run this only after S11a is complete** — conclusions synthesizes
> locked chapter numbers. Together these two deliverables ≈ one normal S8–S10 chapter build.
>
> **Chapter-number crosswalk.** PLAN.md §7 uses conceptual numbering where the ownership/rental split
> shares "Ch 3a/3b". The rendered book auto-numbers each `.qmd` (index + the exec-sum stub are
> unnumbered), so displayed numbers run higher: gaps = Ch 4/rendered 5, populations = Ch 5/rendered 6,
> projections = Ch 6/rendered 7, **conclusions = Ch 7/rendered 8**, data-notes = Appendix A.
> Deliverables are named by filename below; a "Ch N" label is PLAN.md's conceptual number. The `.qmd`
> files never hardcode a number (Quarto numbers from `{#sec-}` headers) — no numbering edit needed.

## Context

These are the two close-out deliverables of the final chapter-build session. Both are prose-heavy but
computation-light, and both structurally depend on the projections chapter (S11a) being final:
conclusions references every prior chapter, and the appendix is where ~10 "open for Session 11
data-notes" items logged across S6–S10 get resolved. This session closes the chapter-build phase;
only Session 12 (assembly/QA) remains after it.

## Kickoff

Build `conclusions.qmd` (PLAN.md §7 "Ch 7"; renders as **Chapter 8**) + `data-notes.qmd` (appendix).
**Prereq: `projections.qmd` (S11a) is complete and its numbers are locked.** Read CLAUDE.md + PLAN.md
§7 (Ch 7 + Appendix), §8 (methodology, verbatim source for the appendix), §4 (vintages table), and
**every §11 log entry** (the appendix's job is to resolve the accumulated open items). Template for
the appendix: adapt faar's `data-notes.qmd` (`R:\hda\faar\data-notes.qmd`) — structure + methodology
prose. **`read_rds()` only; no new data, no new figures.**

## Prereq `.rds` (all present; used only for inline scalars/vintage confirmation)

- Conclusions: none required beyond re-reading finished chapter numbers; may pull inline scalars from
  `gaps.rds`, `wcoop.rds`, `acs_costs.rds`, `chas.rds` for the summary table.
- Appendix: `hud_ami.rds` (MFI $166,100, HUD area, 80% cap note), `wcoop$assumptions` (projection
  model), `gaps$assumptions` (rate 6.49%, 10% down, 28% front-end, $697 tax+ins, 3-person HH).

## Ch 7 content (§7)

- Bullet synthesis only, organized by the scope's needs framing: **by income level, tenure, household
  type, geography.** No new data; every stat traceable to a Ch 1–6 figure (cite `@fig-*`/`@sec-*`).
- **`tbl-needs-summary`** — short "needs by segment" summary table. Suggested rows = segments the
  report actually quantified (e.g. ≤30% AMI renters, 30–80% AMI renters, first-time/moderate-income
  buyers, cost-burdened seniors, forward growth to 2050); columns = headline need + supporting stat +
  source chapter. Keep it a synthesis index, not new analysis. (Row set is a judgment call guided by
  the scope framing — not undecidable; expect one iteration with Jonathan on which segments make the cut.)

## Appendix content (§7 + §8)

- **Source & vintage table** — §4 actuals (record real vintages used: ACS 2020–2024, CHAS 2018–2022,
  WC 1-July-2025, HUD FY2026, LODES 2023, QCEW 2015–2025, PIT 2018–2025, VDOE 2020-21…2024-25).
- **AMI methodology** (§8: HUD-published limits + `calc_ami()` extension, no PUMS, DC-metro area, 80%
  cap kink), **affordability assumptions** (`gaps$assumptions`), **gap methodology** (rental T14/T15,
  ownership listings×affordcalc), **projection model** (`wcoop$assumptions`: two household methods,
  avg-size headline, 3% vacancy, GP +7,737/307 divergence), **MOE/reliability policy**
  (`flag_reliability()` 0–100 CV tiers), **zip≠town caveat**, **interview methodology** (6 interviews /
  9 participants), **GP-study relationship note.**
- **Resolve these accumulated open items (from §11 logs — the appendix is their home):**
  - ACS-vs-CHAS burden denominator reconciliation (ACS drops ~700 "not computed" renters → 40.2% vs
    CHAS 32.9%; Fig 4 uses ACS, Fig 5 uses CHAS). *(S6, S10p1)*
  - Household-projection method divergence: real B25010 = 2.78, not GP's implied ~2.70 → +6,795/+6,662
    vs GP +7,737; production ~269/yr vs GP 307/yr. *(S7, S11a)*
  - CPI-less-shelter deflator: shelter excluded to avoid circularity with housing costs. *(S8)*
  - FMR direction: Fauquier's DC-metro FMR runs *above* actual local rents; SAFMR/ACS are the better
    local gauge. *(S9)*
  - NHPD `total_assisted_units` (874) can exceed a property's `total_units` where subsidies overlap. *(S9)*
  - MLS published-vs-export sales count gap (~+14–23%); prices agree to ~0.1%; whether to re-base
    sales volume / active snapshot on the published summary series. *(S9 follow-on)*
  - Family-poverty *rates* use S1702 subject percentages (C02/C04/C06) while counts anchor bases;
    PIT region-vs-Fauquier scope + PIT-vs-McKinney-Vento non-additivity; Bealeton manufactured-housing
    ACS undercount (CDP limitation). *(S10p2)*

## Per-deliverable §9 checklist (apply to each)

- [ ] Ch 7: setup chunk, bullet synthesis by income/tenure/household-type/geography, `tbl-needs-summary`,
      all stats cross-referenced to Ch 1–6, no new data. Render clean; `@sec-conclusions` resolves.
- [ ] Appendix: source/vintage table + all §8 methodology sections + every open item above resolved.
      Render clean; `@sec-data-notes` resolves; other chapters' "see Data & Methodology" refs land here.
- [ ] Full-book `quarto render` clean (all 11 pages); no `?@`; `_freeze/` + `docs/` rebuilt.

## Definition of done

Both files render in the book; conclusions is a fully cross-referenced synthesis with the summary
table; the appendix documents every source/vintage/method and closes all listed open items; §11 log
entry added; PLAN.md §9 Session 11 checkboxes ticked + §11 status row set to complete. This closes the
chapter-build phase; only Session 12 (assembly/QA) remains.

## Scope risks & honest flags (S11b)

1. **`data-notes.qmd` is the heaviest single item here, not conclusions.** It carries ~10 accumulated
   reconciliation items plus the full §8 methodology. If the session runs long, the natural internal
   order is appendix-first (it's referenced by finished chapters) then conclusions — but keep them one
   session; splitting them apart adds overhead without cutting risk.
2. **`tbl-needs-summary` row set is a judgment call** — the scope framing (income/tenure/household-type/
   geography) bounds it, so it's decidable, but expect one iteration with Jonathan on segments.
3. **faar `data-notes.qmd` template lives on `R:\`** — if that drive isn't mounted at build, the §11
   logs + §4/§8 contain all needed content; the faar file is a nice-to-have structural reference, not
   a blocker.
