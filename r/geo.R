# geo.R ----
# What:   Study-area boundary files for the orientation map (Ch 1 Fig 1) and sf joins
# Source: tigris (Census TIGER/Line cartographic boundary files, 2023 vintage)
# Output: data/geo.rds

## 1. Setup ----
library(tidyverse)
library(tigris)
library(sf)
options(tigris_use_cache = TRUE)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")

## 2. County boundaries (Fauquier + 3 benchmarks) ----
county_sf <- counties("VA", year = 2023, cb = TRUE) |>
  filter(GEOID %in% c(fauquier, unname(benchmarks)))

message("County rows: ", nrow(county_sf))

## 3. Place boundaries (Warrenton town + Bealeton CDP) ----
place_sf <- places("VA", year = 2023, cb = TRUE) |>
  filter(GEOID %in% unname(towns))

message("Place rows: ", nrow(place_sf))

## 4. Virginia state boundary ----
va_sf <- states(cb = TRUE, year = 2023) |>
  filter(STATEFP == "51")

message("State rows: ", nrow(va_sf))

## 5. Write output ----
write_rds(list(county = county_sf, place = place_sf, state = va_sf), "data/geo.rds")
message("Wrote data/geo.rds")

## 6. Validate ----
geo <- read_rds("data/geo.rds")
stopifnot(
  nrow(geo$county) == 4,   # fauquier + 3 benchmarks
  nrow(geo$place)  == 2,   # warrenton + bealeton
  nrow(geo$state)  == 1    # VA
)
message("geo.R validation passed.")
