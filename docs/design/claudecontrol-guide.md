# Controlling a live BalatroTFT instance without screenshots

A self-contained reference for driving/testing a running BalatroTFT instance (solo or
real multiplayer) via ClaudeControl (`cctl`), leaning on text-based state inspection
(`eval`/`ui`/`state`) instead of screenshots wherever possible. Screenshots cost real
visual-token budget and should be the exception, not the default verification step —
see "When you actually need a screenshot" at the end.

This doc assumes the machine setup already documented in Claude's own memory
(`claudecontrol-testing-setup.md`, `balatro-multi-instance-launch.md`) — junctioned mod
deployment, the MPAPI dev-auth override in `core.lua`, the local MP server. Read those
first if starting completely cold. This doc is the layer on top: how to actually **drive**
BalatroTFT once instances are up, and BalatroTFT-specific gotchas that aren't true of
vanilla Balatro or other BMP-family mods.

## What's actually available in this environment

ClaudeControl's own docs (`ClaudeControl_src/ClaudeControl/README.md` and `wiki/`)
describe a much richer `test:`/`ctx:` object API (`highlight_by_rank`, `play_hand`,
`buy_card`, `spawn_joker`, `mock`, `skip_to`, etc.) — that API is provided by a **separate
mod called "Integration"**, built on top of ClaudeControl. **Integration is NOT installed
on this machine** (confirmed: `Get-ChildItem` on the real `Mods/` folder shows
ClaudeControl/DebugPlus/JokerDisplay/MultiplayerAPI/Steamodded/BalatroTFT only — no
Integration — and its source isn't checked out anywhere under `BMPGithub/` either). Every
`cctl script` this whole project has ever run receives a `ctx` vararg per ClaudeControl's
own `control/script.lua`, but **calling any `ctx:` method on it will error — there's
nothing installed to answer those calls.**

**What that leaves, confirmed working throughout this whole project:**

| Command | What it does |
|---|---|
| `cctl ping` | Connection check + current state name |
| `cctl state` | Structured dump: money, hand, jokers, shop, round info, multiplayer |
| `cctl ui` / `cctl ui --buttons` / `cctl ui "text"` | Text dump of visible UI nodes — text, button func names, pixel rects |
| `cctl eval '<lua expr>'` | Evaluate and return any Lua expression |
| `cctl script <path>` | Run a whole Lua file; a bare chunk (no `function(ctx)` wrapper) works fine, just don't call `ctx:` methods on the vararg |
| `cctl press <G.FUNCS name>` | Call a button handler directly by name — **the primary interaction method**, per ClaudeControl's own README |
| `cctl click <x> <y>` / `--id <id>` / `--label "text"` | Click a UI node |
| `cctl key <name>` | Simulate a keypress (needed for real text-input fields) |
| `cctl shot [name]` | Screenshot, saved to the Balatro root dir — the expensive one, see below |
| `--target host/guest/both/all/auto/<N>/<comma-list>` | Route a command at one or more instances **in a single cctl invocation** — must come before the subcommand |

**Efficiency note for future sessions**: this project's own past testing mostly issued
separate `--port 34343 ...` / `--port 34344 ...` calls back to back. `--target both` /
`--target all` do the same thing in one `cctl` invocation when the exact per-instance
values don't need separate handling — prefer that where it fits.

## Reading state without ever looking at pixels

- **Never screenshot to check a value** — `cctl eval 'G.GAME.dollars'` or
  `cctl state` answers it directly, exactly, every time.
- **Use `cctl ui` (optionally filtered: `cctl ui "OPEN"`) instead of a screenshot** to find
  a button's exact `@x,y wxh` rect before clicking, or to confirm a label/tab/row of text
  is actually present. It's plain text — zero image tokens — and was the single biggest
  token-saver once adopted mid-project.
- **Prefer `cctl click --label "exact text"` over pixel coordinates** when a node's label
  is unique on screen — sidesteps needing to compute a center point at all. Falls back to
  raw `x y` coordinates (from a `cctl ui` rect) when a label repeats or the target is a
  bare icon/graphic with no text.
- **Prefer `cctl press <G.FUNCS name>` over any click at all** whenever a real button
  handler exists — confirmed throughout this project to work identically whether or not
  the button is currently visible, and immune to the layout-shifted-since-my-last-read
  class of mistake pixel clicking is prone to (see "Fanned/overlapping card UI" below).
- **For a value that changes on a deferred/animated timeline** (see the dedicated section
  below), re-check with a fresh `eval` after a short real sleep — never trust a value read
  in the same call that triggered the change.

## BalatroTFT-specific entry points (the actual API surface to drive against)

All of these are globals on the running instance, callable via `eval`/`script` directly
— confirmed live throughout this project, not guessed at.

**Core state:**
- `TFT.get_state()` — the per-run save-data table (`life_total`, `level`, `xp`,
  `augments_picked`, `round_index`, `is_multiplayer`, `pending_*` overlay state, etc.)
- `TFT.is_run_active()` — whether a TFT-managed run is currently in progress
- `TFT.ensure_sequence()` — the full round-by-round sequence for this match;
  `TFT.current_round_def()` — the round definition at the current index

**Round flow / advancing without playing hands:**
- `TFT.round_flow_advance()` — the real function poll.lua calls after a round scores;
  callable directly for tests, but prefer just forcing `G.GAME.chips` and playing a real
  (even trivial) hand when a round genuinely needs to be "won" — see "Winning a round
  without RNG-fighting" below.
- `TFT.open_augment_checkpoint(round_def)` / `TFT.open_carousel(round_def)` /
  `TFT.open_level5_voucher_choice()` / `TFT.open_level8_deck_refinement()` /
  `TFT.open_level9_reward()` — open any picker overlay directly, without needing to
  actually reach that exact round/level through real play. Each one's own file
  (`objects/augments/checkpoint.lua`, `objects/round_flow/carousel.lua`,
  `objects/round_flow/level_rewards.lua`) documents its own `state.pending_*` shape and
  `G.FUNCS.tft_pick_*`/`tft_confirm_*` handlers for driving the actual pick programmatically
  instead of clicking.

**Multiplayer:**
- `MPAPI.create_lobby(TFT.id, {max_players=8})` / `MPAPI.join_lobby(TFT.id, code)` — real
  lobby create/join; both are **async**, the returned lobby object's `.code` isn't
  populated until a beat later (`sleep` ~2-3s, or poll `MPAPI.get_current_lobby()`)
- `lobby:action(MPAPI.ActionTypes['tft_<key>']):broadcast({...})` — fire any of this mod's
  own real network actions directly (see `objects/actions/*.lua` for the full list —
  `tft_start_game`, `tft_round_result`, `tft_carousel_offer`/`tft_carousel_turn`/
  `tft_carousel_pick`, `tft_life_total_change`, `tft_joker_ownership`,
  `tft_xp_level_change`, etc.) — this is how every cross-client mechanic in this project
  has actually been verified, not by clicking through two windows in lockstep
- `TFT.LobbySettings` — the host's working settings table (deck/stake/bonus
  money/timer), synced via `lobby:set_metadata`/`get_metadata`
