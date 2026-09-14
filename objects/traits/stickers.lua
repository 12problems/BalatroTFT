-- Per-trait visual Stickers (explicit user request, 2026-09-02): "make
-- Stickers for each trait, and hovering the joker should give the info on
-- what the sticker does, aka what the trait does." Two SEPARATE pieces:
--
-- 1) A real SMODS.Sticker per trait (10 total, `trait_<Key>` below) purely
--    for the hover TOOLTIP/badge -- confirmed via the real installed
--    Steamodded source (src/game_object.lua's SMODS.Sticker, src/utils.lua's
--    Card:add_sticker) that a Sticker's `card.ability[key]` flag feeds
--    card.lua's generic badge-collection loop (generate_UIBox_ability_table)
--    for free, giving each active trait its own hoverable mini-tooltip via
--    loc_txt/loc_vars with zero extra UI code. These are registered against
--    a fully transparent 1x1 "blank_sticker" atlas -- see part 2 for why.
--
-- 2) Our OWN hand-drawn on-card icon strip -- NOT a second SMODS.Sticker per
--    trait. Vanilla's own real Eternal/Perishable/Rental prove multiple
--    simultaneous SMODS.Sticker sprites CAN coexist correctly on one card
--    (confirmed live), so this isn't a hard SMODS/engine limitation -- but
--    per-trait Sticker sprites give no control over WHERE on the card each
--    one lands, so two active traits would still visually overlap in the
--    same corner. Instead: PRE-COMPOSITE every currently-active trait's
--    small icon onto ONE per-card love.graphics.Canvas (rebuilt only when
--    that card's active-tag set actually changes, not every frame), each at
--    its own slot offset, then draw that ONE canvas as a single Sprite each
--    frame the same way a real Sticker draws (`draw_shader('dissolve',
--    ...)`, full-card stretch) -- one real image with everything already
--    laid out, instead of juggling several independently-positioned ones.
--
-- REAL BUG HUNT, 2026-09-04/05 (kept for the record -- the eventual fix was
-- much simpler than any of this suggested): building the canvas above from
-- a shared multi-icon atlas via Quads intermittently produced fully
-- transparent icons for SOME trait columns but not others, in a way that
-- survived swapping Quads for ten separate single-image Atlases, disabling
-- mipmaps, flushing the sprite batch between draws, and reordering
-- registrations -- pointing at what looked like a genuine engine/driver
-- rendering limitation. It wasn't: `Canvas:newImageData():getPixel()`
-- readback on the SOURCE FILES themselves (not the runtime atlas) showed
-- several columns of `assets/2x/trait_icons_strip.png` were genuinely,
-- silently empty on disk -- a real bug in this session's own asset-
-- generation pipeline (the 2x file had been regenerated from a chain of
-- earlier intermediate scripts, and one of those steps dropped several
-- columns' content without erroring). Rebuilding the 2x file as a clean
-- 2x upscale of the known-good 1x file fixed it immediately, with no code
-- changes needed. Lesson: when a custom-asset render only "sometimes"
-- shows content, verify the ACTUAL FILE ON DISK (not just what the runtime
-- atlas object reports for dimensions/metadata) before suspecting the
-- engine.
--
-- Icon art: the user supplied a real icon sheet (assets/icons.png, a 4x9
-- grid of hexagonal trait-style icons with an unrelated "In-Game" reference
-- panel alongside it that isn't part of the reusable icon grid). 10 of those
-- icons were picked (by thematic fit, not the user's own explicit 1:1
-- mapping -- flagged, easy to swap) and composited into trait_icons_strip.png
-- (assets/1x: 200x20, assets/2x: 400x40, ten 20x20/40x40 cells laid out
-- edge-to-edge with no padding) -- see TRAIT_ORDER below for the exact
-- column order.
--
-- ASSUMPTION (flagged): the specific icon-to-trait pairings are my own
-- thematic judgment call (no exact suit/concept icons existed in the sheet
-- for a literal 1:1 mapping) -- e.g. Financiers -> a dollar-sign/vault icon,
-- Ascendants -> a trinity-knot icon. Worth a sanity check/swap if any
-- pairing reads wrong to you.
local TRAIT_ORDER = {
	'Financiers', 'Scholars', 'SpadesGuild', 'ClubsGuild', 'DiamondsGuild',
	'HeartsGuild', 'Multipliers', 'Scalers', 'Encore', 'Ascendants',
}

-- `disable_mipmap = true`: not load-bearing for the bug above (that was a
-- corrupt source file, not a mipmap issue -- confirmed by testing with
-- mipmaps disabled and seeing the identical failure before the real fix).
-- Kept anyway as a reasonable, cheap default for a small strip of flat
-- icons that's always drawn near its native size, never minified enough for
-- mipmapping to matter.
SMODS.Atlas {
	key = 'tft_trait_icons_strip',
	path = 'trait_icons_strip.png',
	px = 20,
	py = 20,
	disable_mipmap = true,
}

-- trait_key -> column index (0-based) into trait_icons_strip.png. MUST stay
-- in sync with that file's real column order (built via a one-off script,
-- not re-generatable from this file alone).
local TRAIT_COLUMN = {}
for i, trait_key in ipairs(TRAIT_ORDER) do
	TRAIT_COLUMN[trait_key] = i - 1
end

-- A real, registered, but fully transparent 1x1 atlas -- every tooltip-only
-- Sticker below points at this so its own (irrelevant to us, sometimes-
-- broken-anyway) generic on-card sprite draws nothing visible either way.
-- The REAL on-card visual is our own composited-canvas system, further down.
SMODS.Atlas {
	key = 'tft_blank_sticker',
	path = 'blank_sticker.png',
	px = 1,
	py = 1,
}

-- How many trait icons can render side by side on one card before they
-- start overlapping in the last slot -- purely a layout choice for our own
-- compositing below.
TFT.TRAIT_STICKER_MAX_SLOTS = 4
local CANVAS_SIZE = 96
local SLOT_W = CANVAS_SIZE / TFT.TRAIT_STICKER_MAX_SLOTS -- 24
local ICON_SIZE = 20
local ICON_MARGIN_X = (SLOT_W - ICON_SIZE) / 2
local ICON_Y = 4

-- trait_key -> the real (SMODS-prefixed) tooltip-only sticker key, populated
-- by the registration loop below.
TFT.TraitStickerKeys = {}

-- Builds the exact same "TFT-style breakpoint ladder" content already shown
-- on the Traits Engine's own tooltip (objects/traits/engine.lua's
-- generate_ui) as a STATIC text template with vanilla's own real `#1#`
-- value-substitution and `{V:n}` per-line colour-substitution markup
-- (confirmed via the real installed functions/misc_functions.lua: each
-- `{V:n}`-prefixed line's colour is read from `args.vars.colours[n]` at
-- DISPLAY time, not registration time) -- `loc_vars`-returned
-- `vars`/`vars.colours` are vanilla's own supported way to make a STATIC
-- template line's colour and numbers vary live, matching the identical
-- "one line per breakpoint, current one bolded" idea the Traits Engine's
-- own tooltip uses.
local function build_sticker_loc_txt(trait_key)
	local breakpoints = TFT.Traits[trait_key].breakpoints
	local effects = TFT.TraitBreakpointEffects[trait_key] or {}
	local text = { '#1# owned' }
	for i, threshold in ipairs(breakpoints) do
		table.insert(text, '{V:' .. (i + 1) .. '}' .. threshold .. ': ' .. (effects[i] or ''))
	end
	return {
		name = TFT.TraitDisplayNames[trait_key] or trait_key,
		text = text,
	}
end

for _, trait_key in ipairs(TRAIT_ORDER) do
	local sticker_def = SMODS.Sticker {
		key = 'trait_' .. trait_key,
		atlas = 'tft_blank_sticker',
		pos = { x = 0, y = 0 },
		-- Never auto-rolled by any generic vanilla/SMODS "does this shop/pack
		-- card get a sticker" mechanism -- same `should_apply = false`
		-- vanilla's own Eternal/Perishable/Rental registrations use
		-- (confirmed via the real installed game_object.lua), since those are
		-- ALL applied through their own bespoke paths, never the generic
		-- roll. Ours is applied/removed only by TFT.sync_card_trait_stickers,
		-- below, driven by real trait-tag membership.
		should_apply = false,
		needs_enable_flag = false,
		loc_txt = build_sticker_loc_txt(trait_key),
		loc_vars = function(self, info_queue, card)
			local counts = TFT.count_trait_tags()
			local count = counts[trait_key] or 0
			local tier = TFT.trait_tier_reached(trait_key, count)
			local colours = {}
			for i = 1, #TFT.Traits[trait_key].breakpoints do
				colours[i + 1] = (i == tier) and G.C.GOLD or G.C.UI.TEXT_INACTIVE
			end
			return { vars = { count, colours = colours } }
		end,
	}
	TFT.TraitStickerKeys[trait_key] = sticker_def.key
end

-- Rebuilds ONE card's own composited icon-strip canvas from scratch --
-- called only when that card's active-tag set has actually changed (see
-- TFT.sync_card_trait_stickers below), not every frame. Draws each active
-- trait's small source icon onto `card.tft_trait_canvas` at its slot's x
-- offset, leaving the rest of the 96x96 canvas transparent -- exactly the
-- layout the old per-slot atlas cells used to hard-code, just composited
-- fresh per real tag combination instead of pre-baked per slot index.
local function rebuild_card_trait_canvas(card, active_tags)
	card.tft_trait_canvas = card.tft_trait_canvas or love.graphics.newCanvas(CANVAS_SIZE, CANVAS_SIZE)

	local atlas = G.ASSET_ATLAS['tft_trait_icons_strip']
	local img_w, img_h = atlas.image:getDimensions()

	local prev_canvas = love.graphics.getCanvas()
	love.graphics.setCanvas(card.tft_trait_canvas)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.setColor(1, 1, 1, 1)
	for i, trait_key in ipairs(active_tags) do
		if i > TFT.TRAIT_STICKER_MAX_SLOTS then break end
		local col = TRAIT_COLUMN[trait_key]
		if col then
			-- Quad exactly matches this column's own 20x20 cell, no padding.
			local quad = love.graphics.newQuad(col * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE, img_w, img_h)
			local slot = i - 1
			love.graphics.draw(atlas.image, quad, slot * SLOT_W + ICON_MARGIN_X, ICON_Y)
		end
	end
	love.graphics.setCanvas(prev_canvas)
