#!/bin/sh
#
# Pier CLI installer.
#
# Downloads a prebuilt `pier` binary from the R2 distribution bucket
# and installs it to the standalone releases directory structure that the
# binary's built-in update command can detect:
#
#   ~/.pier/packages/standalone/releases/<version>-<target>/pier
#   ~/.pier/bin/pier  (symlink → current release)
#
# Usage:
#   curl -fsSL https://dl.piercode.com/install.sh | sh
#   ./install.sh --release 1.2.3
#

set -eu

BASE_URL="${PIER_BASE_URL:-https://dl.piercode.com}"

RELEASE="${PIER_RELEASE:-latest}"
# Non-interactive mode: skip prompts and never relaunch the CLI. Accept both the
# canonical name and the short `PIER_NON_INTERACTIVE` that `pier update`
# passes — a mismatch here used to leave update interactive, so it prompted and
# then launched the TUI into a non-tty pipe, exiting 1 and failing the update.
NON_INTERACTIVE="${PIER_NON_INTERACTIVE:-${PIER_NON_INTERACTIVE:-false}}"
# Quiet mode: collapse the per-step `==>` chatter to a single result line (no
# URLs, paths, or checksum noise), matching the effortless feel of a self-update.
# On by default whenever we're non-interactive (i.e. driven by `update`); force
# either way with PIER_QUIET=1/0.
case "$NON_INTERACTIVE" in
  1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss]) QUIET="${PIER_QUIET:-1}" ;;
  *) QUIET="${PIER_QUIET:-0}" ;;
esac

PIER_HOME="${PIER_HOME:-$HOME/.pier}"
BIN_DIR="$PIER_HOME/bin"
BIN_PATH="$BIN_DIR/pier"
# Short alias so users can invoke the CLI as `sc` as well as `pier`.
SC_PATH="$BIN_DIR/sc"
STANDALONE_ROOT="$PIER_HOME/packages/standalone"
RELEASES_DIR="$STANDALONE_ROOT/releases"
CURRENT_LINK="$STANDALONE_ROOT/current"
LOCK_FILE="$STANDALONE_ROOT/install.lock"
LOCK_DIR="$STANDALONE_ROOT/install.lock.d"
LOCK_STALE_AFTER_SECS=600

path_action="already"
path_profile=""
lock_kind=""
tmp_dir=""

# `step` is progress chatter, silenced in quiet mode; `say` is always shown.
step() { [ "$QUIET" = "1" ] || printf '==> %s\n' "$1"; }
say()  { printf '%s\n' "$1"; }
warn() { printf 'WARNING: %s\n' "$1" >&2; }
die()  { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required to install Pier."
}

# ---- argument parsing -------------------------------------------------------

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --release)
        [ "$#" -ge 2 ] || die "--release requires a value."
        RELEASE="$2"
        shift
        ;;
      --help | -h)
        cat <<EOF
Usage: install.sh [--release VERSION]

Installs the Pier CLI to ~/.pier/bin.

Options:
  --release VERSION   Version to install (e.g. 1.2.3), or "latest" (default).

Environment:
  PIER_RELEASE          Version to install; overridden by --release.
  PIER_BASE_URL         Distribution base URL (default the R2 domain).
  PIER_NON_INTERACTIVE  Set to 1/true/yes to skip prompts.
  PIER_HOME             Pier home dir (default ~/.pier).
EOF
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done
}

# ---- version helpers --------------------------------------------------------

normalize_version() {
  case "$1" in
    "" | latest) printf 'latest\n' ;;
    v*) printf '%s\n' "${1#v}" ;;
    *)  printf '%s\n' "$1" ;;
  esac
}

validate_version() {
  version="$1"
  [ "$version" = "latest" ] && return
  printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta)(\.[0-9]+)?)?$' \
    || die "Invalid version: $version (expected latest or x.y.z[-alpha[.N]|-beta[.N]])."
}

resolve_version() {
  normalized="$(normalize_version "$RELEASE")"
  validate_version "$normalized"

  if [ "$normalized" != "latest" ]; then
    printf '%s\n' "$normalized"
    return
  fi

  # Fetch the actual version from our latest.json.
  resolved="$(download_text "$BASE_URL/latest.json" \
    | sed 's/.*"version":"\([^"]*\)".*/\1/')"

  if [ -z "$resolved" ] || [ "$resolved" = "latest" ]; then
    die "Failed to resolve the latest Pier release version from $BASE_URL/latest.json."
  fi

  validate_version "$resolved"
  printf '%s\n' "$resolved"
}

# ---- download helpers -------------------------------------------------------

download_file() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
    return
  fi
  die "curl or wget is required to install Pier."
}

download_text() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
    return
  fi
  die "curl or wget is required to install Pier."
}

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
    return
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | sed 's/^.*= //'
    return
  fi
  die "sha256sum, shasum, or openssl is required to verify the download."
}

