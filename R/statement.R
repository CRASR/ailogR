#' Draft an AI-use statement from the log
#'
#' Writes a first draft for a methods section or acknowledgments: the tools
#' and versions used, what they were used for by research stage, uses where
#' AI was a method, how uses with `silent` errors were checked, and whether
#' unpublished or confidential material was shared. Entries that were
#' rejected or are still awaiting review are left out. Text in brackets needs
#' filling in by hand.
#'
#' @param path Root folder of the project.
#' @param from,to Optional first and last dates to include.
#'
#' @return The statement as a character string, invisibly. It is also
#'   printed.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "statement-example")
#' create_ai_log(project)
#' add_ai_tool("Claude", "Anthropic", "Opus 5.5", "web", path = project)
#' log_ai("Copy-edit the discussion", tool_id = "claude-opus-5.5",
#'        research_stage = "writing_review_editing", error_visibility = "obvious",
#'        human_decisions = "Accepted some edits; wrote all content",
#'        outcome = "modified", path = project)
#' draft_ai_statement(project)
draft_ai_statement <- function(path = ".", from = NULL, to = NULL) {
  log <- read_table(path, "ai_log")
  tools <- read_table(path, "ai_tools")
  if (!is.null(from)) log <- log[as.Date(log$date) >= as.Date(from), ]
  if (!is.null(to)) log <- log[as.Date(log$date) <= as.Date(to), ]
  n_pending <- sum(log$outcome == "pending")
  if (n_pending) {
    message(n_pending, " entries awaiting review are left out; review them with edit_ai_log().")
  }
  log <- log[!log$outcome %in% c("pending", "rejected"), ]
  if (!nrow(log)) {
    message("No reviewed entries to describe.")
    return(invisible(NULL))
  }

  used <- tools[tools$tool_id %in% log$tool_id, ]
  tool_txt <- paste(sprintf("%s (%s, %s)", used$product, used$model_version, used$provider),
                    collapse = " and ")
  months <- range(as.Date(log$date)) |> format("%B %Y") |> unique() |> paste(collapse = " to ")

  stage_names <- c(information_collection = "finding information",
                   data_collection_method = "data collection methods",
                   privacy_security = "privacy and security",
                   writing_original_draft = "drafting text",
                   writing_review_editing = "editing text",
                   writing_translation = "translation")
  assist <- log[log$ai_role == "assistance", ]
  stage <- ifelse(assist$research_stage %in% names(stage_names),
                  stage_names[assist$research_stage], gsub("_", " ", assist$research_stage))
  assist_txt <- split(assist$task, stage) |>
    vapply(\(tasks) paste(unique(tasks), collapse = "; "), character(1))
  assist_txt <- paste0(names(assist_txt), " (", assist_txt, ")")
  if (length(assist_txt) > 1) {
    assist_txt <- paste(paste(utils::head(assist_txt, -1), collapse = ", "), "and",
                        utils::tail(assist_txt, 1))
  }

  method <- log[log$ai_role == "method", ]
  silent <- log[log$error_visibility == "silent" & nzchar(log$how_checked), ]
  shared <- if (all(log$data_shared %in% c("none", "public"))) {
    "No unpublished or confidential material was shared with AI tools."
  } else {
    "[Describe the unpublished or confidential material shared with AI tools and the settings used.]"
  }

  txt <- paste0(
    "**Use of AI tools.** ", tool_txt, " ", if (nrow(used) > 1) "were" else "was",
    " used from ", months,
    if (nrow(assist)) paste0(" to assist with ", assist_txt) else "", ". ",
    if (nrow(method)) {
      paste0("AI was also used as a method to ", paste(unique(method$task), collapse = "; "),
             "; prompts and settings are archived at ",
             paste(unique(method$prompt_archive), collapse = "; "), ". ")
    },
    if (nrow(silent)) {
      paste0("Outputs whose errors could pass unnoticed were checked by: ",
             paste(unique(silent$how_checked), collapse = "; "), ". ")
    },
    shared, " The authors reviewed all AI output used and take full responsibility for ",
    "this work. The AI-use log is available at [link or DOI]."
  )
  cat(strwrap(txt, 90), sep = "\n")
  invisible(txt)
}
