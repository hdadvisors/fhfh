# vdoe.R ----
# What:   VDOE (Project HOPE-Virginia) McKinney-Vento homeless student counts by school division.
#         Fauquier County Public Schools series 2020-21 … 2024-25, plus a statewide context frame.
# Source: data/raw/vdoe/*.xlsx (one file per school year; report layouts differ year to year)
# Output: data/vdoe.rds
#   NOTE: layouts drift — division-name and count columns are read BY POSITION (cols 2 & 3), not by
#   header name. 2020-21 is a different "child count" report (3 sheets + a title row). Suppression
#   flags "<" and "*" (and footnote "*"/"**" after some division names) coerce to NA via parse_number;
#   Fauquier is never suppressed.

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Per-file config. `sheet` uses actual sheet names (all character — a mixed name/index column would
# fail tibble's type check). 2020-21 has a title row 0 → skip = 1; the rest have the header on row 0.
files <- tribble(
  ~school_year, ~path,                                                   ~sheet,                  ~skip,
  "2020-21",    "data/raw/vdoe/2020-21-child-count.xlsx",                "Total VA Child Counts", 1L,
  "2021-22",    "data/raw/vdoe/LEA-totals-2021-22.xlsx",                 "Sheet1",                0L,
  "2022-23",    "data/raw/vdoe/LEA-totals-to-post-2022-23.xlsx",         "Sheet1",                0L,
  "2023-24",    "data/raw/vdoe/LEA-totals-to-post-2023-24.xlsx",         "Sheet1",                0L,
  "2024-25",    "data/raw/vdoe/2024-25-LEA-MV-Counts-for-posting.xlsx",  "Sheet1",                0L
)

## 2. Per-file reader (position-based; layout-agnostic) ----
read_vdoe <- function(school_year, path, sheet, skip) {
  read_excel(path, sheet = sheet, skip = skip) |>
    clean_names() |>
    rename(division = 2, count_raw = 3) |>                 # col 2 = division name, col 3 = count
    transmute(school_year,
              division = as.character(division),
              students = suppressWarnings(parse_number(as.character(count_raw))))  # "<"/"*" -> NA
}

all_divisions <- pmap_dfr(files, read_vdoe) |>
  filter(str_detect(division, regex("public schools", ignore_case = TRUE)))   # drops title/note rows

## 3. Fauquier series + statewide context ----
fauquier <- all_divisions |>
  filter(str_detect(division, regex("fauquier county public schools", ignore_case = TRUE))) |>
  arrange(school_year)

statewide <- all_divisions |> arrange(school_year, division)   # all LEAs; suppressed counts = NA

## 4. Write output ----
write_rds(
  list(fauquier = fauquier,
       statewide = statewide,
       source = "VDOE Project HOPE-Virginia, McKinney-Vento LEA homeless student counts"),
  "data/vdoe.rds"
)
message("Wrote data/vdoe.rds")

## 5. Validate — exact expected Fauquier series ----
out      <- read_rds("data/vdoe.rds")
expected <- c(`2020-21` = 191, `2021-22` = 135, `2022-23` = 101, `2023-24` = 100, `2024-25` = 92)
got      <- setNames(out$fauquier$students, out$fauquier$school_year)

message("  VDOE Fauquier: ", paste(names(got), got, sep = "=", collapse = " | "))
message("  Statewide divisions/year: ",
        paste(out$statewide |> count(school_year) |> pull(n), collapse = " | "))

stopifnot(
  nrow(out$fauquier) == 5,
  all(got[names(expected)] == expected),
  all(out$statewide |> count(school_year) |> pull(n) > 100)   # ~130+ divisions each year
)
message("vdoe.R validation passed.")
