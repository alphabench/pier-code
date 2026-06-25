# Getting started

This guide walks you through your first session with Pier.

## 1. Install

```bash
curl -fsSL https://dl.piercode.com/install.sh | sh
```

This installs the `pier` binary to `~/.pier/bin` and adds it to your `PATH`. Open a new terminal (or `source` your shell profile) so the command is available. See [install.md](./install.md) for details and other options.

Verify the install:

```bash
pier --version
```

## 2. Sign in

```bash
pier login
```

This opens a browser to pair your CLI with your Pier account. Once paired, your credentials are stored locally and reused across sessions.

## 3. Start coding

Navigate to a project and launch the agent:

```bash
cd my-project
pier
```

Describe what you want in natural language — in English or an Indian language (see [languages.md](./languages.md)). For example:

> Add a `/health` endpoint that returns 200 OK, and write a test for it.

Pier maps your repository, plans the change, and shows you a diff before touching any file. **You stay at the gateway:** every edit is reviewed and approved by you, and commands are surfaced before they run.

## 4. Review and ship

- Approve or reject each proposed change.
- Let the agent run your tests and iterate until they pass.
- Commit when you're happy.

## One-shot mode

To run a single task non-interactively (handy in scripts):

```bash
pier exec "fix the failing test in src/auth"
```

## Next steps

- [Configuration](./configuration.md) — choose models, approval modes, and the sandbox.
- [Slash commands](./slash-commands.md) — control the agent mid-session.
- [FAQ](./faq.md) — common questions.