- `G.FUNCS.tft_create_lobby()` / `tft_join_lobby_from_clipboard()` /
  `tft_join_lobby_from_input()` / `tft_start_game()` — the real UI button handlers,
  `press`-able directly

## Winning a round without RNG-fighting

Directly assigning `G.GAME.chips = <target>` does **not** by itself end the round — the
game still needs a real scored hand to trigger the win-check. The reliable, real recipe
used throughout this project:

```lua
-- after selecting a blind, at SELECTING_HAND:
G.GAME.chips = 100         -- or whatever the blind's chip target is
-- then select ANY 1-5 cards and play them for real — the click sequence below
-- (or `cctl press play_cards_from_highlighted` after selecting cards) triggers
-- vanilla's own real scoring/win path, which now clears immediately since the
-- pre-set chip count already exceeds the target.
```

Selecting cards still needs real coordinate clicks (no `highlight_by_rank` equivalent is
installed) — use `cctl ui` to read the hand's real card rects first, don't guess spacing.

## Applying an augment/voucher/effect without going through its real UI trigger

Two safe, source-verified shortcuts, and one to avoid:

- **Vouchers**: `Card.apply_to_run(nil, G.P_CENTERS[voucher_key])` applies the real
  gameplay effect with zero UI/animation side effects (confirmed via reading the real
  installed `card.lua` — the function's own `self and copy_card(self) or Card(0,0,...)`
  fallback exists specifically for a nil `self`). **Don't** call `card:redeem()` for this
  — it sets `G.STATE = G.STATES.SMODS_REDEEM_VOUCHER` and drives a multi-second real
  animation sequence meant for an actual shop-redeem moment, which will fight any picker
  overlay already on screen.
- **Opening a shop pack / redeeming a shop voucher for real** (i.e. as an actual purchase,
  not a free grant): call `G.FUNCS.use_card({config={ref_table=<the real shop Card
  object>}})` directly instead of clicking. This is the same function a real click
  dispatches to, confirmed by reading `functions/button_callbacks.lua`, and sidesteps the
  fanned/overlapping-card click flakiness described below entirely.