end

-- The on-card draw itself -- one plain `Sprite` (the same real engine class
-- vanilla's own eternal/perishable/rental stickers use, NOT a SMODS.Sticker
-- registration -- we don't need SMODS's per-key apply/badge machinery here,
-- just its proven full-card-stretch draw) wrapping the card's own canvas as
-- a 1-cell "atlas". Built once per card and reused -- only the canvas
-- CONTENT changes when tags change, the Sprite wrapper itself doesn't need
-- rebuilding.
-- Self-healing re-create check (not just `if card.tft_trait_sprite then
-- return end`): if some global "reset every live Sprite" pass ever runs
-- (e.g. a graphics/texture-scaling settings change -- Sprite:reset()
-- re-points `self.atlas` at `G.ASSET_ATLAS[self.atlas.name]`, which doesn't
-- exist for our own ad-hoc canvas-backed atlas table), our sprite would
-- silently lose its canvas reference. Comparing `.atlas.image` against the
-- card's own current canvas catches that and rebuilds instead of leaving a
-- broken sprite in place indefinitely.
local function ensure_card_trait_sprite(card)
	if card.tft_trait_sprite and card.tft_trait_sprite.atlas and card.tft_trait_sprite.atlas.image == card.tft_trait_canvas then return end
	card.tft_trait_sprite = Sprite(0, 0, G.CARD_W, G.CARD_H, {
		name = 'tft_trait_canvas_atlas',
		px = CANVAS_SIZE,
		py = CANVAS_SIZE,
		image = card.tft_trait_canvas,
	}, { x = 0, y = 0 })
