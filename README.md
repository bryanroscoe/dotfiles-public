# dotfiles-public

Shareable configs and tools from my dev setup. Works on macOS and Windows.

## What's included

### Claude Code Status Line

<img width="1498" height="111" alt="Claude Code status line" src="https://gist.github.com/user-attachments/assets/ceb19afd-5326-487d-9f38-617698ebf7a6" />

A Powerline-style status line for [Claude Code](https://claude.ai/code) with a Catppuccin Mocha color scheme. Shows directory, worktree indicator, git branch/status, current task, context window usage (progress bar), active model, API usage limits with reset times, and clock.

**Requires [FiraCode Nerd Font Mono](https://github.com/ryanoasis/nerd-fonts/releases/latest)** — the context window progress bar uses FiraCode-specific glyphs (`U+EE00`–`U+EE05`) that only render in this font.

```bash
brew install --cask font-fira-code-nerd-font
```

#### Installation

```bash
cp claude/statusline.js ~/.claude/statusline.js
```

Add to `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "node \"~/.claude/statusline.js\""
  }
}
```

### Starship Prompt

[Starship](https://starship.rs/) single-line prompt with Catppuccin Mocha colors: directory, git branch/status, language versions, docker context, exit status, and command duration.

```bash
cp starship.toml ~/.config/starship.toml
```

### WezTerm

[WezTerm](https://wezfurlong.org/wezterm/) terminal config with Catppuccin Mocha theme, tmux-style `Ctrl+b` leader key, Powerline status bar with git branch, and full pane/tab management. Press `Leader + ?` for a built-in keybinding cheat sheet.

```bash
cp .wezterm.lua ~/.wezterm.lua
```

### `.gitconfig`

Git aliases and settings. Highlights:
- `git cm "message"` — add all + commit
- `git ammend` — amend last commit (no edit)
- `git lg` — pretty graph log
- `git st` — short status
- `git track` — push + set upstream for current branch
- `git brn <name>` — fetch, checkout origin/develop, create new branch
- `git hist` — compact 10-line history

## See also

For full machine bootstrap with encrypted secrets, I use [chezmoi](https://www.chezmoi.io/) with a private dotfiles repo.
