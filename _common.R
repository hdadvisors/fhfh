# Set global knitr chunk options

knitr::opts_chunk$set(
  echo = FALSE,
  warning = FALSE,
  error = FALSE,
  message = FALSE,
  fig.show = "hold",
  fig.asp = 0.618,
  fig.align = "left"
)

# Load core packages

library(tidyverse)
library(scales)
library(kableExtra)
library(formattable)
library(hdatools)
library(ggtext)

# hdatools::theme_hda() captions are element_markdown, which never wraps, so a long
# Sources + Notes caption clips at the right edge. Swap in a wrapping textbox with the same styling.
theme_hda <- function(...) {
  th  <- hdatools::theme_hda(...)
  cap <- th$plot.caption
  th + theme(plot.caption = ggtext::element_textbox_simple(
    family = cap$family, size = cap$size, colour = cap$colour,
    lineheight = cap$lineheight, margin = cap$margin, hjust = 0, vjust = 0
  ))
}

# Color palettes

hda_pal <- c(
  "#445ca9", # Blue
  "#8baeaa", # Green
  "#e9ab3f", # Yellow
  "#e76f52", # Coral
  "#a97a92", # Lavender
  "#8abc8e"  # Sea Green
)

cb_pal <- c(
  "Severely cost-burdened" = hda_pal[4],
  "Cost-burdened"         = hda_pal[3],
  "Not cost-burdened"     = "grey80"
)

# Geography constants (PLAN.md §4)
# GEOIDs resolved via tigris::places("VA") in Session 1 — never hardcoded from memory.

fauquier   <- "51061"
towns      <- c(warrenton = "5183136", bealeton = "5105336")  # resolved via tigris::places("VA", year=2023)
benchmarks <- c(culpeper = "51047", prince_william = "51153", loudoun = "51107")
virginia   <- "51"
town_zips  <- list(warrenton = c("20186", "20187"), bealeton = "22712")

# Caption helpers (PLAN.md §3)

acs_cap <- function(table, year = "2020–2024") {
  paste0(
    "**Source:** U.S. Census Bureau, ",
    year,
    " American Community Survey 5-year estimates, Table ",
    table,
    "."
  )
}

chas_cap <- function(table, year = "2018–2022") {
  paste0(
    "**Source:** HUD Comprehensive Housing Affordability Strategy (CHAS), ",
    year,
    " estimates, Table ",
    table,
    "."
  )
}

# Data vintages — read once from the rds files so captions/prose never go stale after a refresh.
# mls_through = date of the latest MLS snapshot; costar_through = latest CoStar quarter.
mls_through <- format(max(readr::read_rds("data/mls.rds")$active$snapshot_date), "%m/%d/%Y")
costar_through <- readr::read_rds("data/costar.rds")$quarterly |>
  dplyr::slice_max(year * 10 + qtr, n = 1) |>
  dplyr::mutate(lbl = paste(year, paste0("Q", qtr))) |>
  dplyr::pull(lbl)

mls_cap <- function(year_range = NULL, through = TRUE, type = "closed sales data") {
  base <- paste("**Source:** Bright MLS", type)
  if (!is.null(year_range)) base <- paste0(base, ", ", year_range)
  if (through) base <- paste0(base, " (data through ", mls_through, ")")
  paste0(base, ".")
}

qcew_cap <- function(year_range = "2015-2025", annual = TRUE) {
  paste0(
    "**Source:** U.S. Bureau of Labor Statistics, ",
    "Quarterly Census of Employment and Wages (QCEW), ",
    year_range,
    if (annual) " annual averages." else "."
  )
}

dec_cap <- function(years = "1990–2020")
  paste0("**Source:** U.S. Census Bureau, Decennial Census, ", years, ".")

pep_cap <- function(vintage = 2025)
  paste0("**Source:** U.S. Census Bureau, Population Estimates Program, Vintage ", vintage, ".")

bps_cap <- function(years = "2000–2025")
  paste0("**Source:** U.S. Census Bureau, Building Permits Survey, ", years, " annual.")

lodes_cap <- function(year = 2022)
  paste0("**Source:** U.S. Census Bureau, LEHD Origin-Destination Employment Statistics (LODES), ",
         year, ".")

# Note text, not a source line: use after "<br>**Note:** ".
cpi_cap <- function()
  "Real values use BLS CPI-U less shelter via FRED."

costar_cap <- function()
  paste0("**Source:** CoStar multifamily market data, quarterly, through ", costar_through, ".")

fmr_cap <- function(year = "FY2026")
  paste0("**Source:** HUD Fair Market Rents and Small Area FMRs, ", year, ".")

