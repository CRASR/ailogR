#' Start an AI-use log in a project
#'
#' Makes an `ai-use/` folder holding two empty tables, `ai_log.csv` (one row
#' per task) and `ai_tools.csv` (one row per tool and model version), plus a
#' data dictionary, a short README, and `AI-INSTRUCTIONS.md` for AI tools that
#' draft entries. Existing files are kept. In an R package, `ai-use` is added
#' to `.Rbuildignore`.
#'
#' @param path Root folder of the project.
#'
#' @return The path of the `ai-use/` folder, invisibly.
#' @export
#'
#' @examples
#' create_ai_log(file.path(tempdir(), "my-project"))
create_ai_log <- function(path = ".") {
  dir <- file.path(path, "ai-use")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  dd <- data_dictionary()
  for (table in c("ai_log", "ai_tools")) {
    file <- file.path(dir, paste0(table, ".csv"))
    if (!file.exists(file)) writeLines(paste(dd$field[dd$table == table], collapse = ","), file)
  }
  file.copy(list.files(system.file("templates", package = "ailogR"), full.names = TRUE), dir)

  if (file.exists(file.path(path, "DESCRIPTION"))) {
    rbuildignore <- file.path(path, ".Rbuildignore")
    lines <- if (file.exists(rbuildignore)) readLines(rbuildignore) else character()
    if (!"^ai-use$" %in% lines) writeLines(c(lines, "^ai-use$"), rbuildignore)
  }
  message("AI-use log in ", normalizePath(dir))
  invisible(dir)
}

#' Add an AI tool to the log
#'
#' Each tool and model version gets its own row, because model behavior
#' changes between versions. Run interactively with no arguments, it asks for
#' each field. If the `tool_id` is already listed, nothing is added.
#'
#' @param product Product name, such as `"Claude"` or `"ChatGPT"`.
#' @param provider Company or organization providing the tool.
#' @param model_version Model name and version as shown by the tool.
#' @param access_mode One of `"web"`, `"desktop"`, `"api"`, `"ide"` or
#'   `"cli_agent"`.
#' @param tool_id Short key for the tool. By default made from `product` and
#'   `model_version`, such as `"claude-opus-5.5"`.
#' @param trains_on_inputs `"yes"`, `"no"` or `"unknown"`: whether the
#'   provider may train on your inputs under your account settings.
#' @param notes Optional notes.
#' @param path Root folder of the project.
#'
#' @return The `tool_id`, invisibly.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "tool-example")
#' create_ai_log(project)
#' add_ai_tool("Claude", "Anthropic", "Opus 5.5", "web", path = project)
add_ai_tool <- function(product = NULL, provider = NULL, model_version = NULL,
                        access_mode = NULL, tool_id = NULL, trains_on_inputs = "unknown",
                        notes = "", path = ".") {
  tools <- read_table(path, "ai_tools")
  if (interactive()) {
    if (is.null(product)) product <- ask_text("Product (e.g. Claude, ChatGPT, Copilot)")
    if (is.null(provider)) provider <- ask_text("Provider (e.g. Anthropic, OpenAI, GitHub)")
    if (is.null(model_version)) model_version <- ask_text("Model and version, as shown by the tool")
    if (is.null(access_mode)) {
      access_mode <- ask_choice("How did you access it?", allowed_values("ai_tools", "access_mode"))
    }
  }
  row <- list(tool_id = tool_id, product = product, provider = provider,
              model_version = model_version, access_mode = access_mode,
              trains_on_inputs = trains_on_inputs, notes = notes) |>
    lapply(\(x) if (is.null(x)) "" else as.character(x)) |>
    as.data.frame()
  if (!nzchar(row$tool_id)) {
    row$tool_id <- tolower(gsub("[^[:alnum:].]+", "-", paste(row$product, row$model_version)))
  }
  if (row$tool_id %in% tools$tool_id) {
    message("'", row$tool_id, "' is already in ai_tools.csv.")
    return(invisible(row$tool_id))
  }
  stop_if_problems(find_problems(row, "ai_tools"), "Tool")
  write_table(row, path, "ai_tools", append = TRUE)
  message("Added tool '", row$tool_id, "'.")
  invisible(row$tool_id)
}

