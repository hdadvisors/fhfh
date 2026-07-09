# easements.R ----
# What:   Service district and conservation easement stats extracted from the
#         Fauquier County Comprehensive Plan chapter PDFs in background/.
#         Values are transcribed from static PDFs; this script is a manifest,
#         not a live data pull.
# Source: Fauquier County Comprehensive Plan (various chapters):
#         background/fauquier-county-comp-plan-ch1b.pdf
#         background/fauquier-county-comp-plan-ch3b.pdf
#         background/fauquier-county-comp-plan-ch6-bealeton.pdf
#         background/fauquier-county-comp-plan-ch6-warrenton.pdf
# Output: data/easements.rds — single tibble of cited stats + page references

## 1. Setup ----
library(tidyverse)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Build tibble ----

easements <- tribble(
  ~category,                    ~stat_name,                         ~value,   ~value_chr,                         ~unit,         ~chapter,    ~page,
  # ── Service district build-out capacity (ch3b p.11) ──────────────────────────────
  "service_district_buildout",  "total_capacity_units",             19776,    NA,                                 "units",       "ch3b",      11L,
  "service_district_buildout",  "units_built_as_of_2010",           11395,    NA,                                 "units",       "ch3b",      11L,
  "service_district_buildout",  "units_unbuilt_capacity",            8381,    NA,                                 "units",       "ch3b",      11L,
  "service_district_buildout",  "persons_per_hh_2010",                2.91,   NA,                                 "pph",         "ch3b",      11L,
  "service_district_buildout",  "projected_new_residents_at_capacity", 24389, NA,                                 "persons",     "ch3b",      11L,
  "service_district_buildout",  "weldon_cooper_pop_2045_projection", 88330,   NA,                                 "persons",     "ch3b",      11L,
  "service_district_buildout",  "county_pop_in_service_areas_2010",  33128,   NA,                                 "persons",     "ch3b",      11L,
  "service_district_buildout",  "county_pop_2010",                   65203,   NA,                                 "persons",     "ch3b",      11L,

  # ── Housing production by location (ch3b p.7) ────────────────────────────────────
  "housing_production",         "rural_share_new_units_1980s_1990s",  53,     NA,                                 "pct",         "ch3b",       7L,
  "housing_production",         "rural_share_new_units_post_2000",    35,     NA,                                 "pct",         "ch3b",       7L,
  "housing_production",         "permits_total_2001_2018",           7110,    NA,                                 "permits",     "ch3b",       7L,
  "housing_production",         "permits_sfd_share_2001_2018",        97,     NA,                                 "pct",         "ch3b",       7L,

  # ── Bealeton SD acreages (ch6-bealeton p.29 Table BE-2) ─────────────────────────
  "bealeton_sd_acreages",       "commercial_office_mixed_use",         92,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "town_center",                         84,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "mixed_use",                           36,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "institutional_office_mixed_use",      32,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "flex_industrial",                    149,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "low_density_residential",            984,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "medium_density_residential",         346,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "high_density_residential",            72,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "residential_no_sewer_water",         206,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "park_open_space",                    129,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "virginia_railway_express",             2,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "school_church_fire_rescue_rec",      203,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "school_expansion_area",               28,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "fema_floodplain",                    230,    NA,                                 "acres",       "ch6_beal",  29L,
  "bealeton_sd_acreages",       "total",                             2593,    NA,                                 "acres",       "ch6_beal",  29L,

  # ── Remington SD acreages (ch6-bealeton p.38 Table RE-1) ────────────────────────
  "remington_sd_acreages",      "industrial",                         446,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "light_industrial_employment_center", 402,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "residential_high_density",            14,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "residential_medium_density",          48,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "residential_low_density",            918,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "park_open_space",                    176,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "park_open_space_floodplain",         308,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "school",                              52,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "wastewater_treatment_facility",       10,    NA,                                 "acres",       "ch6_beal",  38L,
  "remington_sd_acreages",      "total",                             2374,    NA,                                 "acres",       "ch6_beal",  38L,

  # ── Warrenton SD housing stats (ch6-warrenton p.4) ──────────────────────────────
  "warrenton_sd_stats",         "houses_in_sd_unincorporated",        1480,   NA,                                 "units",       "ch6_warr",   4L,
  "warrenton_sd_stats",         "houses_added_last_10yr",             1179,   NA,                                 "units",       "ch6_warr",   4L,
  "warrenton_sd_stats",         "share_of_county_growth",               30,   NA,                                 "pct",         "ch6_warr",   4L,
  "warrenton_sd_stats",         "town_pop_1990",                      4830,   NA,                                 "persons",     "ch6_warr",   4L,
  "warrenton_sd_stats",         "town_pop_2000",                      6670,   NA,                                 "persons",     "ch6_warr",   4L,
  "warrenton_sd_stats",         "town_pop_growth_1990_2000_pct",        38,   NA,                                 "pct",         "ch6_warr",   4L,
  "warrenton_sd_stats",         "county_pop_1990",                   48714,   NA,                                 "persons",     "ch6_warr",   4L,
  "warrenton_sd_stats",         "county_pop_2000",                   55139,   NA,                                 "persons",     "ch6_warr",   4L,
  "warrenton_sd_stats",         "county_pop_growth_1990_2000_pct",      13,   NA,                                 "pct",         "ch6_warr",   4L,
  "warrenton_sd_stats",         "county_housing_1990",               16509,   NA,                                 "units",       "ch6_warr",   4L,
  "warrenton_sd_stats",         "county_housing_2000",               19842,   NA,                                 "units",       "ch6_warr",   4L,
  "warrenton_sd_stats",         "town_housing_1990",                  1949,   NA,                                 "units",       "ch6_warr",   4L,
  "warrenton_sd_stats",         "town_housing_2000",                  2658,   NA,                                 "units",       "ch6_warr",   4L,

  # ── Conservation easements (ch6-warrenton p.11, 13) ─────────────────────────────
  "conservation_easement",      "st_leonards_farm_easement_acres",    800,    NA,                                 "acres",       "ch6_warr",  13L,
  "conservation_easement",      "st_leonards_farm_lots_clustered",     41,    NA,                                 "lots",        "ch6_warr",  11L,
  "conservation_easement",      "st_leonards_farm_north_side_lots",    48,    NA,                                 "lots",        "ch6_warr",  13L,
  "conservation_easement",      "st_leonards_farm_easement_holder",    NA,    "Virginia Outdoor Foundation",      NA,            "ch6_warr",  13L,
  "conservation_easement",      "odec_dev_rights_purchase_fund",       1.5,   NA,                                 "million USD", "ch6_beal",  31L,
  "conservation_easement",      "odec_purchase_radius_miles",          5,     NA,                                 "miles",       "ch6_beal",  31L,

  # ── Utility/infrastructure capacity ─────────────────────────────────────────────
  "utility_capacity",           "bealeton_wsa_water_capacity_mgd",    1.3,    NA,                                 "MGD",         "ch6_beal",  17L,
  "utility_capacity",           "bealeton_remington_opal_wwtp_mgd",   2.0,    NA,                                 "MGD",         "ch6_beal",  31L,
  "utility_capacity",           "remington_water_wells_gpd",        104000,   NA,                                 "GPD",         "ch6_beal",  31L,
  "utility_capacity",           "remington_standpipe_gal",          397000,   NA,                                 "gallons",     "ch6_beal",  31L,
  "utility_capacity",           "warrenton_water_treatment_mgd",      2.0,    NA,                                 "MGD",         "ch6_warr",   7L,
  "utility_capacity",           "warrenton_water_utilization_pct",     48,    NA,                                 "pct",         "ch6_warr",   7L,
  "utility_capacity",           "warrenton_wwtp_capacity_mgd",        2.5,    NA,                                 "MGD",         "ch6_warr",   8L,
  "utility_capacity",           "warrenton_avg_daily_sewage_mgd",     0.86,   NA,                                 "MGD",         "ch6_warr",   8L,
  "utility_capacity",           "warrenton_sd_reserved_sewer_units",  400,    NA,                                 "units",       "ch6_warr",   8L,

  # ── Service district count and geography (ch1b p.12) ────────────────────────────
  "service_district_geography", "n_service_districts",                 8,     NA,                                 "districts",   "ch1b",      12L,
  "service_district_geography", "rural_land_share_of_county",         90,     NA,                                 "pct",         "ch1b",      11L
)

