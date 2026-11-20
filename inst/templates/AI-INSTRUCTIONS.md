# Instructions for AI tools: drafting AI-use log entries

This project logs AI use in `ai-use/` with the ailogR R package
(https://github.com/CRASR/ailogR). At the end of a work session,
draft one entry for the person to review.

## When to draft an entry

Draft one entry per task per session when the session's output stays in the
project or shaped a decision the person adopted: code, text, data,
references, or a model or design choice.

Don't draft one when you only explained something, answered questions, or
suggested something the person then wrote themselves.

## How to draft it

**If you can run commands in this project** (Claude Code, Copilot agent,
Codex and similar), run:

```sh
Rscript -e 'ailogR::log_ai(
  task = "One line summarizing what you did this session",
  tool_id = "your tool_id from ai-use/ai_tools.csv",
  research_stage = "software",
  error_visibility = "silent",
  how_checked = "Tests or checks you actually ran, and their results",
  evidence = "Files changed or commit hash",
  logged_by = "ai")'
```

**If you are a chat app without access to the project** (Claude, ChatGPT and
similar on the web or desktop), end your reply with the same `log_ai()` call
in an R code block for the person to paste into R, without `Rscript -e`.

If your tool is not yet in `ai-use/ai_tools.csv`, or you can't see that file,
put an `add_ai_tool()` call first, with your product, provider, exact model
version and access mode (`web`, `desktop`, `api`, `ide` or `cli_agent`).
It does nothing if the tool is already listed:

```r
ailogR::add_ai_tool("Claude", "Anthropic", "Opus 5.5", "cli_agent")
```

## Fields

- `research_stage`: one of the values in `ai-use/data_dictionary.csv`.
  Code is usually `software`; analysis code is `data_analysis`.
- `error_visibility`: if your output were subtly wrong, would that show?
  - `obvious`: the person can read and judge all of it (text edits, comments).
  - `checkable`: a wrong output would fail, error or look wrong (plots, file
    import, code with tests).
  - `silent`: a wrong output would still run and look plausible (joins, unit
    conversions, aggregations, model code, derived variables, QA/QC rules).

  Choose from the task, not from how well it was checked. When unsure, or when
  the session spans several levels, choose the less visible one.
- `how_checked`: only checks you actually ran, with results. Write `none` if
  you ran none. Never describe a check you did not run.
- Leave `human_decisions` empty. The entry is saved as `pending` until the
  person reviews it with `ailogR::edit_ai_log()`.

After drafting, tell the person in one line that you added a draft entry for
them to review.