- **Granting an augment's effect directly**: `TFT.get_augment(key).apply()` — every
  augment's real `apply` function, callable standalone; this is what checkpoint.lua itself
  calls when a real pick is made.

## Known gotchas (all confirmed live, not theoretical)

### `G.SPEEDFACTOR` / `G.SETTINGS.GAMESPEED` can be far from 1

Observed live in this environment: **`G.SPEEDFACTOR = 4`** by default (unrelated to
anything BalatroTFT does — likely a ClaudeControl/testing-convenience baseline; the
separate, uninstalled "Integration" framework's own default test speed is `512`, for
reference on how wide this can swing). Any `G.E_MANAGER:add_event({trigger='after', delay=
N, ...})`-based timer (real vanilla ones, and every host-side timer BalatroTFT's own
Carousel draft/round-timer code schedules) resolves in **real elapsed seconds ÷
SPEEDFACTOR**, not N real seconds. A "10 second" timer can visibly resolve in ~2.5s. This
produced multiple false "it broke early" readings before being tied back to this setting.
**Check `cctl eval 'return G.SPEEDFACTOR'` before concluding a timing-based feature is
buggy.** Set both to `1` via eval for a test that needs the real, full-length window:
`cctl eval 'G.SPEEDFACTOR=1; G.SETTINGS.GAMESPEED=1'`.

### Deferred/animated mutations read stale if checked synchronously

`ease_dollars`, `Card:start_dissolve`'s real removal (`self:remove()` fires at
`1.05 * 0.7 * dissolve_time_fac` seconds in, NOT synchronously), several `CardArea`/`Card`
config field writes — none of these take effect within the same `eval`/`script` call that
triggered them. **Always re-check in a separate call after a real sleep** (scaled by
`G.SPEEDFACTOR` per above). A fixed guessed delay is itself fragile — prefer polling a
real completion signal (e.g. `card.removed`, a real state flag) over a hardcoded sleep
when the exact resolution time matters for correctness, not just for a manual test.

### `CardArea:draw()` does not generically render `self.children`

Unlike `Card:draw()` (which loops all of `self.children` and draws each), the real
installed `cardarea.lua`'s `CardArea:draw()` only ever explicitly draws one hardcoded
child by name (`self.children.area_uibox`, its own card-count display). Attaching a custom
UIBox as a `CardArea`'s child (e.g. to `G.deck`) needs an explicit hook on `CardArea:draw`
itself to actually call `:draw()` on it — a plain attach is silently invisible.

### Fanned/overlapping card UI (hand, deck-view pickers, shop rows after a purchase) is flaky to click

Real coordinate clicks on cards in a fanned hand, a multi-suit deck picker, or shop rows
that just reflowed after a purchase are genuinely unreliable — clicks can land on the
wrong (visually-behind) card, or silently no-op, especially several in a row without a
fresh `cctl ui`/screenshot between each. **Prefer, in order:** (1) a direct function call
that bypasses the click entirely (`G.FUNCS.use_card({config={ref_table=card}})`,
`area:add_to_highlighted(card)`), (2) a fresh `cctl ui` read immediately before each click
(never reuse coordinates from an earlier read once the layout could have changed), (3)
`cctl click --label` when the target has unique text. Never click 2+ fanned cards back to
back off one stale coordinate read.

### `ipairs` stops at the first `nil` hole in a table constructor

