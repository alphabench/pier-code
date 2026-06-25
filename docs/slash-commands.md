# Slash commands

While Pier is running, type `/` to access in-session commands. Common ones:

| Command | What it does |
| --- | --- |
| `/help` | List available commands. |
| `/model` | Show or switch the active model. |
| `/approvals` | Change how much the agent asks before acting. |
| `/init` | Generate an `AGENTS.md` for the current project. |
| `/diff` | Show pending changes as a diff. |
| `/clear` | Clear the conversation and start fresh. |
| `/compact` | Summarize the conversation to reclaim context. |
| `/status` | Show version, model, and session info. |
| `/quit` | Exit Pier. |

Run `/help` inside a session for the full, up-to-date list — available commands may vary by version.

## Command-line subcommands

Outside a session, the `pier` binary also exposes:

| Command | What it does |
| --- | --- |
| `pier` | Start an interactive session. |
| `pier login` | Pair the CLI with your account. |
| `pier exec "<task>"` | Run a single task non-interactively. |
| `pier --version` | Print the installed version. |
| `pier --help` | Show all flags and subcommands. |