#' Log a use of AI
#'
#' Adds one row to `ai_log.csv`: one task in one work session, not one row
#' per prompt. Run interactively, it asks only for what you leave out, with
#' the most recently used tool and research stage listed first:
#'
#' 1. tool, 2. research stage, 3. task, 4. error visibility,
#' 5. how you checked it (only for `checkable` or `silent` uses), and
#' 6. what you decided.
#'
#' Entries written by an AI tool (`logged_by = "ai"`) never ask questions and
#' are saved with outcome `pending`, so a person reviews them with
#' [edit_ai_log()]. See `vignette("what-to-log", package = "ailogR")` for
#' when to log and how to choose `error_visibility`.
#'
#' @param task What AI was used for, in one line.
#' @param tool_id A `tool_id` from `ai_tools.csv`; see [add_ai_tool()].
#' @param research_stage Research stage; see the data dictionary.
#' @param error_visibility If the AI output were subtly wrong, would that
#'   show? `"obvious"` (you can read and judge all of it), `"checkable"` (a
#'   wrong output would fail, error or look wrong) or `"silent"` (a wrong
#'   output would still run and look plausible).
#' @param how_checked The check you ran and what it showed. Required for
#'   `checkable` and `silent` uses and for `method` uses.
#' @param human_decisions What a person decided, designed or changed.
#' @param ai_role `"assistance"` (AI helped a person write code, text or
#'   ideas) or `"method"` (AI itself produced data or results).
#' @param evidence Optional commit, file, test or other record.
#' @param prompt_archive Where prompts and settings are archived. Required
#'   for `method` uses.
#' @param data_shared Most sensitive material given to the tool: `"none"`,
#'   `"public"`, `"unpublished"` or `"confidential"`.
#' @param outcome `"accepted"`, `"modified"`, `"rejected"` or `"pending"`.
#'   Defaults to `"pending"` for entries logged by AI, otherwise
#'   `"accepted"`.
#' @param logged_by `"person"` or `"ai"`.
#' @param logged_when `"at_the_time"` or `"reconstructed"`.
#' @param date Date of the work session.
#' @param path Root folder of the project.
#'
#' @return The new row, invisibly.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "log-example")
#' create_ai_log(project)
#' add_ai_tool("Claude", "Anthropic", "Opus 5.5", "web", path = project)
#' log_ai("Plotting function for discharge time series",
#'        tool_id = "claude-opus-5.5", research_stage = "visualization",
#'        error_visibility = "checkable",
#'        how_checked = "Compared plots with the raw gauge data",
#'        human_decisions = "Chose the variables, scales and layout",
#'        path = project)
log_ai <- function(task = NULL, tool_id = NULL, research_stage = NULL,
                   error_visibility = NULL, how_checked = NULL, human_decisions = NULL,
                   ai_role = c("assistance", "method"), evidence = "", prompt_archive = "",
                   data_shared = "none", outcome = NULL, logged_by = c("person", "ai"),
                   logged_when = c("at_the_time", "reconstructed"), date = Sys.Date(),
                   path = ".") {
  ai_role <- match.arg(ai_role)
  logged_by <- match.arg(logged_by)
  logged_when <- match.arg(logged_when)
  log <- read_table(path, "ai_log")
  tools <- read_table(path, "ai_tools")

  if (interactive() && logged_by == "person") {
    if (is.null(tool_id)) {
      ids <- intersect(unique(c(rev(log$tool_id), tools$tool_id)), tools$tool_id)
      tool_id <- ask_choice("AI tool:", c(ids, "new"), c(ids, "Add a new tool"))
      if (tool_id == "new") tool_id <- add_ai_tool(path = path)
    }
    if (is.null(research_stage)) {
      stages <- allowed_values("ai_log", "research_stage")
      stages <- intersect(unique(c(rev(log$research_stage), stages)), stages)
      research_stage <- ask_choice("Research stage:", stages, gsub("_", " ", stages))
    }
    if (is.null(task)) task <- ask_text("Task, in one line")
    if (is.null(error_visibility)) {
      error_visibility <- ask_choice(
        "If the AI output were subtly wrong, would that show?",
        c("obvious", "checkable", "silent"),
        c("obvious: you can read and judge all of it (text edits, comments)",
          "checkable: a wrong output would fail or look wrong (plots, file import)",
          "silent: a wrong output would still run and look plausible (joins, models, unit conversions)")
      )
    }
    if (is.null(how_checked) && (error_visibility != "obvious" || ai_role == "method")) {
      how_checked <- ask_text("How did you check it, and what did it show?")
    }
    if (ai_role == "method" && !nzchar(prompt_archive)) {
      prompt_archive <- ask_text("Where are the prompts and settings archived?")
    }
    if (is.null(human_decisions)) human_decisions <- ask_text("What did you decide or change?")
  }

  if (is.null(outcome)) outcome <- if (logged_by == "ai") "pending" else "accepted"
  row <- list(date = format(as.Date(date)), tool_id = tool_id, research_stage = research_stage,
              task = task, ai_role = ai_role, error_visibility = error_visibility,
              human_decisions = human_decisions, how_checked = how_checked,
              evidence = evidence, prompt_archive = prompt_archive, data_shared = data_shared,
              outcome = outcome, logged_when = logged_when, logged_by = logged_by) |>
    lapply(\(x) if (is.null(x)) "" else as.character(x)) |>
    as.data.frame()
  # Re-read: a new tool may have been added above.
  stop_if_problems(find_problems(row, "ai_log", read_table(path, "ai_tools")$tool_id), "Entry")

  write_table(row, path, "ai_log", append = TRUE)
  message(sprintf("Logged row %d: %s (%s, %s).", nrow(log) + 1, row$task,
                  row$error_visibility, row$outcome))
  invisible(row)
}

#' Read an AI-use log
#'
#' @param path Root folder of the project.
#' @param table `"ai_log"` or `"ai_tools"`.
#'
#' @return A data frame with every column as character.
#' @export
#'
#' @examples
#' project <- file.path(tempdir(), "read-example")
#' create_ai_log(project)
#' read_ai_log(project)
read_ai_log <- function(path = ".", table = c("ai_log", "ai_tools")) {
  read_table(path, match.arg(table))
}
