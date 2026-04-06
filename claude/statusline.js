#!/usr/bin/env node
// Compact Powerline statusline for Claude Code — Catppuccin Mocha
// Background-colored segments with Nerd Font glyphs and Powerline separators.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync, spawn } = require('child_process');

// Catppuccin Mocha palette (256-color indices)
const PAL = {
  crust: 234, mauve: 183, peach: 216, yellow: 223,
  green: 157, sapphire: 117, lavender: 189, red: 211,
};
const fg = n => `\x1b[38;5;${PAL[n]}m`;
const bg = n => `\x1b[48;5;${PAL[n]}m`;
const R = '\x1b[0m';
const BLINK = '\x1b[5m';

// Nerd Font glyphs
const SEP_R = '\uE0B0'; //
const SEP_L = '\uE0B2'; //
const BRANCH = '\uE0A0'; //
const ICO_STAGED = '\uF067'; //
const ICO_MODIFIED = '\uF040'; //
const ICO_DELETED = '\uF068'; //
const ICO_UNTRACKED = '\uF128'; //

// --- Powerline renderer ---
// segments: [{ color: 'mauve', text: '<already-styled content>', priority: 1-3 }]
function powerline(segs) {
  let out = '';
  for (let i = 0; i < segs.length; i++) {
    const cur = segs[i];
    if (i === 0) {
      out += `${fg(cur.color)}${SEP_L}${R}`;
    } else {
      out += `${fg(segs[i - 1].color)}${bg(cur.color)}${SEP_R}${R}`;
    }
    out += `${bg(cur.color)}${cur.text}${R}`;
  }
  if (segs.length) out += `${fg(segs[segs.length - 1].color)}${SEP_R}${R}`;
  return out;
}

// --- Main ---
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => (input += chunk));
process.stdin.on('end', () => {
  try {
    process.stdout.write(render(JSON.parse(input)));
  } catch {
    process.stdout.write('statusline error');
  }
});

function render(data) {
  const cwd = data.workspace?.current_dir || process.cwd();
  const model = data.model?.display_name || 'Claude';
  const sessionId = data.session_id || '';
  const rawRemaining = data.context_window?.remaining_percentage;
  const rawUsed = data.context_window?.used_percentage;
  const dark = fg('crust');
  const cols = process.stdout.columns || 120;

  const segs = [];

  // 1. Directory (basename for compactness)
  segs.push({ color: 'peach', text: `${dark} \uD83D\uDCC1 ${path.basename(cwd)} `, priority: 1 });

  // 2. Worktree indicator (priority 1 — always visible, signals dangerous state)
  const worktree = worktreeSegment(cwd, dark);
  if (worktree) segs.push({ color: 'red', text: worktree, priority: 1 });

  // 4. Git
  const git = gitSegment(cwd, dark);
  if (git) segs.push({ color: 'yellow', text: git, priority: 1 });

  // 5. Task (optional)
  const task = taskSegment(sessionId, dark);
  if (task) segs.push({ color: 'green', text: task, priority: 2 });

  // 6. Context bar
  const ctx = contextSegment(rawUsed, rawRemaining, dark);
  if (ctx) segs.push({ color: 'mauve', text: ctx, priority: 2 });

  // 7. Model (abbreviated)
  const m = model.match(/^(Opus|Sonnet|Haiku)\s+(\d+\.\d+)/i);
  const mLabel = m ? `${m[1][0].toUpperCase()}${m[2]}` : model;
  segs.push({ color: 'sapphire', text: `${dark} ${mLabel} `, priority: 1 });

  // 8. API Usage (optional, color-coded bg)
  const usage = usageSegment(dark);
  if (usage) segs.push({ ...usage, priority: 2 });

  // Filter segments based on terminal width
  // Priority 1 (always): dir, git, model
  // Priority 2 (>= 80): context bar, task, API usage
  // Priority 3 (>= 100): time
  const maxPriority = cols >= 100 ? 3 : cols >= 80 ? 2 : 1;
  const filtered = segs.filter(s => s.priority <= maxPriority);

  let out = powerline(filtered);

  // 9. Time (plain text after Powerline block, priority 3)
  if (cols >= 100) {
    const now = new Date();
    const h = now.getHours() % 12 || 12;
    const min = String(now.getMinutes()).padStart(2, '0');
    const ampm = now.getHours() >= 12 ? 'PM' : 'AM';
    out += ` ${fg('lavender')}${h}:${min} ${ampm}${R}`;
  }

  return out + '\x1b[K';
}

