# mls.R ----
# What:   Tidy Bright MLS sales + listings + rentals; splice VAR/GP sources for 2016–2021;
#         ingest Bright MLS published monthly summary stats (2022+, 3 geographies)
# Source: data/raw/mls/mls_sales_*.csv (2022+), data/raw/mls/var_*.xlsx (2016–2021),
#         data/gp_appendix.rds ($sales), data/raw/mls/mls_active_*.csv, mls_rentals_*.csv,
#         data/raw/mls/mls_monthly_{sales,listings,inventory}_{fauquier,warrenton,bealeton}.csv
# Output: data/mls.rds (frames incl. monthly_summary — Bright MLS monthly summary, 2022+)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
library(lubridate)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

town_zips <- c("20186", "20187", "22712")

## 2. MLS sales transactions (2022+) ----
message("Reading MLS sales CSVs (2022–2026 YTD)...")

sales_files <- list.files("data/raw/mls", pattern = "mls_sales_.*\\.csv", full.names = TRUE)
message("  Files found: ", paste(basename(sales_files), collapse = ", "))

sales_raw <- map_dfr(sales_files, \(f) {
  read_csv(f, show_col_types = FALSE) |>
    mutate(source_file = basename(f))
}) |>
  clean_names()

message("  Transactions loaded: ", nrow(sales_raw))
message("  Columns: ", paste(names(sales_raw)[1:min(12, ncol(sales_raw))], collapse = ", "))

# Actual Bright MLS column names: sales_price, sales_date, list_price, new_resale
sales <- sales_raw |>
  mutate(
    close_price = parse_number(as.character(sales_price)),
    list_price  = parse_number(as.character(list_price)),
    close_date  = mdy(sales_date),
    year        = year(close_date),
    month       = month(close_date),
    zip         = as.character(parse_number(as.character(zip))),  # 5-digit ZIP column
    dom         = parse_number(as.character(days_on_market)),      # native Bright MLS DOM field
    sq_ft_total = parse_number(as.character(sq_ft_total)),
    acres       = parse_number(as.character(acres)),
    year_built  = parse_number(as.character(year_built))
  ) |>
  filter(!is.na(close_date), !is.na(close_price), close_price > 0)

message("  Parsed transactions: ", nrow(sales),
        " (", min(sales$year), "–", max(sales$year), ")")

## 3. VAR monthly data (2016–2021) ----
message("Reading VAR xlsx files...")

var_msp_raw <- read_excel("data/raw/mls/var_msp_2016_2026_ytd.xlsx", col_names = FALSE)
var_sal_raw <- read_excel("data/raw/mls/var_sales_2016_2026_ytd.xlsx", col_names = FALSE)

# Row containing Fauquier County identified by col 1 label
fauquier_msp_row <- var_msp_raw |>
  filter(str_detect(`...1`, regex("fauquier", ignore_case = TRUE)))
fauquier_sal_row <- var_sal_raw |>
  filter(str_detect(`...1`, regex("fauquier", ignore_case = TRUE)))

stopifnot(nrow(fauquier_msp_row) == 1, nrow(fauquier_sal_row) == 1)

# Build date sequence by column position (col 2 = Jan 2016).
# Labels are unreliable — July 2020 is mislabeled "2021 - Jul" in the sales file.
date_seq_msp <- seq(as.Date("2016-01-01"), by = "month",
                    length.out = ncol(var_msp_raw) - 1)
date_seq_sal <- seq(as.Date("2016-01-01"), by = "month",
                    length.out = ncol(var_sal_raw) - 1)

var_monthly_msp <- tibble(
  date         = date_seq_msp,
  median_price = parse_number(as.character(unlist(fauquier_msp_row[-1])))
) |>
  mutate(year = year(date), month = month(date))

var_monthly_sal <- tibble(
  date        = date_seq_sal,
  sales_count = parse_number(as.character(unlist(fauquier_sal_row[-1])))
) |>
  mutate(year = year(date), month = month(date))

# Restrict VAR to 2016–2021 (MLS covers 2022+)
var_monthly <- var_monthly_msp |>
  left_join(var_monthly_sal, by = c("date", "year", "month")) |>
  filter(year <= 2021, !is.na(median_price))

message("  VAR monthly rows (2016–2021): ", nrow(var_monthly))

## 4. Monthly price series — VAR splice to MLS ----
message("Building monthly price series...")

mls_monthly <- sales |>
  filter(year >= 2022) |>
  summarize(
    median_price = median(close_price, na.rm = TRUE),
    sales_count  = n(),
    .by = c(year, month)
  ) |>
  mutate(date = make_date(year, month, 1))