verify_archive_digest() {
  archive_path="$1"
  expected="$2"
  actual="$(file_sha256 "$archive_path")"
  if [ "$actual" != "$expected" ]; then
    die "Checksum mismatch.
  expected: $expected
  actual:   $actual"
  fi
}

# ---- locking ----------------------------------------------------------------

mkdir_lock_is_stale() {
  [ -d "$LOCK_DIR" ] || return 1

  pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  started_at="$(cat "$LOCK_DIR/started_at" 2>/dev/null || true)"
  now="$(date +%s 2>/dev/null || printf '0')"

  case "$started_at" in ''|*[!0-9]*) started_at=0 ;; esac

  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  if [ "$started_at" -eq 0 ] || [ "$now" -eq 0 ]; then
    return 0
  fi
  [ $((now - started_at)) -ge "$LOCK_STALE_AFTER_SECS" ]
}

acquire_install_lock() {
  mkdir -p "$STANDALONE_ROOT"

  if [ "$os" = "darwin" ] && command -v lockf >/dev/null 2>&1; then
    : >>"$LOCK_FILE"
    exec 9<>"$LOCK_FILE"
    lockf 9
    lock_kind="lockf"
    return
  fi

  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock 9
    lock_kind="flock"
    return
  fi

  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if mkdir_lock_is_stale; then
      warn "Removing stale installer lock at $LOCK_DIR"
      rm -rf "$LOCK_DIR"
      continue
    fi
    sleep 1
  done

  printf '%s\n' "$$" >"$LOCK_DIR/pid"
  date +%s >"$LOCK_DIR/started_at" 2>/dev/null || true
  lock_kind="mkdir"
}

release_install_lock() {
  if [ "$lock_kind" = "mkdir" ]; then
    rm -rf "$LOCK_DIR" 2>/dev/null || true
  elif [ "$lock_kind" = "flock" ] || [ "$lock_kind" = "lockf" ]; then
    exec 9>&- 2>/dev/null || true
  fi
  lock_kind=""
}

# ---- install helpers --------------------------------------------------------

cleanup_stale_install_artifacts() {
  mkdir -p "$RELEASES_DIR" "$STANDALONE_ROOT"
  find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -name '.staging.*' -exec rm -rf {} +
  find "$STANDALONE_ROOT" -mindepth 1 -maxdepth 1 -name '.current.*' -exec rm -f {} +
  if [ -d "$BIN_DIR" ]; then
    find "$BIN_DIR" -mindepth 1 -maxdepth 1 -name '.pier.*' -exec rm -f {} +
    find "$BIN_DIR" -mindepth 1 -maxdepth 1 -name '.sc.*' -exec rm -f {} +
  fi
}

replace_path_with_symlink() {
  link_path="$1"
  link_target="$2"
  tmp_link="$3"

  rm -f "$tmp_link"
  ln -s "$link_target" "$tmp_link"

  # Try atomic rename (GNU mv -T, then BSD mv -h), fall back to non-atomic.
  if mv -Tf "$tmp_link" "$link_path" 2>/dev/null; then return; fi
  if mv -hf "$tmp_link" "$link_path" 2>/dev/null; then return; fi
  rm -f "$link_path"
  mv -f "$tmp_link" "$link_path"
}

release_dir_is_complete() {
  release_dir="$1"
  expected_version="$2"
  expected_target="$3"

  [ -d "$release_dir" ] &&
    [ "$(basename "$release_dir")" = "$expected_version-$expected_target" ] &&
    [ -x "$release_dir/pier" ]
}

install_release() {
  release_dir="$1"
  archive_path="$2"
  stage="$RELEASES_DIR/.staging.$(basename "$release_dir").$$"

  mkdir -p "$RELEASES_DIR"
  rm -rf "$stage"
  mkdir -p "$stage"
  tar -xzf "$archive_path" -C "$stage"
  [ -f "$stage/pier" ] || die "Archive did not contain a pier binary."
  chmod 0755 "$stage/pier"

  if [ -e "$release_dir" ] || [ -L "$release_dir" ]; then
    rm -rf "$release_dir"
  fi
  mv "$stage" "$release_dir"
}