// --- Segment builders ---

function worktreeSegment(cwd, dark) {
  try {
    const gitEnv = { ...process.env, GIT_OPTIONAL_LOCKS: '0' };
    const opts = { cwd, encoding: 'utf8', timeout: 2000, stdio: ['pipe', 'pipe', 'pipe'], env: gitEnv };
    const commonDir = execSync('git rev-parse --git-common-dir', opts).trim();
    const gitDir    = execSync('git rev-parse --git-dir',        opts).trim();
    // In a worktree these differ (gitDir is inside .git/worktrees/<name>)
    if (commonDir === gitDir) return null;
    const toplevel  = execSync('git rev-parse --show-toplevel',  opts).trim();
    const name      = path.basename(toplevel);

    // Check for .wt-instance marker (confirms wt-managed worktree)
    let label = name;
    try {
      const marker = JSON.parse(fs.readFileSync(path.join(toplevel, '.wt-instance'), 'utf8'));
      if (marker.name) label = `${marker.name} \u2713`; // ✓ = wt-managed
    } catch {}

    return `${dark} \uE0A2 ${label} `; // \uE0A2 = Nerd Font branch-detached / worktree glyph
  } catch {
    return null;
  }
}

function gitSegment(cwd, dark) {
  try {
    const gitEnv = { ...process.env, GIT_OPTIONAL_LOCKS: '0' };
    const opts = { cwd, encoding: 'utf8', timeout: 2000, stdio: ['pipe', 'pipe', 'pipe'], env: gitEnv };

    let branch = execSync('git branch --show-current', opts).trim();
    if (!branch) branch = execSync('git rev-parse --short HEAD', opts).trim();
    if (!branch) return null;

    let s = `${dark} ${BRANCH} ${branch}`;

    // Status counts
    const porcelain = execSync(
      'git -c core.useBuiltinFSMonitor=false status --porcelain',
      { ...opts, timeout: 3000 },
    ).trim();
    if (porcelain) {
      let staged = 0,
        modified = 0,
        deleted = 0,
        untracked = 0;
      for (const line of porcelain.split('\n')) {
        if (!line || line.length < 2) continue;
        const x = line[0],
          y = line[1];
        if ('MARCD'.includes(x)) staged++;
        if (y === 'M') modified++;
        if (y === 'D') deleted++;
        if (x === '?' && y === '?') untracked++;
      }
      if (staged > 0) s += ` ${ICO_STAGED} ${staged}`;
      if (modified > 0) s += ` ${ICO_MODIFIED} ${modified}`;
      if (deleted > 0) s += ` ${ICO_DELETED} ${deleted}`;
      if (untracked > 0) s += ` ${ICO_UNTRACKED} ${untracked}`;
    }

    return s + ' ';
  } catch {
    return null;
  }
}

function taskSegment(sessionId, dark) {
  if (!sessionId) return null;
  try {
    const todosDir = path.join(os.homedir(), '.claude/todos');
    const prefix = sessionId + '-agent-';
    const files = fs
      .readdirSync(todosDir)
      .filter(f => f.startsWith(prefix) && f.endsWith('.json'))
      .sort()
      .reverse();
    if (!files.length) return null;

    const todos = JSON.parse(fs.readFileSync(path.join(todosDir, files[0]), 'utf8'));
    const active = todos.find(t => t.status === 'in_progress');
    if (!active?.activeForm) return null;

    let label = active.activeForm;
    if (label.length > 20) label = label.slice(0, 17) + '...';
    return `${dark} \uD83D\uDCCB ${label} `;
  } catch {
    return null;
  }
}

function contextSegment(rawUsed, rawRemaining, dark) {
  if (rawUsed == null && rawRemaining == null) return null;

  const used = rawUsed != null ? Math.round(rawUsed) : (rawRemaining != null ? (100 - Math.round(rawRemaining)) : null);
  if (used == null) return null;

  // 7-segment Fira Code progress bar (2 caps + 5 middles, EE00-EE05)
  // Single fg escape at start — no mid-bar ANSI to break glyph rendering
  const filledCount = Math.round((used / 100) * 7);
  const emptyCount = 7 - filledCount;
  let bar;
  if (filledCount === 0) {
    bar = `${fg('crust')}\uEE00${'\uEE01'.repeat(5)}\uEE02`;
  } else if (filledCount === 7) {
    bar = `${fg('crust')}\uEE03${'\uEE04'.repeat(5)}\uEE05`;
  } else {
    bar = `${fg('crust')}\uEE03${'\uEE04'.repeat(filledCount - 1)}${'\uEE01'.repeat(emptyCount - 1)}\uEE02`;
  }

  // Brain or blinking skull
  const icon =
    used > 90
      ? `${BLINK}\uD83D\uDC80${R}${bg('mauve')}`
      : '\uD83E\uDDE0';

  return ` ${icon} ${bar} ${dark}${used}% `;
}