monthly <- bind_rows(
  var_monthly |> mutate(source = "VAR"),
  mls_monthly |> mutate(source = "MLS")
) |>
  arrange(date)

message("  Monthly rows: ", nrow(monthly),
        " (", min(monthly$year), "–", max(monthly$year), ")")

## 5. Annual series — GP appendix splice to MLS ----
message("Building annual series (GP 2016–2021 / MLS 2022+)...")

gp <- read_rds("data/gp_appendix.rds")
message("  GP appendix frames: ", paste(names(gp), collapse = ", "))

# Confirmed column names from gp_appendix.rds: year, county, sales, median_sold_price, source
gp_annual <- gp$sales |>
  filter(county == "Fauquier", year <= 2021) |>
  select(year, sales_count = sales, median_price = median_sold_price)

mls_annual <- sales |>
  filter(year >= 2022) |>
  summarize(
    median_price = median(close_price, na.rm = TRUE),
    sales_count  = n(),
    .by = year
  )

annual <- bind_rows(
  gp_annual |> mutate(source = "GP"),
  mls_annual |> mutate(source = "MLS")
) |>
  arrange(year)

message("  Annual rows: ", nrow(annual),
        " (", min(annual$year), "–", max(annual$year), ")")

## 6. Active listings snapshot ----
message("Reading active listings snapshot...")

active_files <- list.files("data/raw/mls", pattern = "mls_active", full.names = TRUE)
active_raw   <- map_dfr(active_files, \(f) read_csv(f, show_col_types = FALSE)) |>
  clean_names()

active <- active_raw |>
  mutate(
    list_price = parse_number(as.character(list_price)),
    list_date  = mdy(sales_date)   # in active file sales_date = listing date
  ) |>
  filter(!is.na(list_price), list_price > 0)

message("  Active listings: ", nrow(active), " (benchmark ~218)")

## 7. Rental transactions ----
message("Reading rental CSVs...")

rental_files <- list.files("data/raw/mls", pattern = "mls_rentals", full.names = TRUE)

rentals_raw <- map_dfr(rental_files, \(f) {
  read_csv(f, show_col_types = FALSE) |>
    mutate(source_file = basename(f))
}) |>
  clean_names()

rentals <- rentals_raw |>
  mutate(
    lease_price = parse_number(as.character(sales_price)),
    lease_date  = mdy(sales_date),
    year        = year(lease_date),
    month       = month(lease_date)
  ) |>
  filter(!is.na(lease_date), !is.na(lease_price), lease_price > 0)

message("  Rental records: ", nrow(rentals),
        " (", min(rentals$year), "–", max(rentals$year), ")")

## 7b. Monthly summary statistics (Bright MLS published, 2022+) ----
# Three metric files (sales / listings / inventory) × three geographies
# (Fauquier = county-wide incl. all towns/CDPs, Warrenton, Bealeton), monthly Jan 2022+.
# Supplies the monthly active-listings / new-listings / months-of-supply / days-to-sell
# series the transaction-level data cannot provide. `grain` column is future-proofing: a
# coarser Bealeton re-pull (quarterly/annual) can be appended without restructuring.
message("Reading MLS monthly summary CSVs...")

summary_geos <- c(Fauquier = "fauquier", Warrenton = "warrenton", Bealeton = "bealeton")

read_monthly_metric <- function(geo_slug, metric) {
  path <- file.path("data/raw/mls", paste0("mls_monthly_", metric, "_", geo_slug, ".csv"))
  read_csv(path, show_col_types = FALSE) |>
    clean_names() |>
    rename(month_label = month)   # "Month" header → month; keep raw label for the join
}

monthly_summary <- imap_dfr(summary_geos, \(geo_slug, geo_name) {
  sales_df <- read_monthly_metric(geo_slug, "sales") |>
    transmute(month_label,
              sales_n      = sales_number_of,
              median_price = parse_number(as.character(sale_price_median)))
  listings_df <- read_monthly_metric(geo_slug, "listings") |>
    transmute(month_label,
              active_listings = active_listings_number_of,
              new_listings    = number_of_new_listings)
  inventory_df <- read_monthly_metric(geo_slug, "inventory") |>
    transmute(month_label,
              days_to_sell  = days_to_sell_median,
              months_supply = months_of_inventory)

  sales_df |>
    left_join(listings_df,  by = "month_label") |>
    left_join(inventory_df, by = "month_label") |>
    mutate(geography = geo_name,
           date      = my(month_label),   # "Jan 2022" → 2022-01-01
           year      = year(date),
           month     = month(date),
           grain     = "monthly")
}) |>
  select(geography, date, year, month, grain,
         sales_n, median_price, active_listings, new_listings,
         days_to_sell, months_supply) |>
  arrange(geography, date)

