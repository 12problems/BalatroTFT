# BalatroTFT — agent notes

## Controlling a live instance for testing

**Read [docs/design/claudecontrol-guide.md](docs/design/claudecontrol-guide.md) before
driving or testing a running instance.** It's the consolidated reference for controlling
BalatroTFT via ClaudeControl (`cctl`) without relying on screenshots — what's actually
installed in this environment vs. ClaudeControl's own docs describe, the real
`TFT.*`/`MPAPI.*` entry points to drive directly, and every timing/UI-click gotcha this
project has hit live (a 4x default game-speed setting that throws off timer-based tests,
deferred/animated mutations reading stale if checked synchronously, fanned-card click
flakiness, an `ipairs`-stops-at-nil bug worth knowing about before it bites again, etc.).

Machine-level setup (mod deployment, multi-instance launch, the local MP server) lives in
Claude's own persistent memory (`claudecontrol-testing-setup.md`,
`balatro-multi-instance-launch.md`) — the guide above assumes that's already done and
covers what to do once instances are actually up.

## Before handing control back to the user

Whenever a turn is ending (work done or blocked) — close every launched Balatro instance:

```powershell
Get-Process Balatro -ErrorAction SilentlyContinue | Stop-Process -Force
```

Not needed between individual test steps within the same turn — only right before control
actually returns to the user. Leaving instances running afterward wastes resources, can
lock a live instance's own `dev-mods` copy open, and leaves stale lobby/connection state
around.

## No junctions or symlinks, ever (hard rule, 2026-08-28)

Mods are deployed as real copies via `deploy-dev-mods.ps1` into
`dev-mods\inst<N>\`, launched with `LOVELY_MOD_DIR` pointing at that per-instance
folder — never junctioned into the real `%AppData%\Roaming\Balatro\Mods`. A junction
there has silently wiped the real source checkout before, and a third-party mod
manager on this machine actively cycles that same folder and has clobbered this
setup in the past too. See [docs/design/claudecontrol-guide.md](docs/design/claudecontrol-guide.md)'s
"Multi-instance launch" section for the full recipe. **Run `deploy-dev-mods.ps1`
after every code edit, before relaunching** — there's no junction anymore to make
edits appear automatically.

## Design docs

See [docs/design/README.md](docs/design/README.md) for the mod's own design-doc index —
architecture, augments, traits, and the running `next-session-plan-N.md` series that
tracks what's been built and what's still open.
