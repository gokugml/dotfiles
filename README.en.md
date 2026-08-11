# Portable Apple Silicon Dotfiles

[中文文档](README.md)

<!-- section:overview -->

## Overview

This public repository stores shareable personal configuration and migration capabilities for moving reviewed Zsh, Homebrew, mise, uv, and Zsh plugins to an Apple Silicon Mac. Configuration used jointly with other people belongs in an optional separate shared repository, while machine secrets live only in a local file outside every repository.

Stage 1 applies the approved `zsh-repair-plan.md` to reviewed repository-owned Zsh files. It supports either the plain `zprofile` + `zshrc` names or the dotted `.zprofile` + `.zshrc` names, compares every source block against the targets plus local integrations before and after writing, and marks each adopted plan `Stage 1 applied` only after every validation passes. Stage 2 does not generate these files; the installer resolves the one complete pair under `my_setup/zsh/` and then creates the fixed HOME startup entries.

<!-- section:stages -->

## Four-stage workflow

1. **Stage 0 — analyze and export.** `./dump.sh` exports software, tooling, and plugin candidates read-only. A separate Zsh Skill collects value-free structural evidence plus a preservation manifest for third-party blocks and writes a repair plan. The Export Review Skill reviews candidate configuration. Formal drafts are written only after user confirmation.
2. **Stage 1 — apply the Zsh repair plan.** Update explicit user-provided targets when present. Otherwise, first confirm `zprofile`/`zshrc` or `.zprofile`/`.zshrc`, use the official installer in an isolated HOME to fetch the latest Oh My Zsh template, then apply the plan, compare source and target blocks, and review the complete diff. After all targets pass validation, each adopted plan is updated to the exact handoff field `> 状态：Stage 1 已应用`. It never changes real Zsh entries; only the fixed local parameters/integrations files may be backed up and updated after separate confirmation, and it does not install software.
3. **Stage 2 — configure and install.** Confirm that `my_setup/zsh/` contains exactly the complete pair selected in Stage 1, then run parameterless `./install.sh`. The script shows every exact target and one combined summary, asks once with a default-`N` `y/N` prompt, and uses `./install.sh verify` to check that every symlink, package, runtime, and plugin is installed at its native target. On Apple Silicon, residual Intel items are written to a machine-local `intel_to_be_retired.tsv`; their presence alone does not fail installation.
4. **Stage 3 — retire Intel software.** Read `intel_to_be_retired.tsv` as a hint, then run `./install.sh retire` for a fresh read-only inventory and preview. Run `./install.sh retire --apply` only after another review and an explicit confirmation in a real TTY. Normal installation and `verify` never trigger retirement.

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
- Local configuration is fixed under `~/.config/dotfiles/local/`: `parameters.zsh` stores secrets, accounts, and machine paths, while optional `integrations.zsh` stores Zsh blocks added by third-party installers. Neither declares desired software or plugins.
- If Intel software or paths remain on Apple Silicon, `verify` writes a deterministic mode-`0600` handoff at `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/intel_to_be_retired.tsv`. It is never tracked by Git and is not deletion authorization.
- Personal Zsh sources must contain exactly one complete pair: `my_setup/zsh/zprofile` + `zshrc`, or `my_setup/zsh/.zprofile` + `.zshrc`. Two complete pairs, mixed names, or an incomplete pair stop before confirmation and writes; the installer never guesses a priority or creates an alias copy.
- HOME always uses `~/.zprofile` and `~/.zshrc`, symlinked to the resolved repository files from the same pair.
- `.zshrc` uses `dotfiles: shared → dotfiles: personal → dotfiles: local` for declarative override order, while `integrations.zsh` loads through `dotfiles: local-integrations <phase>` hooks at the pre/post phases of zprofile and zshrc.
- Every enabled plugin has a `dotfiles: plugin <name>` marker in `.zshrc`, ordered by the merged `load_order` value.
- Personal and shared configuration each have at most one `zsh/plugins.toml`. Plugins pin a 40-character commit, and personal wins same-name conflicts.
- Personal and shared configuration declare their own Brewfiles and tooling; personal wins same-name Homebrew conflicts.

Managed symlinks expose mise configuration under `~/.config/mise/conf.d/`, with a `10-` prefix for shared and `20-` for personal. The personal `uv.toml` becomes the user-level uv configuration through a managed symlink, and the installer explicitly passes approved `.python-versions` entries to `uv python install`.

<!-- section:safety -->

## Safety boundaries

- Real installation runs only in a native macOS `arm64` session. Test mode accepts only an isolated HOME under `/private/tmp` or `/tmp`.
- Before replacing an existing `.zprofile` or `.zshrc`, the installer creates a timestamped copy that preserves a file or symlink's type and target.
- The local parent directory must be mode `0700`; existing `parameters.zsh` and `integrations.zsh` files must be mode `0600`. Scripts never display, copy, log, persist, or hash their contents; they only run a silent syntax check and normal shell loading.
- Public output must not contain shared-repository-only information, secrets, or machine-specific absolute paths.
- Services, databases, Homebrew services, and GUI application data are reported for manual handling and are never automatically started, stopped, migrated, or deleted.
- Legacy Intel paths may remain, but no managed command or symlink may target them. Their exact paths and retention reasons are recorded in `intel_to_be_retired.tsv` for Stage 3 to revalidate.
- Retirement accepts only exact Intel formulae with explicit ARM replacement path and architecture evidence and no service/data record. Unknown items, project dependencies, NVM, Python Frameworks, global runtimes, old plugins, and `/usr/local` as a whole are retained by default.

<!-- section:verification -->

## Tests and status reporting

```zsh
./tests/smoke.zsh
./tests/smoke.zsh --quick
.githooks/pre-commit
```

The full smoke test uses a temporary repository and HOME to verify both plain and dotted repository source names, ambiguity/mixed-name blocking, default `N`, backups, symlinks, idempotency, shared/personal merging, local-value non-disclosure, read-only retirement, and non-TTY blocking. Quick mode checks syntax, Markdown, section parity between the Chinese and English documentation, safety boundaries, and forbidden Intel runtime paths.

The pre-commit hook never installs dependencies. It requires `gitleaks 8.30.0`, installed from the Stage 2 mise declaration, and scans the current public tree. CI uses the same pinned version to scan both the current tree and complete Git history. The Stage 2 final report includes quick-check, full-smoke, pre-commit, and CI status, but missing, unrun, or failing CI does not block installation or Stage 2 completion after its A/B verification succeeds.

<!-- section:manual -->

## Manual work

The current Brewfile does not migrate nginx or redis service configuration or data. It also does not take over GUI application data, global npm CLIs, project runtimes, or legacy Python Frameworks. Handle the relevant data and verify ARM replacements before moving any exact item into Stage 3.