update_current_link() {
  release_dir="$1"
  tmp_link="$STANDALONE_ROOT/.current.$$"
  replace_path_with_symlink "$CURRENT_LINK" "$release_dir" "$tmp_link"
}

update_visible_command() {
  mkdir -p "$BIN_DIR"
  tmp_link="$BIN_DIR/.pier.$$"
  replace_path_with_symlink "$BIN_PATH" "$CURRENT_LINK/pier" "$tmp_link"
  # Also expose the short `sc` alias, pointing at the same release binary.
  tmp_link="$BIN_DIR/.sc.$$"
  replace_path_with_symlink "$SC_PATH" "$CURRENT_LINK/pier" "$tmp_link"
}

version_from_binary() {
  path="$1"
  [ -x "$path" ] || return 1
  "$path" --version 2>/dev/null | sed -n 's/.* \([0-9][0-9A-Za-z.+-]*\)$/\1/p' | head -n 1
}

current_installed_version() {
  version="$(version_from_binary "$CURRENT_LINK/pier" || true)"
  [ -n "$version" ] && printf '%s\n' "$version" || true
}

# ---- PATH setup -------------------------------------------------------------

pick_profile() {
  case "$os:${SHELL:-}" in
    darwin:*/zsh)  printf '%s\n' "$HOME/.zprofile" ;;
    darwin:*/bash) printf '%s\n' "$HOME/.bash_profile" ;;
    linux:*/zsh)   printf '%s\n' "$HOME/.zshrc" ;;
    linux:*/bash)  printf '%s\n' "$HOME/.bashrc" ;;
    *)             printf '%s\n' "$HOME/.profile" ;;
  esac
}

rewrite_path_block() {
  profile="$1"; begin_marker="$2"; end_marker="$3"; path_line="$4"
  tmp_profile="$tmp_dir/profile.$$.tmp"

  awk -v begin="$begin_marker" -v end="$end_marker" -v line="$path_line" '
    BEGIN { in_block = 0; replaced = 0 }
    $0 == begin {
      if (!replaced) { print begin; print line; print end; replaced = 1 }
      in_block = 1; next
    }
    in_block { if ($0 == end) { in_block = 0 }; next }
    { print }
    END { if (in_block != 0) exit 1 }
  ' "$profile" >"$tmp_profile"
  mv "$tmp_profile" "$profile"
}

add_to_path() {
  path_action="already"
  path_profile=""

  case ":$PATH:" in *":$BIN_DIR:"*) return ;; esac

  profile="$(pick_profile)"
  path_profile="$profile"
  begin_marker="# >>> Pier installer >>>"
  end_marker="# <<< Pier installer <<<"
  path_line="export PATH=\"$BIN_DIR:\$PATH\""

  if [ -f "$profile" ] && grep -F "$begin_marker" "$profile" >/dev/null 2>&1; then
    if grep -F "$path_line" "$profile" >/dev/null 2>&1; then
      path_action="configured"
      return
    fi
    if grep -F "$end_marker" "$profile" >/dev/null 2>&1; then
      rewrite_path_block "$profile" "$begin_marker" "$end_marker" "$path_line"
      path_action="updated"
      return
    fi
  fi

  {
    printf '\n%s\n' "$begin_marker"
    printf '%s\n' "$path_line"
    printf '%s\n' "$end_marker"
  } >>"$profile"
  path_action="added"
}

print_launch_instructions() {
  case "$path_action" in
    added | updated | configured)
      # This shell can't pick up the PATH change a child installer wrote to your
      # profile, so lead with the copy-paste line that works right now, then note
      # that new terminals just work (PATH was persisted to the profile).
      step "This terminal: run  export PATH=\"$BIN_DIR:\$PATH\" && pier   (or: sc)"
      step "New terminals: just run  pier  (or: sc)  — added $BIN_DIR to PATH"
      ;;
    *)
      step "$BIN_DIR is already on PATH — run: pier  (or: sc)"
      ;;
  esac
}

print_open_new_window_hint() {
  # We can't reliably hand off to the interactive TUI from a `curl | sh` pipe
  # (no usable tty), and launching it here just exits back to the prompt. So
  # instead tell the user how to get a shell that can actually run `pier`.
  step "Open a new terminal window (or run  exec \$SHELL  to refresh) to access pier"
}

# ---- main -------------------------------------------------------------------

parse_args "$@"

require_command mktemp
require_command tar

