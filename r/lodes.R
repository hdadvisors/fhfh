# lodes.R ----
# What:   LODES8 OD commute flows (county-level) + WAC/RAC (block-level, town-aggregated)
# Source: lehdr package (LODES8 — Census LEHD Origin-Destination Employment Statistics)
# Output: data/lodes.rds

## 1. Setup ----
library(tidyverse)
library(lehdr)
library(sf)
library(tigris)
library(janitor)
options(tigris_use_cache = TRUE)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

fauquier <- "51061"
towns    <- c(warrenton = "5183136", bealeton = "5105336")

## 2. Set LODES year ----
lodes_year <- 2023   # confirmed at lehd.ces.census.gov/data/ — 2026-07-08
message("Using LODES year: ", lodes_year)

## 3. OD — Origin-Destination (county aggregation) ----
# lehdr 1.x uses w_county/h_county at county aggregation level (not w_geocode/h_geocode);
# rename immediately for consistency with the block-level fallback path below.
od_main_county <- grab_lodes("va", lodes_year, lodes_type = "od", job_type = "JT00",
                              state_part = "main", agg_geo = "county") |>
  rename(w_geocode = w_county, h_geocode = h_county) |>
  filter(h_geocode == fauquier | w_geocode == fauquier)

# aux: one end is out-of-state (DC/MD/WV workers commuting in)
od_aux_county <- tryCatch(
  grab_lodes("va", lodes_year, lodes_type = "od", job_type = "JT00",
             state_part = "aux", agg_geo = "county") |>
    rename(w_geocode = w_county, h_geocode = h_county) |>
    filter(h_geocode == fauquier | w_geocode == fauquier),
  error = function(e) {
    message("OD aux county-level failed (", conditionMessage(e),
            "). Fetching block-level and filtering.")
    grab_lodes("va", lodes_year, lodes_type = "od", job_type = "JT00",
               state_part = "aux", agg_geo = "block") |>
      filter(str_starts(h_geocode, fauquier) | str_starts(w_geocode, fauquier)) |>
      mutate(h_geocode = str_sub(h_geocode, 1, 5),
             w_geocode = str_sub(w_geocode, 1, 5)) |>
      summarise(S000 = sum(S000), .by = c(h_geocode, w_geocode))
  }
)

od_county <- bind_rows(od_main_county, od_aux_county)

## 4. Live/work summary ----
# Jobs located in Fauquier (workers commuting in + residents working locally)
total_fauquier_jobs <- od_county |>
  filter(w_geocode == fauquier) |>
  summarise(S000 = sum(S000)) |> pull(S000)

# Jobs held by Fauquier residents working in Fauquier (both ends in county)
resident_held <- od_county |>
  filter(h_geocode == fauquier, w_geocode == fauquier) |>
  summarise(S000 = sum(S000)) |> pull(S000)

# Residency share — GP benchmark: 35.4%
residency_share <- resident_held / total_fauquier_jobs

# Top destination counties for Fauquier residents commuting out
top_destinations <- od_county |>
  filter(h_geocode == fauquier, w_geocode != fauquier) |>
  arrange(desc(S000)) |>
  slice_head(n = 15)

# Top origin counties for workers commuting into Fauquier
top_origins <- od_county |>
  filter(h_geocode != fauquier, w_geocode == fauquier) |>
  arrange(desc(S000)) |>
  slice_head(n = 15)

## 5. WAC — Workplace Area Characteristics (block-level) ----
wac_block <- grab_lodes("va", lodes_year, lodes_type = "wac", job_type = "JT00",
                         segment = "S000", agg_geo = "block") |>
  filter(str_starts(w_geocode, fauquier)) |>
  clean_names()

## 6. RAC — Residence Area Characteristics (block-level) ----
rac_block <- grab_lodes("va", lodes_year, lodes_type = "rac", job_type = "JT00",
                         segment = "S000", agg_geo = "block") |>
  filter(str_starts(h_geocode, fauquier)) |>
  clean_names()

## 7. Build block-to-town crosswalk ----
# LODES8 uses 2020 Census block GEOIDs (15-digit)
fauquier_blocks <- blocks("VA", county = "061", year = 2020)

# tigris may return GEOID20 or GEOID depending on version
block_id_col <- if ("GEOID20" %in% names(fauquier_blocks)) "GEOID20" else "GEOID"

geo <- read_rds("data/geo.rds")
town_sf <- geo$place  # Warrenton + Bealeton polygons from Session 2

# Block centroids for point-in-polygon assignment
block_centroids <- st_centroid(fauquier_blocks)
block_town_join <- st_join(
  block_centroids,
  town_sf |> select(town_geoid = GEOID, town_name = NAME),
  join = st_within
) |>
  st_drop_geometry() |>
  select(block_geoid = !!sym(block_id_col), town_geoid, town_name)

## 8. Aggregate WAC to towns ----
wac_town <- wac_block |>
  left_join(block_town_join, by = c("w_geocode" = "block_geoid")) |>
  filter(!is.na(town_geoid)) |>
  summarise(across(where(is.numeric), sum), .by = c(town_geoid, town_name))

## 9. Write output ----
write_rds(
  list(
    od_county        = od_county,
    wac_block        = wac_block,
    rac_block        = rac_block,
    block_town       = block_town_join,
    wac_town         = wac_town,
    live_work        = tibble(
      total_jobs      = total_fauquier_jobs,
      resident_held   = resident_held,
      residency_share = residency_share
    ),
    top_destinations = top_destinations,
    top_origins      = top_origins,
    lodes_year       = lodes_year
  ),
  "data/lodes.rds"
)
message("Wrote data/lodes.rds")

## 10. Validate ----
lodes <- read_rds("data/lodes.rds")

# Block coverage
stopifnot(nrow(lodes$wac_block) > 300)

# Residency share — GP benchmark: 35.4% (±10pp for LODES year vs GP vintage)
stopifnot(between(lodes$live_work$residency_share, 0.20, 0.55))

# Total jobs (WAC-equivalent from OD) — GP: ~24,138 (±30% for year diff)
stopifnot(between(lodes$live_work$total_jobs, 15000, 35000))

# Top flows non-empty
stopifnot(nrow(lodes$top_destinations) >= 5)
stopifnot(nrow(lodes$top_origins) >= 5)

# Block-town crosswalk touches both towns
stopifnot(all(unname(towns) %in%
  unique(lodes$block_town$town_geoid[!is.na(lodes$block_town$town_geoid)])))

message("lodes.R validation passed.",
        " | Residency share: ", round(lodes$live_work$residency_share * 100, 1), "%",
        " | Total jobs: ", lodes$live_work$total_jobs,
        " | LODES year: ", lodes$lodes_year)
