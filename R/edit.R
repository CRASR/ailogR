#' Edit or review an entry in the AI-use log
#'
#' Give field values to change them directly, as in
#' `edit_ai_log(3, outcome = "modified")`. Run interactively with no field
#' values, it lists entries awaiting review first, then the ten most recent.
#' For an entry awaiting review (usually one drafted by an AI tool), it asks
#' what you decided and the outcome, then lets you change any other field.
#'
#' @param row Row number in `ai_log.csv`. Asked interactively if missing.
#' @param ... Fields to change, as `field = value`.
#' @param path Root folder of the project.
#'
#' @return The edited row, invisibly.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "edit-example")
#' create_ai_log(project)
#' add_ai_tool("Claude", "Anthropic", "Opus 5.5", "cli_agent", path = project)
#' log_ai("Join gauge and chemistry tables by site and date",
#'        tool_id = "claude-opus-5.5", research_stage = "data_curation",
#'        error_visibility = "silent",
#'        how_checked = "Row counts before and after match; 10 rows checked by hand",
#'        logged_by = "ai", path = project)
#' edit_ai_log(1, human_decisions = "Chose to drop unmatched dates",
#'             outcome = "accepted", path = project)
edit_ai_log <- function(row = NULL, ..., path = ".") {
  log <- read_table(path, "ai_log")
  changes <- list(...)
  if (!nrow(log)) stop("The log has no entries yet.", call. = FALSE)

  if (is.null(row)) {
    if (!interactive()) stop("Give the `row` to edit.", call. = FALSE)
    pending <- which(log$outcome == "pending")
    rows <- c(pending, setdiff(rev(utils::tail(seq_len(nrow(log)), 10)), pending))
    row <- ask_choice("Which entry?", rows,
                      sprintf("row %d, %s: %s [%s]", rows, log$date[rows], log$task[rows],
                              log$outcome[rows]))
  }
  if (!row %in% seq_len(nrow(log))) stop("There is no row ", row, " in the log.", call. = FALSE)
  unknown <- setdiff(names(changes), names(log))
  if (length(unknown)) stop("Unknown field(s): ", paste(unknown, collapse = ", "), call. = FALSE)

  if (!length(changes) && interactive()) {
    if (log$outcome[row] == "pending") {
      cat(sprintf("\nTask: %s\nError visibility: %s\nHow checked: %s\nEvidence: %s\n\n",
                  log$task[row], log$error_visibility[row], log$how_checked[row],
                  log$evidence[row]))
      changes$human_decisions <- ask_text("What did you decide or change?", log$human_decisions[row])
      changes$outcome <- ask_choice("Outcome:", c("accepted", "modified", "rejected"))
    }
    repeat {
      fields <- setdiff(names(log), names(changes))
      field <- ask_choice("Change another field?", c("done", fields),
                          c("Done", paste0(fields, ": ", unlist(log[row, fields]))))
      if (field == "done") break
      allowed <- allowed_values("ai_log", field)
      changes[[field]] <- if (length(allowed) > 1) {
        ask_choice(paste0(field, ":"), allowed)
      } else {
        ask_text(field, log[[field]][row])
      }
    }
  }
  if (!length(changes)) {
    message("Nothing changed.")
    return(invisible(log[row, ]))
  }

  log[row, names(changes)] <- lapply(changes, as.character)
  stop_if_problems(find_problems(log[row, ], "ai_log", read_table(path, "ai_tools")$tool_id),
                   "Edit")
  write_table(log, path, "ai_log")
  message("Updated row ", row, ".")
  invisible(log[row, ])
}