## 3. Write output ----
write_rds(easements, "data/easements.rds")
message("Wrote data/easements.rds — ", nrow(easements), " rows across ",
        n_distinct(easements$category), " categories")

## 4. Validate ----
e <- read_rds("data/easements.rds")

stopifnot(nrow(e) > 0)
stopifnot(all(c("category", "stat_name", "value", "unit", "chapter", "page") %in% names(e)))

# Service district build-out capacity cross-check
cap   <- e$value[e$stat_name == "total_capacity_units"]
built <- e$value[e$stat_name == "units_built_as_of_2010"]
unbuilt_check <- e$value[e$stat_name == "units_unbuilt_capacity"]
stopifnot(cap - built == unbuilt_check)   # 19776 - 11395 == 8381

# Bealeton total acreage cross-check
beal_parts <- e |>
  filter(category == "bealeton_sd_acreages", stat_name != "total") |>
  pull(value) |>
  sum(na.rm = TRUE)
beal_total <- e$value[e$stat_name == "total" & e$category == "bealeton_sd_acreages"]
stopifnot(beal_parts == beal_total)   # should equal 2593

# Remington total acreage cross-check
rem_parts <- e |>
  filter(category == "remington_sd_acreages", stat_name != "total") |>
  pull(value) |>
  sum(na.rm = TRUE)
rem_total <- e$value[e$stat_name == "total" & e$category == "remington_sd_acreages"]
stopifnot(rem_parts == rem_total)   # should equal 2374

message("easements.R validation passed.")
