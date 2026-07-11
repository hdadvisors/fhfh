# Machine setup checklist

One-time checklist for the first work session on a machine that hasn't touched this repo
before (new laptop, reinstall, etc.). Run through in order — items marked **[Claude]** can be
verified/run directly in the session; items marked **[Jonathan]** need manual action (browser,
file transfer) before Claude can proceed.

Reference values below (R/Quarto versions, drive letters, usernames) were captured from the
desktop machine on 2026-07-11. If this checklist is reused later, re-verify current values
rather than assuming they still match.

## 1. Data — the actual blocker

`data/` is gitignored (622 MB as of 2026-07-11) — it never comes through `git clone`/`pull`.
It holds every completed session's `.rds` output plus all manual raw drops (MLS, CoStar, HUD,
NHPD, PIT, VDOE, WCoop, CHAS). Don't try to regenerate it by rerunning `r/` scripts — several
raw sources are manual drops that can't be re-fetched, and API-derived outputs have accumulated
corrections that only exist in the already-run `.rds` files.

- [ ] **[Jonathan]** Download `data/` from wherever it was backed up (Google Drive, external
      drive, etc.) into the repo root, so it lands at `<repo-root>/data/`.
- [ ] **[Claude]** Confirm it landed correctly: `ls data/*.rds | wc -l` should show ~20 files;
      `ls data/raw` should show `chas/ costar/ hud/ mls/ nhpd/ pit/ vdoe/ wcoop/`.

## 2. Clone the repo

- [ ] **[Jonathan]** `gh auth login` (or sign into git credential manager) — the desktop's
      GitHub token lives in its OS keyring and does not transfer between machines.
- [ ] **[Claude]** Confirm access: `gh repo view hdadvisors/fhfh` should succeed (private repo —
      account needs org access).
- [ ] **[Jonathan/Claude]** `git clone https://github.com/hdadvisors/fhfh.git`. The desktop keeps
      it at `R:\hda\fhfh` on a **local** drive (not network-shared — confirmed via `net use`/
      `subst` returning nothing), so there's no path that has to match; pick any location.

## 3. Verify R + Quarto

- [ ] **[Claude]** `Rscript -e 'R.version.string'` → desktop reads
      `R version 4.5.1 (2025-06-13 ucrt)`.
- [ ] **[Claude]** `quarto --version` → desktop is on `1.9.36`.
- [ ] **[Claude]** Check whether R is on PATH (`Rscript --version` with no path prepend). It is
      **not** on the desktop's PATH either — CLAUDE.md's `export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"`
      workaround exists because of this. Worth actually adding it to the laptop's permanent PATH
      this time (System → Environment Variables) instead of prepending every session.

## 4. Restore R packages

- [ ] **[Claude]** From repo root: `Rscript -e 'renv::restore()'`. Needs network access to CRAN
      and to GitHub (pulls `hdatools` from `hdadvisors/hdatools`, a public repo).
- [ ] **[Claude]** `Rscript -e 'renv::status()'` afterward will still list
      `boot/cluster/codetools/foreign/lattice/Matrix/mgcv/nlme/nnet/rpart/spatial/survival` as
      "inconsistent" — that's expected noise (base-R recommended packages), not a real problem,
      and shows up on the desktop too.

## 5. Render sanity check

- [ ] **[Claude]** `quarto render` from repo root — should complete clean. `docs/` and
      `_freeze/` are both committed to git (unlike `data/`), so no manual transfer needed there;
      this just confirms the freeze cache behaves correctly on a new machine.

## 6. Lower priority — only if rerunning a data script

Sessions 8–12 (chapter builds + assembly/QA) only read `.rds` via `read_rds()` — chapters never
call APIs, and no further data-pull sessions are planned. Skip this section unless you're
revising an upstream `r/` script.

- [ ] **[Jonathan]** Place a `.Renviron` with `CENSUS_API_KEY`/`FRED_API_KEY` at
      `C:\Users\<laptop-username>\.Renviron` (R's HOME-based auto-load).
- [ ] Note: 10 scripts in `r/` also hardcode a fallback read from
      `C:/Users/JTK/Documents/.Renviron` specifically — that fallback only works unmodified if
      the laptop's Windows username is also `JTK`. If it differs, either also drop the file at
      that literal path or update the hardcoded paths in those scripts.

---

Once all boxes are checked, proceed with PLAN.md §9 Session 8. This file can be deleted or left
in place for the next machine transition — either way it's not part of the report build.
