# Portable Apple Silicon Dotfiles

[中文文档](README.md)

<!-- section:overview -->

## Overview

This public repository stores shareable personal configuration and migration capabilities for moving reviewed Zsh, Homebrew, mise, uv, and Zsh plugins to an Apple Silicon Mac. Company-specific additions belong in an optional private repository, while machine secrets live only in a local file outside every repository.

The repository is currently building its Stage 1 capabilities. Stage 1 builds and tests scripts without installing anything into the developer's real HOME. Stage 2 will generate the final `my_setup/zsh/.zprofile` and `.zshrc` from the approved `zsh-repair-plan.md` and show the changes for review.

<!-- section:stages -->

## Four-stage workflow

1. **Stage 0 — analyze and export.** `./dump.sh` exports software, tooling, and plugin candidates read-only. A separate Zsh Skill collects value-free structural evidence and writes a repair plan. The Export Review Skill reviews candidate configuration. Formal drafts are written only after user confirmation.
2. **Stage 1 — build capabilities.** Build the collector, installer, internal capability modules, tests, pre-commit hook, Chinese and English documentation, and CI gates without changing the real HOME or installed software.
3. **Stage 2 — configure and install.** Generate repository-owned Zsh files from the repair plan, review the public/company diff, then run parameterless `./install.sh`. The script shows one combined summary and asks once with a default-`N` `y/N` prompt, followed by `./install.sh verify`.
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

Stage 2 must uniquely authorize the optional company repository and pass its absolute path to the root installer:

```zsh
DOTFILES_COMPANY_DIR=/absolute/path/to/company-dotfiles ./install.sh
```

<!-- section:configuration -->

## Configuration contract

- Personal configuration always lives in this public repository under `my_setup/`.
- Company configuration is an optional, separate Git worktree containing only company additions.
- Local configuration is fixed at `~/.config/dotfiles/local/parameters.zsh` and contains only secrets, accounts, and machine paths—not software or plugin choices.
- `.zshrc` uses the markers `dotfiles: company → dotfiles: personal → dotfiles: local` to preserve load order and the `company < personal < local` override priority.
- Every enabled plugin has a `dotfiles: plugin <name>` marker in `.zshrc`, ordered by the merged `load_order` value.
- Personal and company configuration each have at most one `zsh/plugins.toml`. Plugins pin a 40-character commit, and personal wins same-name conflicts.
- Personal and company configuration declare their own Brewfiles and tooling; personal wins same-name Homebrew conflicts.

Managed symlinks expose mise configuration under `~/.config/mise/conf.d/`, with a `10-` prefix for company and `20-` for personal. The personal `uv.toml` becomes the user-level uv configuration through a managed symlink, and the installer explicitly passes approved `.python-versions` entries to `uv python install`.

<!-- section:safety -->

## Safety boundaries

- Real installation runs only in a native macOS `arm64` session. Test mode accepts only an isolated HOME under `/private/tmp` or `/tmp`.
- Before replacing an existing `.zprofile` or `.zshrc`, the installer creates a timestamped copy that preserves a file or symlink's type and target.
- The parent directory of `parameters.zsh` must be mode `0700`, and the file must be mode `0600`. Scripts never display, copy, log, persist, or hash its contents; they only run a silent syntax check and normal shell loading.
- Public output must not contain company information, secrets, or machine-specific absolute paths.
- Services, databases, Homebrew services, and GUI application data are reported for manual handling and are never automatically started, stopped, migrated, or deleted.
- Retirement accepts only exact Intel formulae with explicit ARM replacement path and architecture evidence and no service/data record. Unknown items, project dependencies, NVM, Python Frameworks, global runtimes, old plugins, and `/usr/local` as a whole are retained by default.

<!-- section:verification -->

## Tests and release gates

```zsh
./tests/smoke.zsh
./tests/smoke.zsh --quick
.githooks/pre-commit
```

The full smoke test uses a temporary repository and HOME to verify default `N`, backups, symlinks, idempotency, company/personal merging, local-value non-disclosure, read-only retirement, and non-TTY blocking. Quick mode checks syntax, Markdown, section parity between the Chinese and English documentation, safety boundaries, and forbidden Intel runtime paths.

The pre-commit hook never installs dependencies. It requires `gitleaks 8.30.0`, installed from the Stage 2 mise declaration, and scans the current public tree. CI uses the same pinned version to scan both the current tree and complete Git history. Release requires quick checks, the complete smoke test, and CI to pass.

<!-- section:manual -->

## Manual work

The current Brewfile does not migrate nginx or redis service configuration or data. It also does not take over GUI application data, global npm CLIs, project runtimes, or legacy Python Frameworks. Handle the relevant data and verify ARM replacements before moving any exact item into Stage 3.
