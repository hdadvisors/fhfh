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

message("  FMR columns: ", paste(names(fmr_raw)[1:10], collapse = ", "), "...")

fmr <- fmr_raw |>
  filter(str_detect(hud_area_code, fauquier_hmfa)) |>
  select(
    area_code = hud_area_code,
    area_name = hud_area_name,
    fmr_0br   = matches("^fmr_0"),
    fmr_1br   = matches("^fmr_1"),
    fmr_2br   = matches("^fmr_2"),
    fmr_3br   = matches("^fmr_3"),
    fmr_4br   = matches("^fmr_4")
  ) |>
  slice(1)

stopifnot(nrow(fmr) == 1)
message("  FMR row: ", fmr$area_name)

## 3. SAFMR — zip level ----
message("Reading hud_safmr_fy2026.xlsx...")
safmr_raw <- read_excel("data/raw/hud/hud_safmr_fy2026.xlsx") |>
  clean_names()

message("  SAFMR columns: ", paste(names(safmr_raw)[1:10], collapse = ", "), "...")

safmr <- safmr_raw |>
  filter(
    str_detect(zip_code, paste(town_zips, collapse = "|")),
    str_detect(hud_area_code, fauquier_hmfa)
  ) |>
  select(
    zip       = zip_code,
    area_code = hud_area_code,
    safmr_0br,
    safmr_1br,
    safmr_2br,
    safmr_3br,
    safmr_4br
  )

message("  SAFMR rows retained: ", nrow(safmr), " (expect 3)")

## 4. Write output ----
write_rds(list(fmr = fmr, safmr = safmr), "data/fmr.rds")
message("Wrote data/fmr.rds")

## 5. Validate ----
out <- read_rds("data/fmr.rds")
stopifnot(
  nrow(out$fmr) == 1,
  nrow(out$safmr) == 3,
  between(out$fmr$fmr_2br, 1200, 3500)
)
message("fmr.R validation passed.")
message("  2BR FMR: $", format(out$fmr$fmr_2br, big.mark = ","))
message("  SAFMRs: ", paste(out$safmr$zip, "$", out$safmr$safmr_2br, collapse = " | "))
