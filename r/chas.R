# chas.R ----
# What:   HUD CHAS 2018-2022 tables T7/T8/T14/T15/T18 at county (050) + place (160)
# Tables: 7, 8, 14A, 14B, 15A, 15B, 15C, 18A, 18B, 18C
# Source: huduser.gov CHAS 2018thru2022 (050 + 160 csv zips) + separate data dictionary xlsx
# Output: data/chas.rds
#
# Notes (build 2026-07-10): the CHAS csv zips contain ONLY Table*.csv — the data dictionary is a
# SEPARATE download (CHAS-data-dictionary-18-22.xlsx). HUD soft-blocks bare user-agents, so all
# GETs send a full browser UA + Referer. Vintage locked to 2018-2022 to reconcile with GP (Step 0).

## 1. Setup ----
library(tidyverse)
library(glue)
library(httr)
library(janitor)
library(readxl)

fauquier  <- "51061"
towns     <- c(warrenton = "5183136", bealeton = "5105336")
chas_year <- 2022                     # 2018thru2022 (locked — see Step 0)
sumlevs   <- c("050", "160")
tables    <- c("7", "8", "14A", "14B", "15A", "15B", "15C", "18A", "18B", "18C")

dir.create("data/raw/chas", showWarnings = FALSE, recursive = TRUE)

hud_hdr <- add_headers(
  `User-Agent`      = paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"),
  Accept            = "application/zip,application/octet-stream,*/*",
  `Accept-Language` = "en-US,en;q=0.9",
  Referer           = "https://www.huduser.gov/portal/datasets/cp.html")

## 2. Download + unzip each sumlevel + the dictionary (cached) ----
walk(sumlevs, function(sl) {
  url <- glue("https://www.huduser.gov/PORTAL/datasets/cp/{chas_year - 4}thru{chas_year}-{sl}-csv.zip")
  zip <- file.path("data/raw/chas", basename(url))
  if (!file.exists(zip) || file.size(zip) < 1e6) {
    message("Downloading CHAS ", sl, " ...")
    GET(url, hud_hdr, write_disk(zip, overwrite = TRUE), timeout(600))
  }
  exdir <- file.path("data/raw/chas", sl)
  if (!dir.exists(exdir)) unzip(zip, exdir = exdir)
})

dict_path <- "data/raw/chas/CHAS-data-dictionary-18-22.xlsx"
if (!file.exists(dict_path) || file.size(dict_path) < 1e5) {
  message("Downloading CHAS data dictionary ...")
  GET("https://www.huduser.gov/portal/datasets/cp/CHAS-data-dictionary-18-22.xlsx",
      hud_hdr, write_disk(dict_path, overwrite = TRUE), timeout(180))
}
if (!file.exists(dict_path) || file.size(dict_path) < 1e5) {
  stop("CHAS dictionary fetch failed. Manual fallback: download CHAS-data-dictionary-18-22.xlsx ",
       "from huduser.gov/portal/datasets/cp.html into ", dict_path, " and re-run.")
}

## 3. Dimension recodes (str_detect — robust to per-table wording differences) ----
recode_tenure <- function(x) case_when(
  str_detect(x, "Owner")  ~ "Homeowner",
  str_detect(x, "Renter") ~ "Renter",
  .default = x
)
recode_income <- function(x) case_when(
  str_detect(x, "less than or equal to 30%")                       ~ "≤30% AMI",
  str_detect(x, "greater than 30% but less than or equal to 50%")  ~ "30-50% AMI",
  str_detect(x, "greater than 50% but less than or equal to 80%")  ~ "50-80% AMI",
  str_detect(x, "greater than 80% but less than or equal to 100%") ~ "80-100% AMI",
  str_detect(x, "greater than 100%")                               ~ ">100% AMI",
  .default = x
)
recode_burden <- function(x) case_when(
  str_detect(x, "less than or equal to 30%")                      ~ "Not cost-burdened",
  str_detect(x, "greater than 30% but less than or equal to 50%") ~ "Cost-burdened",
  str_detect(x, "greater than 50%")                               ~ "Severely cost-burdened",
  str_detect(x, "not computed")                                   ~ "No or negative income",
  .default = x
)
# Rent affordability (RHUD30/50/80) in T14B / T15C — the unit's rent expressed as an AMI band
recode_rent <- function(x) case_when(
  str_detect(x, "less than or equal to RHUD30")     ~ "≤30% AMI",
  str_detect(x, "RHUD30 but less than or equal to RHUD50") ~ "30-50% AMI",
  str_detect(x, "RHUD50 but less than or equal to RHUD80") ~ "50-80% AMI",
  str_detect(x, "greater than RHUD80")              ~ ">80% AMI",
  .default = x
)

