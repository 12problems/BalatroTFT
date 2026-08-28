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
lock junctioned source files (silently breaking the next session's edits from taking
effect), and leaves stale lobby/connection state around.

## Design docs

See [docs/design/README.md](docs/design/README.md) for the mod's own design-doc index —
architecture, augments, traits, and the running `next-session-plan-N.md` series that
tracks what's been built and what's still open.
