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
# Fauquier's HUD area — verified against the FY2026 IL file below (never assume).
hud_area_name <- "Washington-Arlington-Alexandria, DC-VA-MD HUD Metro FMR Area"

## 2. Acquire FY2026 Income Limits (script-fetch, manual fallback) ----
# NOTE: dir is il26 (not il2026); HUD soft-blocks bare user-agents (202/empty), so send a
# full browser UA + Referer. Verified 2026-07-10: 200 OK, 771 KB, sheet "Section8-FY26".
il_path <- "data/raw/hud/hud_il_fy2026.xlsx"
il_url  <- "https://www.huduser.gov/portal/datasets/il/il26/Section8-FY26.xlsx"
if (!file.exists(il_path)) {
  message("Fetching HUD FY2026 Income Limits from ", il_url)
  resp <- tryCatch(
    GET(il_url,
        add_headers(
          `User-Agent`      = paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                                     "AppleWebKit/537.36 (KHTML, like Gecko)",
                                     "Chrome/125.0 Safari/537.36"),
          Accept            = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,*/*",
          `Accept-Language` = "en-US,en;q=0.9",
          Referer           = "https://www.huduser.gov/portal/datasets/il.html"),
        write_disk(il_path, overwrite = TRUE), timeout(180)),
    error = function(e) e
  )
  if (inherits(resp, "error") || !file.exists(il_path) || file.size(il_path) < 100000) {
    stop("HUD IL fetch failed. Manual fallback: download the FY2026 Section 8 Income Limits xlsx ",
         "from huduser.gov/portal/datasets/il.html (FY2026 > Section8-FY26.xlsx) into ",
         il_path, " and re-run.")
  }
}

## 3. Read + verify Fauquier's HUD area ----
il_raw <- read_excel(il_path, sheet = "Section8-FY26") |> clean_names()

# IL files key rows by 10-digit fips (state+county+99999) + hud_area_name.
fauquier_il <- il_raw |> filter(str_starts(as.character(fips), fauquier))

stopifnot(nrow(fauquier_il) == 1)                     # exactly one HUD area row for Fauquier
message("Fauquier HUD area (from file): ", fauquier_il$hud_area_name)
stopifnot(str_detect(fauquier_il$hud_area_name, "Washington-Arlington-Alexandria"))

## 4. Published limits: 30 / 50 / 80% by household size ----
# HUD cols (post clean_names): eli_1..eli_8 (=30% ELI), l50_1..l50_8, l80_1..l80_8, median2026.
# ELI floors at the poverty guideline and is HUD's published 30%-AMI band (faar + GP convention);
# the ELI ≠ exactly-30% nuance is documented in data-notes (Session 11).
published <- fauquier_il |>
  select(matches("^(eli|l50|l80)_[1-8]$")) |>
  pivot_longer(everything(),
               names_to = c("level", "hh_size"), names_pattern = "(.*)_([1-8])",
               values_to = "income") |>
  mutate(level   = case_when(level == "eli" ~ "ami30",
                             level == "l50" ~ "ami50",
                             level == "l80" ~ "ami80"),
         hh_size = paste0(hh_size, "-person"))

# Area MFI (published) — the calc_ami() input.
mfi <- fauquier_il |> pull(median2026) |> as.numeric()
message("Published area MFI (median2026): $", format(mfi, big.mark = ","))

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
  mutate(level   = factor(level, levels = band_order),
         hh_size = factor(hh_size, levels = paste0(1:8, "-person")),
         income  = as.numeric(income)) |>
  arrange(hh_size, level)

## 7. Write output ----
write_rds(
  list(ami       = ami,                 # long: hh_size × level × income
       mfi       = mfi,
       area_name = hud_area_name,
       area_fips = fauquier,
       source    = "HUD FY2026 Section 8 Income Limits (il26/Section8-FY26.xlsx); 100/120% via calc_ami(MFI)",
       cap_note  = "DC-metro 80% limit is HUD-capped to the US median; 100/120% derived from published MFI"),
  "data/hud_ami.rds"
)
message("Wrote data/hud_ami.rds")

## 8. Validate ----
out  <- read_rds("data/hud_ami.rds")
ami4 <- out$ami |> filter(hh_size == "4-person") |> arrange(level)
inc  <- function(lv) ami4 |> filter(level == lv) |> pull(income)
stopifnot(
  nrow(out$ami) == 40,                          # 8 sizes × 5 bands
  all(diff(ami4$income) >= 0),                  # bands ordered ascending for 4-person
  inc("ami100") >= inc("ami80"),                # monotonic across the DC-cap "kink"
  abs(inc("ami100") - out$mfi) / out$mfi < 0.02 # 100% ≈ MFI
)
message("hud_ami.R validation passed.")
message("  MFI: $", format(out$mfi, big.mark = ","),
        " | 4-person 80% (capped): $", format(inc("ami80"), big.mark = ","),
        " | 4-person 100%: $",         format(inc("ami100"), big.mark = ","),
        " | kink 80→100: $",           format(inc("ami100") - inc("ami80"), big.mark = ","))
