#' Check an AI-use log for gaps
#'
#' Checks both tables against the data dictionary: required fields, allowed
#' values, dates, and tool IDs that are not in `ai_tools.csv`. A use whose
#' errors would be `checkable` or `silent`, or where AI was used as a
#' `method`, also needs `how_checked`; a `method` use needs `prompt_archive`.
#' A `silent` use whose `how_checked` is `"none"` is flagged, and entries
#' with outcome `pending` are listed as awaiting review.
#'
#' @param path Root folder of the project.
#'
#' @return A data frame with one row per problem (`table`, `row`, `field`,
#'   `problem`), invisibly. Problems are also printed.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "check-example")
#' create_ai_log(project)
#' check_ai_log(project)
check_ai_log <- function(path = ".") {
  tools <- read_table(path, "ai_tools")
  log <- read_table(path, "ai_log")
  pending <- which(log$outcome == "pending")
  unchecked <- which(log$error_visibility == "silent" & tolower(trimws(log$how_checked)) == "none")
  problems <- rbind(
    find_problems(tools, "ai_tools"),
    find_problems(log, "ai_log", tools$tool_id),
    data.frame(table = rep("ai_log", length(unchecked)), row = unchecked,
               field = rep("how_checked", length(unchecked)),
               problem = rep("silent errors possible, but not checked", length(unchecked))),
    data.frame(table = rep("ai_log", length(pending)), row = pending,
               field = rep("outcome", length(pending)),
               problem = rep("awaiting review with edit_ai_log()", length(pending)))
  )
  if (nrow(problems)) {
    message(nrow(problems), " problem(s) found:")
    print(problems, row.names = FALSE)
  } else {
    message("The AI-use log looks complete.")
  }
  invisible(problems)
}

find_problems <- function(tbl, table, tool_ids = character()) {
  dd <- data_dictionary(table)
  missing_cols <- setdiff(dd$field, names(tbl))
  if (length(missing_cols)) {
    return(data.frame(table = table, row = NA_integer_, field = missing_cols,
                      problem = "column missing"))
  }
  found <- lapply(seq_len(nrow(dd)), \(i) {
    field <- dd$field[i]
    x <- trimws(tbl[[field]])
    empty <- !nzchar(x)
    # Conditional requirements are keyed on the wording in data_dictionary.csv.
    needed <- switch(dd$required[i],
      yes = rep(TRUE, nrow(tbl)),
      "yes, unless outcome is pending" = tbl$outcome != "pending",
      "if checkable, silent or method" =
        tbl$error_visibility %in% c("checkable", "silent") | tbl$ai_role == "method",
      "if method" = tbl$ai_role == "method",
      rep(FALSE, nrow(tbl))
    )
    allowed <- strsplit(dd$allowed_values[i], "|", fixed = TRUE)[[1]]
    invalid <- if (length(allowed) > 1) {
      !x %in% allowed
    } else if (identical(allowed, "YYYY-MM-DD")) {
      is.na(as.Date(x, format = "%Y-%m-%d"))
    } else if (identical(allowed, "unique")) {
      duplicated(x)
    } else if (table == "ai_log" && field == "tool_id") {
      !x %in% tool_ids
    } else {
      rep(FALSE, nrow(tbl))
    }
    bad <- !empty & invalid
    rbind(
      data.frame(table = rep(table, sum(needed & empty)), row = which(needed & empty),
                 field = rep(field, sum(needed & empty)),
                 problem = rep("missing", sum(needed & empty))),
      data.frame(table = rep(table, sum(bad)), row = which(bad), field = rep(field, sum(bad)),
                 problem = sprintf("'%s' is not allowed", x[bad]))
    )
  })
  do.call(rbind, found)
}

stop_if_problems <- function(problems, what) {
  if (!nrow(problems)) return(invisible())
  stop(what, " not saved:\n",
       paste0("  ", problems$field, ": ", problems$problem, collapse = "\n"),
       call. = FALSE)
}
