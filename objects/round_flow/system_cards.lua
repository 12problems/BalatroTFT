-- General-purpose home for every pseudo-Joker "system" card BalatroTFT itself
-- creates -- explicit user request, 2026-09-01: the Traits Engine (and any
-- future per-augment pseudo-Joker technical.md's original design sketched,
-- "up to 3 per player") needs to be fully immune to anything that could
-- sell it, or that Ankh/Wheel of Fortune/Invisible Joker/etc. could select,
-- duplicate, or destroy -- basically anything that could ever touch it at
-- all. Modeled on MultiplayerAPI's own separate "phantom" showcase CardArea
-- (BalatroMultiplayerAPI/api/synced/phantom.lua) rather than that same
-- file's alternate "masking" approach (tagging a special edition and
-- patching find_card/poll_edition/etc. one call site at a time) -- a real,
-- independent CardArea object is far more robust here, since it makes these
-- cards invisible for free to every piece of code (vanilla's own, or any
-- other mod's) that references `G.jokers`/`G.jokers.cards` by identity,
-- confirmed by reading the real installed card.lua: Ankh, Wheel of Fortune,
-- Invisible Joker, and the sell-button visibility check
-- (`self.area == G.jokers`, line ~4160) all key off that exact same G.jokers
-- identity, not a `type`/tag field on the card -- so simply not being IN
-- that table defeats all of them at once, including anything else built the
-- same way in the future, with nothing further to patch per-effect.
--
-- THE ONE REAL COST of moving a card out of G.jokers, flagged explicitly
-- (this is exactly the "may want a whole rework of how traits get applied"
-- risk the user's own request called out): vanilla's actual scoring
-- dispatch (functions/state_events.lua, inside G.FUNCS.evaluate_play) does
-- NOT walk some generic "every Joker-like area" list -- it has `G.jokers`
-- hardcoded directly into several separate `for k=1,#G.jokers.cards do`
-- loops spread across that one (very long) function, for exactly the three
-- calculate() contexts engine.lua's Traits Engine actually relies on
-- (joker_main: once per hand; individual: once per scoring card;
-- repetition: retriggers). None of those loops are their own separately
-- nameable/wrappable function -- G.FUNCS.evaluate_play as a whole is the
-- smallest real hook point. So THIS file makes the system-card area
-- temporarily, synchronously borrow G.jokers.cards for the exact duration
-- of one G.FUNCS.evaluate_play() call (confirmed via the real source that
-- this function's entire body -- both per-card loops, all the calculate_joker
-- dispatch -- runs synchronously in one call; the delay()/juice animations
-- inside it only pace already-decided numbers being displayed, not the
-- calculation itself) -- splice in right before, splice back out right
-- after, so vanilla's own real scoring code runs completely unmodified and
-- reaches these cards for exactly those three contexts, while they're
-- physically absent from G.jokers everywhere else (shop, Ankh/WoF/Invisible
-- Joker's own random-selection code, the sell button, the "X/Y Joker slots"
-- display, etc.) essentially 100% of the time. Any FUTURE system card that
-- needs a DIFFERENT calculate_joker context (e.g. selling_card, buying_card,
-- end_of_round) would need this same splice technique extended to that
-- other G.FUNCS entry too -- not automatically covered by this file.
--
-- BONUS, discovered live while implementing this (2026-09-01): the Traits
-- Engine living directly in G.jokers this whole time meant it was actually
-- consuming one of the player's real Joker slots (confirmed live:
-- `#G.jokers.cards` counted it, `G.jokers.config.card_limit` did not exclude
-- it) -- moving it out fixes this as a free side effect, not something
-- separately implemented.

-- Positioned beneath G.consumeables (explicit user request, item 5's own
-- stage-roadmap move is relative to THIS area's position, so this needs to
-- land first). Same real CardArea(...) constructor vanilla itself uses for
-- G.jokers/G.consumeables (confirmed via the real installed game.lua).
-- highlight_limit = 0: nothing in here should ever be selectable/draggable
-- by the player at all. card_limit = 1 (explicit user request, 2026-09-01):
-- there's only ever one system card today (the Traits Engine); capping the
-- area at 1 keeps its own default slot-count display ("N/1") from ever
-- implying more cards belong here than actually do. A genuine second system
-- card (a future per-augment pseudo-Joker) would need this raised.
--
-- CAUGHT live (a real recurrence of this project's own documented "deferred
-- mutation reads stale if checked synchronously" gotcha -- it bit the
-- diagnosis of THIS bug twice in a row before landing on the real cause):
-- applying the Negative edition (TFT.add_system_card, below) grants +1 to
-- WHATEVER area the card lives in via a real deferred event, not the
-- hardcoded G.jokers/G.consumeables-only, synchronous assignment the static
-- vanilla source reference suggests (confirmed live: an unrelated throwaway
-- CardArea showed card_limit unchanged read back in the SAME eval call, but
-- had grown from 1 to 2 when re-checked a few real seconds later in a
-- separate call) -- almost certainly a genuine Steamodded-level patch this
-- project's own static "Balatro Source" reference copy doesn't reflect.
-- Applying the edition BEFORE add_to_deck() (still done below, see
-- TFT.add_system_card's own comment) does NOT avoid this after all. Rather
-- than chase the exact real patched call site, this is pinned back down to
-- 1 unconditionally every frame in the Game:draw hook below -- cheap (one
-- field compare) and immune to whatever the actual mutation path turns out
-- to be, including any future one.
function TFT.ensure_system_card_area()
	if G.STAGE ~= G.STAGES.RUN then return nil end
	if TFT.system_cards then return TFT.system_cards end
	TFT.system_cards = CardArea(0, 0, G.consumeables.T.w, 0.95 * G.CARD_H,
		{ card_limit = 1, type = 'joker', highlight_limit = 0 })
	TFT.position_system_card_area()
	pcall(TFT.attach_stage_roadmap_display)

	-- Real, confirmed double-render fix (explicit user feedback: "the joker
	-- for some reason has a double-joker effect on it") -- see the fuller
	-- story in the Game:draw hook's own comment below. First attempt only
	-- gated OUR OWN explicit draw call from Game:draw, which did NOT fix the
	-- visible duplicate -- proof the real second caller invokes
	-- TFT.system_cards:draw() directly, bypassing that call site entirely
	-- (its actual origin was never root-caused). Fixed for real by wrapping
	-- THIS INSTANCE's own :draw method directly (shadowing the CardArea
	-- class method just for this one object, the same technique this file's
	-- own earlier live diagnostic used to first measure the double-call) --
	-- every caller, ours or the mystery one, now funnels through the same
	-- per-frame dedup check.
	local orig_draw = TFT.system_cards.draw
	local last_drawn_frame = -1
	TFT.system_cards.draw = function(self)
		local frame = G.FRAMES and G.FRAMES.MOVE or 0
		if frame == last_drawn_frame then return end
		last_drawn_frame = frame
		return orig_draw(self)
	end

	return TFT.system_cards
end

-- Stage roadmap (item 5, explicit user request, 2026-09-01; REWORKED again
-- the same day per explicit follow-up feedback: "I do not like the stage
-- display being tied to a joker" / "I liked the previous box it resided in,
-- so you can just move that below the new card area"). The first version of
-- this move attached the roadmap as a CHILD of TFT.system_cards (the same
-- "float a UIBox as a child of a real Moveable" technique hud.lua's own
-- TFT.attach_deck_level_display uses for G.deck) -- functionally fine, but
-- it made the display's own existence/position depend on the system-card
-- CardArea (and, by extension, read as "belonging to" the Traits Engine
-- card sitting in it), which is exactly the coupling being objected to here.
-- It also lost the real background/frame the OLD (pre-2026-09-01,
-- HUD-Ante-box) version had for free by inheriting vanilla's own Ante
-- column chrome -- this version's bare G.UIT.ROOT with colour=G.C.CLEAR
-- rendered as loose floating text, not "a box".
--
-- Fixed both at once: this is now a fully STANDALONE UIBox, wrapping the
-- exact same TFT.build_hud_stage_nodes() content in its OWN rounded
-- container (recreating the boxed look the old Ante-column chrome used to
-- provide for free) -- NOT parented to TFT.system_cards or any Card/
-- CardArea at all. Positioned via a plain absolute T = {x, y} (confirmed via
-- the real installed engine/ui.lua: UIBox:init reads `args.T` directly via
-- `Moveable.init(self, {args.T})`, and when no config.parent/major is given,
-- `args.config.major` defaults to `self` -- i.e. it aligns relative to its
-- own already-given T, not to any other object), computed once from
-- TFT.system_cards's own T.x/y/w/h at creation and re-derived on every
-- set_screen_positions() call, the same way TFT.position_system_card_area
-- already re-derives ITS OWN position from G.consumeables -- a one-time
-- coordinate lookup, not an ongoing parent/child relationship.
--
-- REWORKED again the same day (explicit follow-up feedback: too long/too
-- dark): the inner column no longer forces `minw = TFT.system_cards.T.w` --
-- that minw was the actual cause of the box reading as too long (it padded
-- the box out to the full card-area width regardless of how few pips a
-- given stage's content actually needed, e.g. Stage 1's 3-round strip);
-- removed so the box sizes itself snugly to whatever TFT.build_hud_stage_
-- nodes actually returns (up to 7 pips + checkpoint markers fits comfortably
-- with real vanilla Balatro's own layout system doing the sizing, no manual
-- floor needed). Background swapped from a flat opaque G.C.BLACK to
-- G.C.DYN_UI.BOSS_DARK -- the same semi-transparent tone vanilla's own
-- "Round score" HUD box uses (functions/UI_definitions.lua's
-- `contents.dollars_chips`, confirmed via the real installed source) and
-- this project's own build_hud_life_row already reuses elsewhere -- rather
-- than a flat black.
--
-- Still rebuilt in place on round change via the same add_child/remove-then-
-- rebuild primitive as before (this part didn't need to change).
function TFT.attach_stage_roadmap_display()
	if TFT.stage_roadmap_box or not TFT.system_cards then return end
	TFT.stage_roadmap_box = UIBox{
		definition = { n = G.UIT.ROOT, config = { align = 'cm' }, nodes = {
			{ n = G.UIT.C, config = { align = 'cm', r = 0.1, colour = G.C.DYN_UI.BOSS_DARK, emboss = 0.05, padding = 0.1 }, nodes = {
				{ n = G.UIT.C, config = { align = 'cm', id = 'tft_stage_roadmap_col' }, nodes = TFT.build_hud_stage_nodes() or {} },
			} },
		} },
		config = { align = 'cm' },
		T = { x = 0, y = 0 },
	}

	-- Same defensive per-frame dedup guard as TFT.system_cards's own :draw
	-- (see TFT.ensure_system_card_area's comment for the full story) -- not
	-- independently confirmed double-drawn, but cheap insurance against the
	-- same class of issue on a similarly-shaped standalone UI object.
	local orig_draw = TFT.stage_roadmap_box.draw
	local last_drawn_frame = -1
	TFT.stage_roadmap_box.draw = function(self)
		local frame = G.FRAMES and G.FRAMES.MOVE or 0
		if frame == last_drawn_frame then return end
		last_drawn_frame = frame
		return orig_draw(self)
	end

	TFT.position_stage_roadmap_display()
end

function TFT.refresh_stage_roadmap_display()
	if not TFT.is_run_active() or not TFT.system_cards then return end
	if not TFT.stage_roadmap_box then
		pcall(TFT.attach_stage_roadmap_display)
		return
	end
	local node = TFT.stage_roadmap_box:get_UIE_by_ID('tft_stage_roadmap_col')
	if not node then return end
	local ok, defs = pcall(TFT.build_hud_stage_nodes)
	if not ok or not defs then return end

	if node.children and #node.children > 0 then
		remove_all(node.children)
		node.children = {}
	end
	for _, def in ipairs(defs) do
		TFT.stage_roadmap_box:add_child(def, node)
	end
end

function TFT.position_system_card_area()
	if not (TFT.system_cards and G.consumeables) then return end
	TFT.system_cards.T.x = G.consumeables.T.x
	TFT.system_cards.T.y = G.consumeables.T.y + G.consumeables.T.h + 0.15
	TFT.system_cards:hard_set_VT()
end

-- Absolute position only -- see this file's own header comment on
-- TFT.attach_stage_roadmap_display for why this box takes no parent at all.
-- The y-gap below the card area was tuned empirically against a live
-- screenshot in the previous (CardArea-child) version and carries over
-- unchanged here -- same visual clearance below the card art either way.
-- Centered horizontally under the card area's own width using the box's OWN
-- T.w (populated by UIBox:init at construction time) -- needed now that the
-- box no longer forces itself to the card area's full width and instead
-- sizes snugly to its pip content, so a plain left-edge-aligned x would hug
-- the left side instead of sitting centered under the card.
function TFT.position_stage_roadmap_display()
	if not (TFT.stage_roadmap_box and TFT.system_cards) then return end
	TFT.stage_roadmap_box.T.x = TFT.system_cards.T.x + (TFT.system_cards.T.w - TFT.stage_roadmap_box.T.w) / 2
	TFT.stage_roadmap_box.T.y = TFT.system_cards.T.y + TFT.system_cards.T.h + 1.2
	TFT.stage_roadmap_box:hard_set_VT()
end

-- Re-applied every time vanilla recomputes screen layout (window resize,
-- entering/leaving a run) -- same splice pattern this project already uses
-- everywhere (hud.lua/standings.lua/shop_xp_buy.lua's own G.UIDEF wraps),
-- just against a plain global function instead of a UIDEF builder.
local _tft_orig_set_screen_positions = set_screen_positions
function set_screen_positions()
	_tft_orig_set_screen_positions()
	TFT.position_system_card_area()
	TFT.position_stage_roadmap_display()
end

-- CardArea:draw() is only ever explicitly called by name for the areas
-- vanilla itself knows about (G.jokers, G.consumeables, etc., in
-- Game:draw()) -- a new area needs its own explicit draw call somewhere, the
-- same real gotcha this project's own claudecontrol-guide.md already
-- documents for CardArea in general (it does NOT generically draw
-- self.children the way Card:draw() does, but that's a different, unrelated
-- issue -- this is about the AREA's own :draw() never being invoked at all
-- unless something calls it). The roadmap box is now a fully independent
-- object (not a child of this area, per this file's own header comment
-- above) so it gets its own separate, unconditional draw call here too --
-- not gated on TFT.system_cards existing, since there's no structural
-- dependency between the two anymore, only a one-time position lookup.
--
-- CAUGHT live (explicit user feedback: "the joker for some reason has a
-- double-joker effect on it"): the visible duplicate wasn't the Negative
-- edition's own shadow render after all (confirmed by isolating: a plain
-- Eternal, non-Negative copy of this exact same center, placed directly in
-- G.jokers, rendered as a single clean card) -- it was TFT.system_cards:draw()
-- itself genuinely firing TWICE per real frame. Measured precisely against
-- love.timer.getFPS() (matched exactly for the top-level Game:draw hook AND
-- for a real vanilla area, G.jokers:draw(), both a clean 1:1 ratio -- only
-- TFT.system_cards:draw() itself came back at ~2x). The real origin of that
-- second call was never root-caused; the actual fix (a per-frame dedup
-- guard wrapping the INSTANCE's own :draw method directly, so every caller
-- funnels through it) lives in TFT.ensure_system_card_area, above -- a first
-- attempt gating only THIS call site didn't fix the visible duplicate at
-- all, proving the real second caller bypasses this call site entirely.
-- This is therefore back to a single plain call, same as any other area.
local _tft_orig_game_draw = Game.draw
function Game:draw()
	_tft_orig_game_draw(self)
	if TFT.system_cards and TFT.system_cards.config.card_limit ~= 1 then
		-- Pinned back down every frame -- see TFT.ensure_system_card_area's
		-- own comment above on the real deferred-edition-side-effect cause.
		TFT.system_cards.config.card_limit = 1
	end
	if G.STATE ~= G.STATES.SPLASH then
		if TFT.system_cards then TFT.system_cards:draw() end
		if TFT.stage_roadmap_box then TFT.stage_roadmap_box:draw() end
	end
end

-- The one call site every current/future system-card creator should go
-- through instead of ever touching G.jokers directly. Applies Eternal on
-- creation (requires the center's own eternal_compat = true) -- pure
-- defense-in-depth at this point, not the real immunity mechanism (that's
-- this card simply not living in G.jokers at all, see this file's own
-- header comment), but a real vanilla sticker that still means something to
-- anything that checks `card.ability.eternal` directly.
--
-- Negative edition was DROPPED, 2026-09-01 (explicit user feedback on a live
-- screenshot: "the joker for some reason has a double-joker effect on it? I
-- do not like this at all"). Negative editions render with a real vanilla
-- shadow/parallax duplicate-card effect -- fine for an actual player-owned
-- Negative Joker, but wrong for a card meant to look like a single, unified
-- "system" element. Since the real immunity comes from the CardArea move
-- (confirmed via the real installed card.lua: Ankh/Wheel of Fortune/
-- Invisible Joker/the sell button all key off `self.area == G.jokers`
-- specifically, not an edition/sticker), Negative was never load-bearing --
-- dropping it costs nothing functionally. This also removes the real
-- deferred card_limit side effect Negative's own application was causing
-- (see TFT.ensure_system_card_area's own comment on that) -- the per-frame
-- card_limit=1 pin in Game:draw below is kept anyway, as cheap insurance,
-- but nothing should trigger the drift it guards against anymore.
function TFT.add_system_card(center_key)
	local area = TFT.ensure_system_card_area()
	if not area then return nil end
	for _, c in ipairs(area.cards) do
		if c.config and c.config.center and c.config.center.key == center_key then
			return c -- already present
		end
	end
	local card = create_card('Joker', area, nil, nil, nil, nil, center_key)
	card:set_eternal(true) -- requires the center's own eternal_compat = true
	card:add_to_deck()
	area:emplace(card)

	return card
end

-- REVERTED, 2026-09-01 (explicit user correction): the crash fix above was
-- first attempted as `card.states.collide.can = false` on the system card
-- itself -- this DID stop the crash, but also silently killed the hover
-- tooltip along with it (confirmed by the user directly: "hovering over it
-- did not actually show the information... it only showed it before you
-- made that change"). `states.collide.can` and `states.hover.can` are
-- nominally separate flags (card.lua sets both true independently at
-- init), but in practice disabling collide clearly also disables whatever
-- hit-testing hover itself depends on for this card -- wrong assumption,
-- corrected here rather than left in.
--
-- Fixed properly instead by patching the actual crashing function directly:
-- vanilla's real `CardArea:remove_from_highlighted(card, force)`
-- (confirmed via this instance's own real lovely/dump/cardarea.lua)
-- unconditionally calls `card:highlight(false)` after a loop that never
-- guarantees `card` is non-nil -- a genuine latent vanilla bug, not
-- something specific to our card. A nil-card call was always a pointless
-- no-op anyway (there's nothing to un-highlight), so guarding it is safe
-- for every area, not just this one -- collide.can stays at its normal
-- default (true), so hover/tooltip works exactly like any other Joker
-- again, and the crash is fixed at its actual source instead of worked
-- around by disabling collision entirely.
local _tft_orig_remove_from_highlighted = CardArea.remove_from_highlighted
function CardArea:remove_from_highlighted(card, force)
	if not card then return end
	return _tft_orig_remove_from_highlighted(self, card, force)
end

-- The actual scoring-dispatch splice described in this file's own header
-- comment above. Wrapped as the outermost layer (BalatroTFT loads after
-- Steamodded/other mods per this project's normal mod order), so the system
-- cards are present for the full real call chain, not just vanilla's own
-- innermost implementation.
local _tft_orig_evaluate_play = G.FUNCS.evaluate_play
G.FUNCS.evaluate_play = function(e)
	local spliced = {}
	if TFT.system_cards and TFT.system_cards.cards and G.jokers then
		for _, c in ipairs(TFT.system_cards.cards) do
			table.insert(G.jokers.cards, c)
			table.insert(spliced, c)
		end
	end

	local ok, err = pcall(_tft_orig_evaluate_play, e)

	for _, c in ipairs(spliced) do
		for i = #G.jokers.cards, 1, -1 do
			if G.jokers.cards[i] == c then
				table.remove(G.jokers.cards, i)
				break
			end
		end
	end

	if not ok then error(err, 0) end
end
