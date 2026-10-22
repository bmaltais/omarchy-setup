# Playbook: Shared Cargo build cache (mr-boxington)

Install Rust and [mr-boxington](https://mr-boxington.jdx.dev) (`mbx`) through mise so every Cargo build on the machine shares one compiler-output cache. Cargo still resolves and plans builds; `mbx` restores matching outputs from the shared store and compiles only what is missing.

## Why it is in this setup

Omarchy is a dev-oriented desktop, and Rust projects are slow to rebuild and large on disk:

- **Worktrees and clones rebuild the same dependencies.** Each checkout has its own `target/`, so the same crates compile again. A shared store lets them reuse each other's output. This matters more with agents, which tend to work in parallel git worktrees.
- **`target/` directories pile up.** One store is easier to bound and clean than many project-local directories.
- **No wrapper to remember.** With the `mr_boxington` option on the `rust` tool, mise puts a caching `cargo` on `PATH`. You keep typing `cargo build`, with no `mbx setup` hook and no daemon (each command starts its own cache agent and stops it when the build ends).
- **Everything stays under mise.** Omarchy already manages tool versions with mise, so this adds one line to the global mise config instead of a separate install path.

## Assumptions

- Omarchy (Arch + Hyprland) with mise (`command -v mise`)
- mise 2026.9.2 or newer (needed for the `mr_boxington` Rust option)
- Network access to download the Rust toolchain and `mr-boxington` release

## Live paths this playbook changes

| Path | Role |
|------|------|
| `~/.config/mise/config.toml` | Adds `rust` (with `mr_boxington = true`) and `mr-boxington` |
| mise install dir (`mise where rust`) | Toolchain and `mbx` binaries |

mise may also add provenance options (for example a `workflow` value) to the `mr-boxington` entry. Those are written by mise and are fine to leave alone.

## Quick install

```bash
./scripts/mr-boxington-install.sh
```

## 1. Detect

```bash
command -v mise && mise --version
mise ls --global | grep -E 'rust|mr-boxington'
```

## 2. Install

```bash
./scripts/mr-boxington-install.sh
```

This runs:

```bash
mise use --global --tool-option mr_boxington=true rust mr-boxington
```

## 3. Configure

Nothing else. The option on `rust` is the configuration:

```toml
mr-boxington = "latest"
rust = { version = "latest", mr_boxington = true }
```

## 4. Verify

In a new shell with mise activation (or shims) on `PATH`:

```bash
command -v cargo
mbx --version
cargo build   # in any Rust project; a second checkout should report cache hits
```

`cargo` must resolve through mise. If `~/.cargo/bin` or a system `cargo` comes first, builds are not cached. See the [verify guide](https://mr-boxington.jdx.dev/setup#verify-plain-cargo).

## After updates

- `mise upgrade` moves both tools forward; keep them together.
- Updating mise below 2026.9.2 breaks the option; the script refuses to run on an older mise.
- Kernel and Omarchy updates do not affect this.

## Undo

```bash
mise unuse --global rust mr-boxington
```

Delete the shared cache store separately if you want the disk back (see the mr-boxington docs for its location and `mbx` cleanup commands).

## References

- [mr-boxington](https://github.com/jdx/mr-boxington)
- [mr-boxington docs](https://mr-boxington.jdx.dev/getting-started)
