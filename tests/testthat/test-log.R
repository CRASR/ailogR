new_project <- function() {
  path <- tempfile("ailogR-")
  suppressMessages(create_ai_log(path))
  suppressMessages(add_ai_tool("Claude", "Anthropic", "Opus 5.5", "cli_agent", path = path))
  path
}

test_that("create_ai_log writes headers that match the data dictionary", {
  path <- new_project()
  dd <- data_dictionary()
  expect_equal(names(read_ai_log(path)), dd$field[dd$table == "ai_log"])
  expect_equal(names(read_ai_log(path, "ai_tools")), dd$field[dd$table == "ai_tools"])
  expect_true(file.exists(file.path(path, "ai-use", "AI-INSTRUCTIONS.md")))
})

test_that("tool IDs are made from product and version, and not duplicated", {
  path <- new_project()
  expect_message(add_ai_tool("Claude", "Anthropic", "Opus 5.5", "web", path = path),
                 "already")
  expect_equal(read_ai_log(path, "ai_tools")$tool_id, "claude-opus-5.5")
})

test_that("log_ai writes a complete entry", {
  path <- new_project()
  suppressMessages(log_ai("Plot discharge", tool_id = "claude-opus-5.5",
                          research_stage = "visualization", error_visibility = "checkable",
                          how_checked = "Compared with raw data", human_decisions = "Chose layout",
                          path = path))
  log <- read_ai_log(path)
  expect_equal(nrow(log), 1)
  expect_equal(log$outcome, "accepted")
  expect_equal(nrow(suppressMessages(check_ai_log(path))), 0)
})

test_that("checkable, silent and method uses need how_checked; method needs prompt_archive", {
  path <- new_project()
  expect_error(log_ai("Join tables", tool_id = "claude-opus-5.5", research_stage = "data_curation",
                      error_visibility = "silent", human_decisions = "x", path = path),
               "how_checked: missing")
  expect_error(log_ai("Classify abstracts", tool_id = "claude-opus-5.5",
                      research_stage = "data_analysis", error_visibility = "obvious",
                      ai_role = "method", how_checked = "Hand-coded 50", human_decisions = "x",
                      path = path),
               "prompt_archive: missing")
  expect_equal(nrow(read_ai_log(path)), 0)
})

test_that("unknown values and tools are refused", {
  path <- new_project()
  expect_error(log_ai("x", tool_id = "gpt-9", research_stage = "software",
                      error_visibility = "visible", human_decisions = "x", path = path),
               "'gpt-9' is not allowed")
})

test_that("AI-drafted entries are pending until reviewed", {
  path <- new_project()
  suppressMessages(log_ai("Join tables", tool_id = "claude-opus-5.5",
                          research_stage = "data_curation", error_visibility = "silent",
                          how_checked = "none", logged_by = "ai", path = path))
  problems <- suppressMessages(check_ai_log(path))
  expect_setequal(problems$problem,
                  c("silent errors possible, but not checked", "awaiting review with edit_ai_log()"))
  expect_message(draft_ai_statement(path), "awaiting review")

  suppressMessages(edit_ai_log(1, human_decisions = "Chose the join keys",
                               how_checked = "Row counts match", outcome = "accepted", path = path))
  expect_equal(nrow(suppressMessages(check_ai_log(path))), 0)
  expect_equal(read_ai_log(path)$logged_by, "ai")
})

test_that("edit_ai_log refuses unknown fields and invalid values", {
  path <- new_project()
  suppressMessages(log_ai("Edit text", tool_id = "claude-opus-5.5",
                          research_stage = "writing_review_editing", error_visibility = "obvious",
                          human_decisions = "Kept some edits", path = path))
  expect_error(edit_ai_log(1, colour = "blue", path = path), "Unknown field")
  expect_error(edit_ai_log(1, outcome = "maybe", path = path), "not allowed")
})

test_that("the statement names tools, stages, methods and checks", {
  path <- new_project()
  suppressMessages({
    log_ai("Copy-edit the discussion", tool_id = "claude-opus-5.5",
           research_stage = "writing_review_editing", error_visibility = "obvious",
           human_decisions = "Wrote all content", date = "2026-11-02", path = path)
    log_ai("Extract litter mass loss from tables", tool_id = "claude-opus-5.5",
           research_stage = "data_curation", ai_role = "method", error_visibility = "silent",
           how_checked = "Compared 40 papers with hand extraction", prompt_archive = "prompts/",
           human_decisions = "Defined the fields", date = "2026-12-01", path = path)
  })
  txt <- capture.output(statement <- draft_ai_statement(path))
  expect_match(statement, "Claude \\(Opus 5.5, Anthropic\\)")
  expect_match(statement, "November 2026 to December 2026")
  expect_match(statement, "editing text \\(Copy-edit the discussion\\)")
  expect_match(statement, "as a method to Extract litter")
  expect_match(statement, "Compared 40 papers")
})
