# Install

Pier ships as a single self-contained binary. There is no runtime to install and no IDE dependency.

## Supported platforms

| OS        | Architectures                         |
| --------- | ------------------------------------- |
| macOS 12+ | Apple Silicon (arm64), Intel (x86_64) |
| Linux     | x86_64, arm64 (aarch64); glibc-based  |

**Recommended:** 8 GB RAM (4 GB minimum).

## Install script (recommended)

```bash
curl -fsSL https://dl.piercode.com/install.sh | sh
```

The script detects your OS and architecture, downloads the matching binary, verifies its SHA-256 checksum, installs it to `~/.pier/bin`, and adds that directory to your `PATH`.

### Pin a version

```bash
curl -fsSL https://dl.piercode.com/install.sh | sh -s -- --release 0.1.4
```

### Environment variables

The installer honors these:

| Variable                      | Default                 | Purpose                                         |
| ----------------------------- | ----------------------- | ----------------------------------------------- |
| `PIER_RELEASE`         | `latest`                | Version to install (overridden by `--release`). |
| `PIER_INSTALL_DIR`     | `~/.pier/bin`    | Install directory.                              |
| `PIER_NON_INTERACTIVE` | `false`                 | Set to `1` to skip prompts (useful in CI).      |
| `PIER_BASE_URL`        | the distribution domain | Override the download base URL.                 |

## Manual download

Release artifacts are published per target at:

```
https://dl.piercode.com/v<version>/pier-<target>.tar.gz
https://dl.piercode.com/latest/pier-<target>.tar.gz
```

where `<target>` is one of:

- `aarch64-apple-darwin` (macOS, Apple Silicon)
- `x86_64-apple-darwin` (macOS, Intel)
- `aarch64-unknown-linux-gnu` (Linux, arm64)
- `x86_64-unknown-linux-gnu` (Linux, x86_64)

Each tarball has a matching `.sha256` sidecar and contains a single `pier` binary. Extract it onto your `PATH` (substitute the target for your platform):

```bash
tar -xzf pier-aarch64-apple-darwin.tar.gz
mv pier ~/.local/bin/
```

## Verify

```bash
pier --version
```

## Update

Re-run the install script — it always fetches the latest published version (or pass `--release` for a specific one).

## Uninstall

```bash
rm -rf ~/.pier
```

Then remove the `# >>> Pier installer >>>` block the installer added to your shell profile (`~/.zprofile`, `~/.bashrc`, `~/.profile`, etc.).
