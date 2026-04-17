# macOS Dev Bootstrap

Bootstrap a macOS developer shell for standard users without `sudo`. The installer is safe to re-run and keeps shell changes isolated in a managed block.

## Requirements

- macOS on Apple Silicon or Intel
- Xcode Command Line Tools
- Internet access

Install Xcode CLT if needed:

```bash
xcode-select --install
```

## Install

Quick install:

```bash
curl -fsSL https://raw.githubusercontent.com/h2pl69/mdb-gNLAewG2/main/mdb.sh | bash -s -- --install
```

Manual install:

```bash
git clone https://github.com/h2pl69/mdb-gNLAewG2.git
cd mdb-gNLAewG2
bash install.sh
```

When the script finishes, restart your terminal or load the updated shell config:

```bash
source ~/.zshrc
```

## What Gets Installed

- Homebrew in `~/.homebrew`
- Oh My Zsh in `~/.oh-my-zsh`
- `zsh-completions`, `zsh-autosuggestions`, and `zsh-syntax-highlighting`
- Powerlevel10k
- `uv`
- Bun
- Claude Code
- Claude settings from `config/claude-settings.json`

## Shell Integration

If `~/.zshrc` existed before installation, it is backed up once to `~/.zshrc.bak`. Re-running the installer updates only the managed block and skips components that are already present.

## Re-run Safely

`install.sh` is idempotent. Running it again preserves existing installs, avoids destructive changes, and refreshes the managed shell configuration when needed.

## Uninstall

Quick uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/h2pl69/mdb-gNLAewG2/main/mdb.sh | bash -s -- --uninstall
```

Manual uninstall:

```bash
bash uninstall.sh
```

The uninstaller is **interactive**. It asks for confirmation before removing anything, and the bundled Oh My Zsh uninstaller asks its own confirmation too. Both prompts read from your terminal via `/dev/tty` when stdin is not a TTY, so the `curl | bash` form above still works and still asks you to confirm.

The uninstaller removes managed components when present and restores `~/.zshrc` from `~/.zshrc.bak` when a backup exists. If no backup exists, it leaves `~/.zshrc` unchanged.

> A fully automated uninstall without a controlling terminal is not supported by design. If the script cannot reach a TTY, it exits with an `[ERROR]` and a non-zero status rather than guessing your intent.

## Troubleshooting

### The script exits with an error

Read the `[ERROR]` message, fix the reported dependency or network issue, then run the installer again.

### Homebrew install fails

Verify Xcode CLT is installed:

```bash
xcode-select -p
```

If the command does not print a path, install the tools and retry.

### `claude` is not available after install

Restart the terminal or run `source ~/.zshrc`.

### zsh plugins are not loading

Confirm `~/.oh-my-zsh` exists.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
