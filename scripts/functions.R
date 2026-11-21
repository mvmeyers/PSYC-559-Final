# functions.R
# Shared helpers. Load with source(here::here("scripts", "functions.R")).

#' Previous-day values, within person, NA when the previous row is not
#' yesterday.
#'
#' People skip days (about 23% of consecutive rows skip at least one), so the
#' previous row is not always the previous day. This sets the lag to NA unless
#' the previous row is exactly one calendar day earlier. It only looks back,
#' never forward, so it cannot leak tomorrow into today.
#'
#' @param data  the daily table (needs id and day)
#' @param vars  character vector of columns to lag
#' @param suffix added to each lagged column name
lag_within_person <- function(data, vars, suffix = "_prev") {
  data <- dplyr::arrange(data, id, day)
  data <- dplyr::group_by(data, id)
  data <- dplyr::mutate(
    data,
    dplyr::across(dplyr::all_of(vars),
                  ~ dplyr::if_else(day - dplyr::lag(day) == 1, dplyr::lag(.x), NA),
                  .names = paste0("{.col}", suffix))
  )
  dplyr::ungroup(data)
}