case "$(uname -s)" in
  Darwin) os="darwin" ;;
  Linux)  os="linux" ;;
  *) die "install.sh supports macOS and Linux only." ;;
esac

case "$(uname -m)" in
  x86_64 | amd64)  arch="x86_64" ;;
  arm64 | aarch64) arch="aarch64" ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
esac

# A macOS x86_64 process running under Rosetta should get the native arm64 binary.
if [ "$os" = "darwin" ] && [ "$arch" = "x86_64" ]; then
  if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = "1" ]; then
    arch="aarch64"
  fi
fi

case "$os:$arch" in
  darwin:aarch64) target="aarch64-apple-darwin";      platform_label="macOS (Apple Silicon)" ;;
  darwin:x86_64)  target="x86_64-apple-darwin";       platform_label="macOS (Intel)" ;;
  linux:aarch64)  target="aarch64-unknown-linux-gnu"; platform_label="Linux (ARM64)" ;;
  linux:x86_64)   target="x86_64-unknown-linux-gnu";  platform_label="Linux (x64)" ;;
  *) die "Unsupported platform: $os/$arch" ;;
esac

resolved_version="$(resolve_version)"
release_dir="$RELEASES_DIR/$resolved_version-$target"
asset="pier-$target.tar.gz"
checksum_asset="$asset.sha256"
download_url="$BASE_URL/v$resolved_version/$asset"
checksum_url="$BASE_URL/v$resolved_version/$checksum_asset"

current_version="$(current_installed_version)"
if [ -n "$current_version" ] && [ "$current_version" != "$resolved_version" ]; then
  install_kind="update"
  step "Updating Pier CLI from $current_version to $resolved_version"
elif [ -n "$current_version" ]; then
  install_kind="reinstall"
  step "Reinstalling Pier CLI $resolved_version"
else
  install_kind="install"
  step "Installing Pier CLI"
fi
step "Detected platform: $platform_label"
step "Resolved version: $resolved_version"

tmp_dir="$(mktemp -d)"
cleanup() {
  release_install_lock
  [ -n "$tmp_dir" ] && rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

acquire_install_lock
cleanup_stale_install_artifacts

if ! release_dir_is_complete "$release_dir" "$resolved_version" "$target"; then
  if [ -e "$release_dir" ] || [ -L "$release_dir" ]; then
    warn "Found incomplete existing release at $release_dir; reinstalling."
  fi

  archive_path="$tmp_dir/$asset"
  checksum_path="$tmp_dir/$checksum_asset"

  step "Downloading $download_url"
  download_file "$download_url" "$archive_path" \
    || die "Download failed. Is version '$resolved_version' published for $target?"

  if download_file "$checksum_url" "$checksum_path" 2>/dev/null; then
    expected="$(awk '{print $1}' "$checksum_path")"
    verify_archive_digest "$archive_path" "$expected"
    step "Checksum verified"
  else
    warn "No checksum published for $asset; skipping verification."
  fi

  step "Installing to $release_dir"
  install_release "$release_dir" "$archive_path"
fi

update_current_link "$release_dir"
update_visible_command
add_to_path
"$BIN_PATH" --version >/dev/null 2>&1 || die "Installed binary failed to run."
release_install_lock

# Result line. In quiet mode (a self-update) keep it to one effortless line, the
# way Claude's updater does — no URLs, paths, or checksum trail. In verbose mode
# keep the original detailed confirmation plus PATH/launch guidance.
if [ "$QUIET" = "1" ]; then
  case "$install_kind" in
    update)    say "Updated $current_version → $resolved_version" ;;
    reinstall) say "Reinstalled Pier $resolved_version" ;;
    *)         say "Installed Pier $resolved_version" ;;
  esac
  # Only surface PATH guidance if we actually had to touch the profile; an
  # already-on-PATH update should say nothing more.
  case "$path_action" in
    added | updated)
      say "Added $BIN_DIR to PATH — open a new terminal (or run: pier)."
      ;;
  esac
else
  print_launch_instructions
  printf 'Pier CLI %s installed successfully.\n' "$resolved_version"
fi

# On a fresh interactive install/reinstall, point the user at a shell that can
# actually run `pier`. We don't auto-launch the TUI: from a `curl | sh` pipe
# there's no usable tty to hand off to, so the launch would just exit (and on a
# non-interactive self-update it would fail the whole update).
case "$NON_INTERACTIVE" in
  1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss]) : ;;
  *) print_open_new_window_hint ;;
esac
