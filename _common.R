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

acs_cap <- function(table, year = "2020-2024") {
  paste0(
    "**Source:** U.S. Census Bureau, ",
    year,
    " American Community Survey 5-year estimates, Table ",
    table,
    "."
  )
}

chas_cap <- function(table, year = "2018-2022") {
  paste0(
    "**Source:** HUD Comprehensive Housing Affordability Strategy (CHAS), ",
    year,
    " estimates, Table ",
    table,
    "."
  )
}

mls_cap <- function(year_range = NULL) {
  base <- "**Source:** Bright MLS closed sales data"
  if (!is.null(year_range)) paste0(base, ", ", year_range, ".") else paste0(base, ".")
}

qcew_cap <- function(year_range = "2015-2025") {
  paste0(
    "**Source:** U.S. Bureau of Labor Statistics, ",
    "Quarterly Census of Employment and Wages (QCEW), ",
    year_range,
    " annual averages."
  )
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