message("  monthly_summary rows: ", nrow(monthly_summary),
        " (", n_distinct(monthly_summary$geography), " geographies × ",
        n_distinct(monthly_summary$date), " months, ",
        format(min(monthly_summary$date)), "–", format(max(monthly_summary$date)), ")")

## 8. New-construction vs resale attributes (2022+ transactions) ----
# Supports Ch 1 Fig 6 ("large homes on large lots" / missing-middle validation).
message("Building new-vs-resale attribute summary...")

new_vs_resale <- sales |>
  filter(year >= 2022) |>
  mutate(construction = case_when(
    str_detect(new_resale, regex("new",    ignore_case = TRUE)) ~ "New construction",
    str_detect(new_resale, regex("resale", ignore_case = TRUE)) ~ "Resale",
    TRUE ~ NA_character_)) |>
  filter(!is.na(construction)) |>
  summarize(n = n(),
            median_price = median(close_price, na.rm = TRUE),
            median_sqft  = median(sq_ft_total, na.rm = TRUE),
            median_acres = median(acres,       na.rm = TRUE),
            median_yrblt = median(year_built,  na.rm = TRUE),
            .by = c(year, construction))

message("  new_vs_resale rows: ", nrow(new_vs_resale),
        " (", n_distinct(new_vs_resale$year), " years × 2 groups)")

## 8b. Aggregate frames for Ch 3a (MLS 2022+) ----
message("Building Ch 3a aggregate frames (annual_zip, dom_annual, sales_bands)...")

# Town-zip annual median price (MLS 2022+). town_zips = c("20186","20187","22712").
annual_zip <- sales |>
  filter(year >= 2022, zip %in% town_zips) |>
  mutate(town = case_when(
    zip %in% c("20186", "20187") ~ "Warrenton",
    zip == "22712"               ~ "Bealeton",
    TRUE ~ NA_character_)) |>
  filter(!is.na(town)) |>
  summarize(median_price = median(close_price, na.rm = TRUE), n = n(),
            .by = c(year, town))

# Days-on-market summary (2022+) from the native MLS DOM field.
dom_annual <- sales |>
  filter(year >= 2022, !is.na(dom), dom >= 0) |>
  summarize(median_dom = median(dom, na.rm = TRUE), n = n(), .by = year) |>
  arrange(year)

# Sales by price band (2022+). Bands aligned to the affordability narrative.
band_brks <- c(-Inf, 250e3, 350e3, 500e3, 750e3, Inf)
band_labs <- c("<$250k", "$250-350k", "$350-500k", "$500-750k", "$750k+")
sales_bands <- sales |>
  filter(year >= 2022) |>
  mutate(band = cut(close_price, band_brks, band_labs, right = FALSE)) |>
  summarize(n = n(), .by = c(year, band)) |>
  mutate(share = n / sum(n), .by = year) |>
  arrange(year, band)

message("  annual_zip rows: ", nrow(annual_zip),
        " | dom_annual rows: ", nrow(dom_annual),
        " | sales_bands rows: ", nrow(sales_bands))

## 9. Write output ----
write_rds(
  list(monthly = monthly, annual = annual, active = active, rentals = rentals,
       new_vs_resale = new_vs_resale,
       annual_zip = annual_zip, dom_annual = dom_annual, sales_bands = sales_bands,
       monthly_summary = monthly_summary),
  "data/mls.rds"
)
message("Wrote data/mls.rds")

## 10. Validate ----
out <- read_rds("data/mls.rds")

stopifnot(
  min(out$monthly$year) == 2016,
  max(out$monthly$year) >= 2025,
  nrow(out$active) >= 100
)

# new_vs_resale: both groups present in recent years; New larger/pricier than Resale
nvr <- out$new_vs_resale
stopifnot(all(c("New construction", "Resale") %in% nvr$construction))
nvr_recent <- nvr |> filter(year >= 2022) |>
  summarize(median_price = weighted.mean(median_price, n),
            median_sqft  = weighted.mean(median_sqft,  n),
            .by = construction)
new_row    <- nvr_recent |> filter(construction == "New construction")
resale_row <- nvr_recent |> filter(construction == "Resale")
if (!(new_row$median_price > resale_row$median_price))
  warning("New median price not above resale — check new_vs_resale")
if (!(new_row$median_sqft > resale_row$median_sqft))
  warning("New median sqft not above resale — check new_vs_resale")
