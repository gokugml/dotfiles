# Portable Apple Silicon Dotfiles

[中文文档](README.md)

<!-- section:overview -->

## Overview

This public repository stores shareable personal configuration and migration capabilities for moving reviewed Zsh, Homebrew, mise, uv, and Zsh plugins to an Apple Silicon Mac. Configuration used jointly with other people belongs in an optional separate shared repository, while machine secrets live only in a local file outside every repository.

Stage 1 applies the approved `zsh-repair-plan.md` to reviewed repository-owned Zsh files. It supports either the plain `zprofile` + `zshrc` names or the dotted `.zprofile` + `.zshrc` names. Stage 2 does not generate these files; the installer resolves the one complete pair under `my_setup/zsh/` and then creates the fixed HOME startup entries.

<!-- section:stages -->

## Four-stage workflow

1. **Stage 0 — analyze and export.** `./dump.sh` exports software, tooling, and plugin candidates read-only. A separate Zsh Skill collects value-free structural evidence and writes a repair plan. The Export Review Skill reviews candidate configuration. Formal drafts are written only after user confirmation.
2. **Stage 1 — apply the Zsh repair plan.** Update explicit user-provided targets when present. Otherwise, first confirm `zprofile`/`zshrc` or `.zprofile`/`.zshrc`, then apply the plan against the existing files and review the complete diff without changing the real HOME or installing software.
3. **Stage 2 — configure and install.** Confirm that `my_setup/zsh/` contains exactly the complete pair selected in Stage 1, then run parameterless `./install.sh`. The script shows the selected sources and one combined summary, asks once with a default-`N` `y/N` prompt, and finishes with `./install.sh verify`.
4. **Stage 3 — retire Intel software.** Start with the read-only `./install.sh retire` preview. Run `./install.sh retire --apply` only after another review and an explicit confirmation in a real TTY. Normal installation and `verify` never trigger retirement.

<!-- section:layout -->

## Repository and installer layout

```text
dotfiles/
├── README.md                     # default Chinese documentation
├── README.en.md                  # English documentation
├── dump.sh
├── install.sh                    # only public installation entry point
├── my_setup/
│   ├── zsh/install.sh            # internal Zsh/symlink/plugin module
│   ├── zsh/{zprofile,zshrc}       # default plain Stage 1 sources
│   │   or zsh/{.zprofile,.zshrc}  # dotted sources when selected
│   ├── tooling/install.sh        # internal mise/uv module
│   └── macos/install.sh          # internal Homebrew module
├── tests/smoke.zsh
├── .githooks/pre-commit
└── .github/workflows/verify.yml
```

The three nested `install.sh` files are internal modules sourced by the root installer and fail safely when executed directly. The root installer owns argument parsing, cross-capability checks, the combined summary, the single confirmation, orchestration, and final verification.

<!-- section:commands -->

## Commands

```zsh
./dump.sh
./install.sh
./install.sh verify
./install.sh retire
./install.sh retire --apply
```

The parameterless install order is `macos → tooling → zsh → pre-commit hook → verify`. If Apple Silicon Homebrew is missing, the installer stops and asks the user to review and install official Homebrew first; it never runs an opaque `curl | shell` command.

Stage 2 must uniquely authorize the optional shared repository and pass its absolute path to the root installer:

```zsh
DOTFILES_SHARED_DIR=/absolute/path/to/shared-dotfiles ./install.sh
```

<!-- section:configuration -->

## Configuration contract

- Personal configuration always lives in this public repository under `my_setup/`.
- Shared configuration is an optional, separate Git worktree containing only settings used jointly with other people.
- Local configuration is fixed at `~/.config/dotfiles/local/parameters.zsh` and contains only secrets, accounts, and machine paths—not software or plugin choices.
- Personal Zsh sources must contain exactly one complete pair: `my_setup/zsh/zprofile` + `zshrc`, or `my_setup/zsh/.zprofile` + `.zshrc`. Two complete pairs, mixed names, or an incomplete pair stop before confirmation and writes; the installer never guesses a priority or creates an alias copy.
- HOME always uses `~/.zprofile` and `~/.zshrc`, symlinked to the resolved repository files from the same pair.
- `.zshrc` uses the markers `dotfiles: shared → dotfiles: personal → dotfiles: local` to preserve load order and the `shared < personal < local` override priority.
- Every enabled plugin has a `dotfiles: plugin <name>` marker in `.zshrc`, ordered by the merged `load_order` value.
- Personal and shared configuration each have at most one `zsh/plugins.toml`. Plugins pin a 40-character commit, and personal wins same-name conflicts.
- Personal and shared configuration declare their own Brewfiles and tooling; personal wins same-name Homebrew conflicts.

Managed symlinks expose mise configuration under `~/.config/mise/conf.d/`, with a `10-` prefix for shared and `20-` for personal. The personal `uv.toml` becomes the user-level uv configuration through a managed symlink, and the installer explicitly passes approved `.python-versions` entries to `uv python install`.

<!-- section:safety -->

## Safety boundaries

- Real installation runs only in a native macOS `arm64` session. Test mode accepts only an isolated HOME under `/private/tmp` or `/tmp`.
- Before replacing an existing `.zprofile` or `.zshrc`, the installer creates a timestamped copy that preserves a file or symlink's type and target.
- The parent directory of `parameters.zsh` must be mode `0700`, and the file must be mode `0600`. Scripts never display, copy, log, persist, or hash its contents; they only run a silent syntax check and normal shell loading.
- Public output must not contain shared-repository-only information, secrets, or machine-specific absolute paths.
- Services, databases, Homebrew services, and GUI application data are reported for manual handling and are never automatically started, stopped, migrated, or deleted.
- Retirement accepts only exact Intel formulae with explicit ARM replacement path and architecture evidence and no service/data record. Unknown items, project dependencies, NVM, Python Frameworks, global runtimes, old plugins, and `/usr/local` as a whole are retained by default.

<!-- section:verification -->

## Tests and release gates

```zsh
./tests/smoke.zsh
./tests/smoke.zsh --quick
.githooks/pre-commit
```

The full smoke test uses a temporary repository and HOME to verify both plain and dotted repository source names, ambiguity/mixed-name blocking, default `N`, backups, symlinks, idempotency, shared/personal merging, local-value non-disclosure, read-only retirement, and non-TTY blocking. Quick mode checks syntax, Markdown, section parity between the Chinese and English documentation, safety boundaries, and forbidden Intel runtime paths.

The pre-commit hook never installs dependencies. It requires `gitleaks 8.30.0`, installed from the Stage 2 mise declaration, and scans the current public tree. CI uses the same pinned version to scan both the current tree and complete Git history. Release requires quick checks, the complete smoke test, and CI to pass.

<!-- section:manual -->

## Manual work

The current Brewfile does not migrate nginx or redis service configuration or data. It also does not take over GUI application data, global npm CLIs, project runtimes, or legacy Python Frameworks. Handle the relevant data and verify ARM replacements before moving any exact item into Stage 3.