function formatResetTime(isoStr) {
  if (!isoStr) return '';
  try {
    const d = new Date(isoStr);
    if (isNaN(d)) return '';
    const h = d.getHours() % 12 || 12;
    const ampm = d.getHours() >= 12 ? 'pm' : 'am';
    return `@${h}${ampm}`;
  } catch {
    return '';
  }
}

function formatResetDay(isoStr) {
  if (!isoStr) return '';
  try {
    const d = new Date(isoStr);
    if (isNaN(d)) return '';
    const now = new Date();
    const days = Math.round((d - now) / 86400000);
    const h = d.getHours() % 12 || 12;
    const ampm = d.getHours() >= 12 ? 'pm' : 'am';
    if (days <= 6) {
      const dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.getDay()];
      return `@${dayName} ${h}${ampm}`;
    }
    const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.getMonth()];
    return `@${mon} ${d.getDate()}`;
  } catch {
    return '';
  }
}

function usageSegment(dark) {
  const cachePath = '/tmp/claude-usage-cache.json';

  // Background refresh if stale or missing
  try {
    const stat = fs.statSync(cachePath);
    if ((Date.now() - stat.mtimeMs) / 1000 > 300) refreshUsageCache();
  } catch {
    refreshUsageCache();
  }

  try {
    const data = JSON.parse(fs.readFileSync(cachePath, 'utf8'));
    if (data.error) return null;
    const h5 = data.five_hour?.utilization;
    const d7 = data.seven_day?.utilization;
    if (h5 == null) return null;

    const h5used = Math.round(h5);
    const d7used = d7 != null ? Math.round(d7) : null;

    // Color bg by worst utilization (higher = worse)
    const worstUsed = d7used != null ? Math.max(h5used, d7used) : h5used;
    let bgName;
    if (worstUsed < 50) bgName = 'green';
    else if (worstUsed < 75) bgName = 'yellow';
    else if (worstUsed < 90) bgName = 'peach';
    else bgName = 'red';

    // "📊 5h: 6% @12pm | 7d: 35% @Mon 5pm"
    let text = `${dark} \uD83D\uDCCA 5h: ${h5used}%`;
    const h5reset = formatResetTime(data.five_hour?.resets_at);
    if (h5reset) text += ` ${h5reset}`;

    if (d7used != null && d7used >= 75) {
      text += ` | 7d: ${d7used}%`;
      const d7reset = formatResetDay(data.seven_day?.resets_at);
      if (d7reset) text += ` ${d7reset}`;
    }
    text += ' ';

    return { color: bgName, text };
  } catch {
    return null;
  }
}

function refreshUsageCache() {
  // Touch cache mtime immediately so parallel agents see it as fresh and skip refresh
  const cachePath = '/tmp/claude-usage-cache.json';
  try { const t = new Date(); fs.utimesSync(cachePath, t, t); } catch {
    try { fs.writeFileSync(cachePath, '{}'); } catch {}
  }
  try {
    const child = spawn('sh', ['-c',
      'TMP="/tmp/claude-usage-cache.json.tmp.$$" && ' +
        'TOKEN=$(/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null ' +
        '| /usr/bin/python3 -c "import sys,json; print(json.load(sys.stdin).get(\'claudeAiOauth\',{}).get(\'accessToken\',\'\'))") && ' +
        '[ -n "$TOKEN" ] && ' +
        'curl -s -X GET "https://api.anthropic.com/api/oauth/usage" ' +
        '-H "Accept: application/json" -H "Content-Type: application/json" ' +
        '-H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20" ' +
        '-o "$TMP" && ' +
        '/usr/bin/python3 -c "import sys,json; d=json.load(open(sys.argv[1])); sys.exit(0 if \'five_hour\' in d else 1)" "$TMP" && ' +
        'mv -f "$TMP" /tmp/claude-usage-cache.json || { rm -f "$TMP"; touch /tmp/claude-usage-cache.json; }',
    ], { detached: true, stdio: 'ignore' });
    child.unref();
  } catch {}
}