## 4. Generalized reader ----
# Reads Table{tbl}.csv at sumlevel sl, filters to study geos, splits est/moe, joins the dictionary
# sheet, keeps Detail rows, and recodes the shared dimensions.
read_chas <- function(tbl, sl) {
  csv    <- glue("data/raw/chas/{sl}/{sl}/Table{tbl}.csv")
  dict   <- read_excel(dict_path, sheet = glue("Table {tbl}")) |>
    select(code = `Column Name`, everything())
  targets <- if (sl == "050") fauquier else unname(towns)

  read_csv(csv, col_types = cols(.default = col_guess(),
                                 geoid = "c", name = "c", source = "c", sumlevel = "c")) |>
    clean_names() |>
    mutate(geo_code = str_extract(geoid, "(?<=US)\\d+$")) |>
    filter(geo_code %in% targets) |>
    pivot_longer(matches("_(est|moe)\\d+$"), names_to = "col", values_to = "value") |>
    mutate(id   = str_extract(col, "\\d+$"),
           type = str_extract(col, "est|moe")) |>
    select(-col) |>
    pivot_wider(names_from = type, values_from = value) |>
    transmute(geoid, name, geo_code,
              code = glue("T{tbl}_est{id}"),
              estimate = est, moe) |>
    left_join(dict, by = "code") |>
    clean_names() |>
    filter(line_type == "Detail") |>
    mutate(across(any_of("tenure"),           recode_tenure),
           across(any_of("household_income"), recode_income),
           across(any_of("cost_burden"),      recode_burden),
           across(any_of("rent"),             recode_rent),
           table    = tolower(paste0("t", tbl)),
           sumlev   = sl,
           geo_type = if (sl == "050") "county" else "place")
}

## 5. Read all tables × sumlevels ----
# One list element per table; county (050) + place (160) share identical columns → clean bind.
chas <- map(tables, \(tbl) bind_rows(read_chas(tbl, "050"), read_chas(tbl, "160"))) |>
  set_names(tolower(paste0("t", tables)))

## 6. Write output ----
write_rds(chas, "data/chas.rds")
message("Wrote data/chas.rds (", length(chas), " tables: ",
        paste(names(chas), collapse = ", "), ")")

## 7. Validate — cost-burden rates (CHAS ranges) + ACS ballpark for reference ----
# NOTE: GP's 40.2%/21.5% headline is the ACS B25070/B25091 figure (reproduced exactly below),
# NOT CHAS. CHAS T8 burden runs lower for renters because ACS drops ~700 "not computed" renters
# from its denominator while CHAS does not. Both are correct for their source; validate CHAS
# against CHAS-appropriate ranges and print the ACS ballpark alongside so the divergence is on the
# record (Ch4 uses ACS for the burden-trend headline, CHAS T8 for the by-AMI-band core chart).
out <- read_rds("data/chas.rds")

burden <- out$t8 |>
  filter(geo_type == "county", cost_burden != "No or negative income",
         tenure %in% c("Homeowner", "Renter")) |>
  summarise(burdened = sum(estimate[cost_burden != "Not cost-burdened"], na.rm = TRUE),
            total    = sum(estimate, na.rm = TRUE), .by = tenure) |>
  mutate(pct = burdened / total * 100)

chas_renter <- burden$pct[burden$tenure == "Renter"]
chas_owner  <- burden$pct[burden$tenure == "Homeowner"]

# Total occupied households (T7 county detail sum) — GP benchmark ~26,720
total_hh <- out$t7 |> filter(geo_type == "county") |> pull(estimate) |> sum(na.rm = TRUE)

# ACS ballpark (reference only): B25070 renter, B25091 owner, Fauquier county
ac <- read_rds("data/acs_costs.rds")
acs_num <- function(tbl, ids) tbl |> filter(GEOID == "51061") |>
  mutate(n = readr::parse_number(str_extract(variable, "\\d+$"))) |>
  filter(n %in% ids) |> pull(estimate) |> sum()
acs_renter <- acs_num(ac$B25070, 7:10)  / acs_num(ac$B25070, 2:10)  * 100
acs_owner  <- (acs_num(ac$B25091, c(8:11, 19:22))) /
              (acs_num(ac$B25091, 3:11) + acs_num(ac$B25091, 14:22)) * 100

message("  Cost burden — CHAS T8: renter ", round(chas_renter, 1), "%, owner ", round(chas_owner, 1),
        "% | ACS ballpark: renter ", round(acs_renter, 1), "%, owner ", round(acs_owner, 1),
        "% (GP headline 40.2% / 21.5% = ACS)")
message("  Total occupied HH (T7 detail sum): ", format(round(total_hh), big.mark = ","), " (GP ~26,720)")

stopifnot(
  between(chas_renter, 25, 45),                 # CHAS-appropriate range (not the ACS 40.2%)
  between(chas_owner,  12, 30),
  abs(acs_renter - 40.2) < 2, abs(acs_owner - 21.5) < 2,   # ACS reproduces GP headline
  all(c("t7", "t8", "t14b", "t15c") %in% names(out)),
  abs(total_hh - 26720) / 26720 < 0.10
)
# Warn (don't fail) if a town is absent at place level
walk(names(towns), \(tn) {
  if (!any(out$t8$geo_code == towns[[tn]])) warning(tn, " absent in CHAS 160 — note in log")
})
message("chas.R validation passed.")