message("  new_vs_resale: New $", format(round(new_row$median_price), big.mark = ","),
        " / ", round(new_row$median_sqft), " sqft vs Resale $",
        format(round(resale_row$median_price), big.mark = ","),
        " / ", round(resale_row$median_sqft), " sqft (2022+ wtd)")

ann_2025 <- out$annual |> filter(year == 2025) |> pull(median_price)
if (length(ann_2025) > 0) {
  if (!between(ann_2025, 550000, 750000))
    warning("2025 annual median $", round(ann_2025, 0),
            " outside expected range $550k–$750k")
  message("  2025 annual median: $", format(round(ann_2025, 0), big.mark = ","),
          " (benchmark ~$645,250)")
}

median_rent <- median(out$rentals$lease_price, na.rm = TRUE)

# New Ch 3a aggregate frames: non-empty; price-bands sum to 1 per year.
stopifnot(
  nrow(out$annual_zip)  > 0,
  nrow(out$dom_annual)  > 0,
  nrow(out$sales_bands) > 0
)
band_sums <- out$sales_bands |> summarize(s = sum(share), .by = year)
if (!all(abs(band_sums$s - 1) < 1e-9))
  warning("sales_bands shares do not sum to 1 within every year")
message("  annual_zip: ", nrow(out$annual_zip), " rows (",
        paste(sort(unique(out$annual_zip$town)), collapse = "/"), "), ",
        min(out$annual_zip$year), "–", max(out$annual_zip$year))
message("  dom_annual: median DOM ", min(out$dom_annual$year), "=",
        out$dom_annual$median_dom[out$dom_annual$year == min(out$dom_annual$year)],
        " → ", max(out$dom_annual$year), "=",
        out$dom_annual$median_dom[out$dom_annual$year == max(out$dom_annual$year)])
message("  sales_bands: bands sum to 1 per year = ", all(abs(band_sums$s - 1) < 1e-9))

# monthly_summary: structure + reconciliation vs transaction-derived series
ms <- out$monthly_summary
stopifnot(
  setequal(unique(ms$geography), c("Fauquier", "Warrenton", "Bealeton")),
  nrow(ms) == 162,                              # 3 geographies × 54 months
  min(ms$date) == as.Date("2022-01-01"),
  max(ms$date) == as.Date("2026-06-01")
)
fau_ms <- ms |> filter(geography == "Fauquier")
stopifnot(
  nrow(fau_ms) == 54,
  !anyNA(fau_ms$sales_n),
  !anyNA(fau_ms$active_listings),
  !anyNA(fau_ms$months_supply)
)

# Investigate-first reconciliation: Bright MLS published summary (all residential) vs
# the transaction-derived monthly series (mls_sales_*.csv, MLS 2022+). Report only —
# do NOT re-base published figures here until the divergence is understood.
recon <- fau_ms |>
  select(date, year, summary_n = sales_n, summary_price = median_price) |>
  inner_join(
    out$monthly |> filter(source == "MLS") |>
      select(date, derived_n = sales_count, derived_price = median_price),
    by = "date"
  )
recon_yr <- recon |>
  summarize(summary_n = sum(summary_n), derived_n = sum(derived_n), .by = year) |>
  mutate(pct_gap = (summary_n - derived_n) / derived_n)

message("  monthly_summary reconciliation — Fauquier sales counts (summary vs transaction-derived):")
pwalk(recon_yr, \(year, summary_n, derived_n, pct_gap)
      message(sprintf("    %d: summary %d vs derived %d (%+.1f%%)",
                      as.integer(year), as.integer(summary_n),
                      as.integer(derived_n), 100 * pct_gap)))

if (any(abs(recon_yr$pct_gap) > 0.10))
  warning("Summary vs transaction sales counts diverge >10% in ",
          sum(abs(recon_yr$pct_gap) > 0.10), " year(s) — likely a Type/property-class ",
          "filter in the mls_sales exports; reconcile before re-basing sales volume.")

price_mad <- mean(abs(recon$summary_price - recon$derived_price) / recon$derived_price)
message(sprintf("  monthly_summary median-price mean abs %% diff vs derived: %.1f%%",
                100 * price_mad))

message("mls.R validation passed.")
message("  Monthly rows: ", nrow(out$monthly))
message("  Annual rows:  ", nrow(out$annual))
message("  Active listings: ", nrow(out$active))
message("  Rental records:  ", nrow(out$rentals))
message("  Monthly summary rows: ", nrow(out$monthly_summary), " (",
        paste(sort(unique(out$monthly_summary$geography)), collapse = "/"), ")")
message("  Median rental price: $", format(round(median_rent, 0), big.mark = ","),
        " (benchmark ~$2,450)")