end

-- Real per-frame hook, installed once below: draws `card.tft_trait_sprite`
-- (when present) on top of the card's own art, using the exact same
-- `draw_shader('dissolve', ...)` full-card-stretch call a real Sticker's
-- generic on-card draw uses -- confirmed to render correctly for a single
-- draw call per card (see this file's header note).
local function draw_card_trait_icons(card, layer)
	if layer ~= 'card' or not card.tft_trait_sprite or not card.children.center then return end
	card.tft_trait_sprite.role.draw_major = card
	card.tft_trait_sprite:draw_shader('dissolve', nil, nil, nil, card.children.center)
end

local card_draw_ref = Card.draw
function Card:draw(layer)
	card_draw_ref(self, layer)
	draw_card_trait_icons(self, layer)
end

-- Adds/removes NOTHING per-slot any more -- rebuilds the card's own
-- composited icon canvas (see above) only when its real trait-tag
-- membership (TFT.get_trait_tags, objects/traits/tagging.lua) has actually
-- changed since last sync, and keeps the tooltip-only stickers (part 1,
-- above) in sync with the SAME tag set so hovering the card still shows the
-- right per-trait breakpoint-ladder tooltips.
--
-- Tags are sorted alphabetically before slot assignment purely for stable,
-- deterministic output (so the same trait always lands in the same on-card
-- slot frame-to-frame, rather than jittering with pairs() iteration order)
-- -- it has no gameplay meaning beyond that. A duplicate tag (e.g. a
-- Joker's own static tag ALSO chosen by Grand Emblem) is de-duplicated
-- before assignment, since it should only occupy one slot.
--
-- The Traits Engine's own system card is explicitly excluded -- it's not a
-- real trait-tagged Joker itself, and living outside G.jokers entirely
-- (objects/round_flow/system_cards.lua) means TFT.get_trait_tags would
-- return {} for it anyway, but this guard makes the exclusion explicit
-- rather than incidental.
function TFT.sync_card_trait_stickers(card)
	if not card or not card.config or not card.config.center then return end
	if card.config.center.key == 'j_tft_traits_engine' then return end

	local seen = {}
	local active_tags = {}
	for _, t in ipairs(TFT.get_trait_tags(card)) do
		if not seen[t] then
			seen[t] = true
			active_tags[#active_tags + 1] = t
		end
	end
	table.sort(active_tags)

	-- Tooltip-only stickers: same add/remove-to-match pattern as before,
	-- just one flat key per trait instead of one per (trait, slot).
	local active_set = seen
	for trait_key, sticker_key in pairs(TFT.TraitStickerKeys) do
		local has_tag = active_set[trait_key] or false
		local has_sticker = card.ability[sticker_key] or false
		if has_tag and not has_sticker then
			card:add_sticker(sticker_key, true)
		elseif has_sticker and not has_tag then
			card:remove_sticker(sticker_key)
		end
	end

	-- On-card composited icon strip: only rebuild the canvas when the
	-- active-tag combination has actually changed (cheap string compare),
	-- not on every poll tick.
	local tags_key = table.concat(active_tags, ',')
	if card.tft_trait_tags_key ~= tags_key then
		card.tft_trait_tags_key = tags_key
		if #active_tags > 0 then
			rebuild_card_trait_canvas(card, active_tags)
			ensure_card_trait_sprite(card)
		elseif card.tft_trait_sprite then
			card.tft_trait_sprite = nil
		end
	end
end

-- Called every frame (objects/round_flow/poll.lua's TFT.round_flow_poll) --
-- cheap (a handful of owned Jokers, one string compare each; the canvas
-- rebuild itself only runs on an actual tag-set change), matching this
-- project's own established precedent for this exact trait subsystem
-- (engine.lua's own TFT.count_trait_tags comment: "simplified to a plain
-- recompute-on-call... since a player's Joker count is small"). Covers
-- every real tag-changing event (a new Joker bought/drawn, Grand Emblem/
-- Apprentice's Charm/Trait Heart picked) for free, without needing a
-- dedicated hook at each individual call site.
function TFT.sync_all_trait_stickers()
	if not G.jokers or not G.jokers.cards then return end
	for _, card in ipairs(G.jokers.cards) do
		TFT.sync_card_trait_stickers(card)
	end
end
