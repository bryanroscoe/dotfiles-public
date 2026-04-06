# dotfiles-public

Shareable configs and tools from my dev setup. Works on macOS and Windows.

## What's included

### `.gitconfig`
Git aliases and settings. Highlights:
- `git cm "message"` — add all + commit
- `git ammend` — amend last commit (no edit)
- `git lg` — pretty graph log
- `git st` — short status
- `git track` — push + set upstream for current branch
- `git brn <name>` — fetch, checkout origin/develop, create new branch
- `git hist` — compact 10-line history

### `starship.toml`
[Starship](https://starship.rs/) cross-shell prompt configuration.

### `claude/statusline-command.sh`
A Powerline-style status line for [Claude Code](https://claude.ai/code) with a Catppuccin Mocha color scheme. Shows:
- Current directory and git branch/status
- Context window usage (progress bar)
- Active model
- API usage limits with reset times

Requires a [Nerd Font](https://www.nerdfonts.com/) and `jq`.

## Usage

Cherry-pick what you want, or clone and symlink:

```bash
git clone https://github.com/bryanroscoe/dotfiles-public.git

# Starship
cp dotfiles-public/starship.toml ~/.config/starship.toml

# Claude status line
cp dotfiles-public/claude/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh

# Git aliases (copy the [alias] section into your .gitconfig)
```

## See also

For full machine bootstrap with encrypted secrets, I use [chezmoi](https://www.chezmoi.io/) with a private dotfiles repo.