nhpd_cap <- function()
  "**Source:** National Housing Preservation Database (NHPD)."

pmms_cap <- function()
  "**Source:** Freddie Mac Primary Mortgage Market Survey (PMMS), 30-year fixed rate, via FRED."

# easements rows carry chapter + page
compplan_cap <- function(chapter, page)
  paste0("**Source:** Fauquier County Comprehensive Plan, ", chapter, ", p. ", page, ".")

ami_cap <- function(year = "FY2026")
  paste0("**Source:** HUD Section 8 Income Limits, ", year, ".")

pit_cap <- function()
  "**Source:** Foothills Housing Network Point-in-Time Count, 2018–2025."

vdoe_cap <- function()
  paste0("**Source:** VDOE Project HOPE-Virginia, McKinney-Vento ",
         "homeless student counts, 2020–21 to 2024–25.")

wc_cap <- function(release = 2025)
  paste0("**Source:** University of Virginia Weldon Cooper Center for Public Service, ",
         "Virginia Population Projections, ", release, " release.")

# Caption convention: one bold "**Source:**" line, or "**Sources:** A, yr. B, yr." when combining
# sources (write it by hand rather than pasting helpers together). Extra context goes on a new
# line: "<br>**Note:** ..." / "<br>**Notes:** ...".

# The caption helpers above emit markdown bold, which ggtext renders in ggplot captions but
# kableExtra::footnote() passes through literally. Convert before using one in a table footnote
# (and pass escape = FALSE so the tags survive).
tbl_note <- function(x) gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", x)

# High/Medium/Low reliability tiers from a 0–100 CV column (PLAN.md §3 thresholds 15/30).
# The .rds frames store `cv` on a 0–100 scale; hdatools::add_reliability() expects a *_cv
# column on a 0–1 proportion scale, so a thin local wrapper avoids mislabeling town cells.
flag_reliability <- function(df, cv_col = cv) {
  df |>
    mutate(reliability = case_when(
      {{ cv_col }} <= 15 ~ "High",
      {{ cv_col }} <= 30 ~ "Medium",
      {{ cv_col }} >  30 ~ "Low",
      TRUE               ~ NA_character_
    ))
}

# Scope ladder of cumulative housing need through 2050 (projections @fig-scope-ladder).
# Shared so exec-sum and conclusions quote the same totals as the projections chapter.
scope_ladder <- function() {
  wcoop <- readr::read_rds("data/wcoop.rds")
  gaps  <- readr::read_rds("data/gaps.rds")
  stock <- readr::read_rds("data/acs_stock.rds")
  asm   <- wcoop$assumptions
  horizon_yrs <- 2050 - asm$base_year

  grow_units <- wcoop$households$growth_avgsize[wcoop$households$year == 2050]
  vac_units  <- round(grow_units * asm$vacancy_allowance)
  # Rung 3 backlog: rental sub-80% AMI deficit (data) + 1/3 of ownership sub-80% shortfall (assumed)
  rg <- gaps$rental_gap
  og <- gaps$ownership_gap
  backlog_rent <- -sum(rg$surplus_deficit[rg$band %in% c("≤30% AMI", "30-50% AMI", "50-80% AMI")])
  own_sub80    <- -sum(og$surplus_deficit[og$band %in% c("ami30", "ami50", "ami80")])
  backlog_own  <- round(own_sub80 / 3)
  # Rung 4 replacement: assumption-driven (no demolition data), 0.25%/yr of the current stock
  total_units <- stock$b25001$estimate[stock$b25001$GEOID == fauquier]
  repl_rate   <- 0.0025
  repl_units  <- round(total_units * repl_rate * horizon_yrs)

  list(horizon_yrs = horizon_yrs, grow_units = grow_units, vac_units = vac_units,
       backlog_rent = backlog_rent, own_sub80 = own_sub80, backlog_own = backlog_own,
       backlog_tot = backlog_rent + backlog_own, total_units = total_units,
       repl_rate = repl_rate, repl_units = repl_units,
       lad_c1 = grow_units, lad_c2 = grow_units + vac_units,
       lad_c3 = grow_units + vac_units + backlog_rent + backlog_own,
       lad_c4 = grow_units + vac_units + backlog_rent + backlog_own + repl_units)
}

# Special function to apply str_wrap() to ordered factors

fct_wrap <- function(f, width) {
  fct_relabel(f, ~ str_wrap(., width = width))
}

# Set plot rendering options

if (knitr::is_html_output()) {

  knitr::opts_chunk$set(out.width = "100%")

} else {

  knitr::opts_chunk$set(dpi = 150)

}