Bit us for real once this project (Run Info's Standings tab silently never rendered): a
table literal like `{a, b, (cond and c or nil), d}` puts a literal `nil` in that slot when
`cond` is false, and `ipairs` — which `create_tabs` and plenty of other vanilla UI
builders use to walk their node arrays — stops dead at the first nil, silently dropping
everything after it. When building on top of a vanilla list that has a conditional-nil
entry (vouchers' Stake tab is one real example), put new unconditional entries **before**
it, never after.

### BalatroTFT replaces Ante/Blind — vanilla ante-based navigation doesn't map onto it

Real vanilla mechanics keyed on `G.GAME.round_resets.ante` (and, if it were ever
installed, the uninstalled Integration framework's own `test:skip_to(ante, blind)`) exist
for vanilla's own Ante/Blind structure. BalatroTFT replaces that with its own stage/round
sequence (`state.round_index` into `TFT.ensure_sequence()`), and
`objects/round_flow/hooks.lua`'s `TFT.apply_current_round_blind_state` force-pins
`G.GAME.round_resets.ante` to match the current TFT stage every round — so driving ante
directly will just get overwritten. **To jump to a specific round for testing, set
`TFT.get_state().round_index` directly** (and call the relevant `TFT.open_*`/advance
function for that round type) instead of touching ante/blind state.

### MPAPI actions are asynchronous — never assume same-call delivery

Every `lobby:action(...):broadcast(...)` (including loopback to the sender) resolves via a
real, if fast, MQTT round-trip — never synchronously within the calling `eval`. Always
`sleep` at least ~1-1.5s (real, unscaled by `G.SPEEDFACTOR` — MQTT isn't gated by that)
before checking a value the broadcast was supposed to set on ANY client, including the
one that sent it.

### Global RNG overrides contaminate unrelated real rolls in the same call chain

Overriding `pseudorandom` (or similar) globally to force a specific outcome, then
exercising it through a real vanilla call chain (e.g. `SMODS.create_card`), also forces
every OTHER unrelated roll inside that same chain (e.g. vanilla's own independent edition
roll). If the logic under test is reachable as its own standalone function, call it
directly against an already-existing object instead of forcing global RNG through the
full real chain — sidesteps the contamination entirely. (This is exactly the class of bug
the uninstalled Integration framework's `test:mock` is designed to solve properly — it
queues a value consumed by exactly one specific named function's next real call, not a
blanket override — worth installing if this keeps coming up; see "Integration" note above.)

## Multi-instance launch (this machine only)

`cctl launch N` itself is **unreliable on this machine** (the WSL→`explorer.exe`
indirection it uses repeatedly failed to spawn a process at all, root cause never fully
diagnosed) — don't rely on it for the actual process spawn. Its own `ping`/`eval`/
`press`/`ui`/`--target` machinery against already-running instances works fine once
they're up. Launch instances directly from Windows-side PowerShell instead, wrapped in a
retry loop (the shared `lovely/dump` directory lock is intermittently held across
instances — full root cause and the proven fix in Claude's own memory,
`balatro-multi-instance-launch.md`):

```powershell
$bat = Join-Path $env:TEMP "cctl_manual_instN.bat"
Set-Content -Path $bat -Value @('@echo off','set BMP_IMPERSONATE_NAME=PlayerNNN','start "" "Y:\Applications\Steam\steamapps\common\Balatro\Balatro.exe"') -Encoding ASCII
$up = $false
for ($i = 1; $i -le 8; $i++) {
    Remove-Item "C:\Users\rob\AppData\Roaming\Balatro\Mods\lovely\dump" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Users\rob\AppData\Roaming\Balatro\Mods\lovely\game-dump" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath $bat
    for ($t = 0; $t -lt 12; $t++) {
        Start-Sleep -Milliseconds 1500
        if ((Test-NetConnection -ComputerName 127.0.0.1 -Port <thisInstancesPort> -WarningAction SilentlyContinue).TcpTestSucceeded) { $up = $true; break }
    }
    if ($up) { break }
    Get-Process Balatro -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $hostPid } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
```

Instance 1 = port 34343 (host, still needs `BMP_IMPERSONATE_NAME` too against the local
dev server — real Steam auth fails against it), instance 2 = 34344, instance N =
`34343+(N-1)`. Drive each from the Bash tool via
`wsl.exe -e bash -c "python3 <ClaudeControl_src path>/cctl.sh --port <N> <command>"`
(the Bash tool itself is Git Bash, not real WSL, and has no `/mnt/c` — always go through a
`wsl.exe -e` subshell to reach `cctl.sh`, or use ClaudeControl's own `--target` flag
against one real `cctl` invocation once instances are up).

**Always close every instance at the end of a session or before a code-change relaunch**
(`Get-Process Balatro | Stop-Process -Force` via PowerShell with
`dangerouslyDisableSandbox: true`) — junctioned source files can be locked open by a live
instance, silently breaking the next edit from taking effect, and stale instances break
the standard port-number assumptions for the next launch.

## When you actually need a screenshot

Reserve `cctl shot` for:
- Confirming real card art/visual layout renders correctly (a picker showing real
  enhancements/editions, not just that the underlying data is right)
- A deliverable the user explicitly asked to see (e.g. "a screenshot of the lobby with 8
  players")
- Debugging a click that isn't landing where a stale `cctl ui` rect said it would —
  and even then, prefer a fresh `cctl ui` re-read first; only fall back to a screenshot if
  the text dump itself doesn't explain what's on screen

Don't screenshot to confirm a click registered, a value changed, or an overlay closed —
`eval` answers all of those exactly, every time, for a fraction of the cost.
