# AI-use log

Each row of `ai_log.csv` is one task where an AI tool's output stayed in
this project. The files are plain CSV; the ailogR R package
(https://github.com/CRASR/ailogR) adds, edits and checks entries.

| File | Contents |
|---|---|
| `ai_log.csv` | One row per task: date, tool, research stage, what AI did, whether an error would show, how it was checked, and what a person decided |
| `ai_tools.csv` | One row per AI tool and model version |
| `data_dictionary.csv` | What each column means and its allowed values |
| `AI-INSTRUCTIONS.md` | Instructions for AI tools that draft entries for review |

Entries with outcome `pending` were drafted by an AI tool and have not yet
been reviewed by a person.
