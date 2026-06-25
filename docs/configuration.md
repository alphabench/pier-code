# Configuration

Pier reads configuration from `~/.pier/config.toml`. You can also override most settings per-invocation with `-c key=value` flags. This page covers the user-facing options; see [examples/config](../examples/config) for ready-to-copy snippets.

## Choosing a model

Pier is powered by sovereign Indian models by default. Set the model in config:

```toml
model = "sarvam-105b"
```

Or per-run:

```bash
pier -m sarvam-105b
```

The larger model handles long-horizon repo tasks; a smaller, faster model is available for quick edits and Q&A. For the hardest tasks you can opt into a frontier model per run — see [pricing.md](./pricing.md).

## Approvals

By default, Pier asks before doing anything that writes files, runs commands, or touches the network — only provably read-only commands are auto-approved. This keeps you at the gateway.

```toml
# How much to ask before acting.
approval_policy = "untrusted"   # ask unless provably read-only (default)
# approval_policy = "on-request"  # the agent asks when it wants to escalate
# approval_policy = "never"       # never prompt (use only inside a sandbox)
```

## Sandbox

The sandbox limits what the agent can touch on your machine.

```toml
sandbox_mode = "workspace-write"   # read anywhere, write only in the workspace
# sandbox_mode = "read-only"        # no writes at all
```

Network access inside `workspace-write` is off by default; enable it when a task needs it:

```bash
pier -s workspace-write -c sandbox_workspace_write.network_access=true
```

> **Tip:** Keep the sandbox on for everyday work. It is what stops a bad command from reaching outside your project.

## Project instructions

Drop an `AGENTS.md` file at the root of a repository to give Pier persistent, project-specific guidance (conventions, build commands, things to avoid). The agent reads it at the start of every session in that project.

## Where things live

| Path | Contents |
| --- | --- |
| `~/.pier/config.toml` | Your configuration. |
| `~/.pier/bin/` | The installed binary. |
| `~/.pier/` | Credentials and local state. |
