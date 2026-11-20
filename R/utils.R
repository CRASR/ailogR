data_dictionary <- function(table = NULL) {
  dd <- utils::read.csv(system.file("templates", "data_dictionary.csv", package = "ailogR"),
                        colClasses = "character")
  if (is.null(table)) dd else dd[dd$table == table, ]
}

allowed_values <- function(table, field) {
  dd <- data_dictionary(table)
  strsplit(dd$allowed_values[dd$field == field], "|", fixed = TRUE)[[1]]
}

log_file <- function(path, table) {
  file <- file.path(path, "ai-use", paste0(table, ".csv"))
  if (!file.exists(file)) {
    stop("No ", basename(file), " in ", normalizePath(path, mustWork = FALSE),
         ". Start a log with create_ai_log().", call. = FALSE)
  }
  file
}

read_table <- function(path, table) {
  utils::read.csv(log_file(path, table), colClasses = "character",
                  na.strings = character(), check.names = FALSE)
}

write_table <- function(x, path, table, append = FALSE) {
  utils::write.table(x, log_file(path, table), append = append, sep = ",",
                     row.names = FALSE, col.names = !append, qmethod = "double",
                     fileEncoding = "UTF-8")
}

# Returns the chosen element of `choices`; cancelling (0) stops.
ask_choice <- function(title, choices, labels = choices) {
  i <- utils::menu(labels, title = title)
  if (i == 0) stop("Cancelled.", call. = FALSE)
  choices[[i]]
}

ask_text <- function(prompt, default = "") {
  shown <- if (nzchar(default)) sprintf("%s [%s]: ", prompt, default) else paste0(prompt, ": ")
  answer <- trimws(readline(shown))
  if (nzchar(answer)) answer else default
}
