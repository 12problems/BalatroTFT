-- Real deck-browsing multi-select picker -- next-session-plan.md priority
-- #3's Deck Surgeon ("remove any 5 cards of your choice") and Seal Artisan
-- ("choose up to 4 cards... assign each a Seal"), previously flagged NOT
-- WIRED since ui/picker.lua's existing helper is single-row-select only.
--
-- REWRITTEN per explicit user feedback on the first version (a plain rank/
-- suit text-grid): "players will want to see their enhancements and such
-- while selecting" -- real card art/enhancements/editions/seals only exist
-- on the REAL Card objects, not a text label, so this now builds on top of
-- vanilla's own real deck-viewing machinery instead of a from-scratch grid:
--   * functions/UI_definitions.lua's G.UIDEF.view_deck is the reference for
--     HOW to lay real cards out (one CardArea per suit, populated with
--     copy_card() copies -- copy_card (common_events.lua) explicitly copies
--     edition AND seal, confirmed by reading it, so a copy looks identical
--     to the original, enhancements and all).
--   * view_deck's own copies are DISPLAY ONLY (`type = 'title', highlight_
--     limit = 0`) -- cardarea.lua's CardArea:can_highlight only returns true
--     for type in {hand, joker, consumeable, shop}, so 'title'-type cards can
--     never become clickable/highlightable no matter what highlight_limit is
--     set to (confirmed by reading that function, not assumed). Building our
--     OWN CardAreas with `type = 'joker'` instead reuses vanilla's REAL
--     click-to-highlight system (Card:click -> CardArea:add_to_highlighted)
--     for free, rather than hand-rolling toggle buttons -- this is what
--     makes the actual card art clickable.
--
-- REMAINING GAP vs the first version: the "X/N selected" live counter is
-- gone -- it required rebuilding the whole overlay on every click (this
-- version's selection state lives entirely in vanilla's own CardArea.
-- highlighted lists, never routed back through a re-render), and a STALE
-- count would be worse than none. The subtitle is now static instructions
-- instead; Confirm just silently no-ops (logged, not shown) if the count is
-- wrong for an "exact" picker, same silent-reject behavior the first version
-- already had on a bad count.
TFT._deck_picker = nil

-- Cross-suit-area shared selection cap: vanilla's own highlight_limit is
-- PER CardArea (cardarea.lua's add_to_highlighted only ever counts
-- #self.highlighted), but Deck Surgeon/Seal Artisan need ONE shared cap
-- across all 4 suit areas together (5 total cards, not 5-per-suit). Hooked
-- globally on CardArea itself (there's no per-instance method override
-- mechanism in this engine cheaper than that), but gated to a complete no-op
-- for every CardArea in the game except the ones THIS picker created and
-- tagged (`area.tft_deck_picker = true`) -- zero behavior change for hand/
-- jokers/consumeables/shop, which is the vast majority of all
-- add_to_highlighted calls that will ever happen.
local _tft_orig_add_to_highlighted = CardArea.add_to_highlighted
function CardArea:add_to_highlighted(card, silent)
	if not self.tft_deck_picker then return _tft_orig_add_to_highlighted(self, card, silent) end

	local picker = TFT._deck_picker
	if picker then
		local total = 0
		for _, area in ipairs(picker.areas) do total = total + #area.highlighted end
		if total >= picker.opts.max_select then
			-- Evict the globally-oldest selection (first non-empty area's
			-- first entry) to make room -- lets a player just keep clicking
			-- new cards instead of having to manually deselect first.
			for _, area in ipairs(picker.areas) do
				if #area.highlighted > 0 then
					area:remove_from_highlighted(area.highlighted[1])
					break
				end
			end
		end
	end
	return _tft_orig_add_to_highlighted(self, card, silent)
end

local SUIT_ORDER = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }

-- opts: { title, subtitle, max_select, exact (bool -- must hit exactly
-- max_select to confirm, vs "up to"), on_confirm = function(list_of_cards) }
function TFT.open_deck_card_picker(opts)
	remove_nils(G.playing_cards)
	-- Same flag vanilla's own view_deck sets (functions/UI_definitions.lua) --
	-- CardArea:draw skips drawing G.deck/G.hand/G.play while this is true, so
	-- the real hand/deck don't visually clash behind this picker's card
	-- copies. Cleared on confirm below (there's no cancel path -- no_esc
	-- matches this being a direct, unskippable consequence of an augment
	-- pick already made, same as the previous grid version).
	G.VIEWING_DECK = true

	local by_suit = { Spades = {}, Hearts = {}, Clubs = {}, Diamonds = {} }
	for _, card in ipairs(G.playing_cards) do
		if by_suit[card.base.suit] then table.insert(by_suit[card.base.suit], card) end
	end

	local areas = {}
	local rows = {}
	for _, suit in ipairs(SUIT_ORDER) do
		local list = by_suit[suit]
		if #list > 0 then
			table.sort(list, function(a, b) return a.base.id < b.base.id end)

			-- Same construction args as G.UIDEF.view_deck's own real CardArea
			-- (functions/UI_definitions.lua) -- copied verbatim rather than
			-- guessed at, down to the initial x/y (the UIBox layout this gets
			-- embedded into repositions it regardless, same as vanilla's own
			-- deck_info screen does) -- except `type = 'joker'` and a real
			-- `highlight_limit` instead of 'title'/0, per this file's header
			-- note on why that's the one thing that actually needs to change.
			local area = CardArea(
				G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h,
				6.5 * G.CARD_W, 0.6 * G.CARD_H,
				{ card_limit = #list, type = 'joker', highlight_limit = opts.max_select, card_w = G.CARD_W * 0.7, draw_layers = { 'card' } }
			)
			area.tft_deck_picker = true

			for _, real_card in ipairs(list) do
				-- copy_card (functions/common_events.lua) explicitly copies
				-- edition AND seal -- confirmed by reading it, not assumed --
				-- so enhancements/editions/seals show on these copies exactly
				-- as they do on the real cards.
				local copy = copy_card(real_card, nil, 0.7)
				copy.tft_real_card = real_card -- maps the click target back to the real card for on_confirm
				copy.T.x = area.T.x
				copy.T.y = area.T.y
				copy:hard_set_T()
				area:emplace(copy)
			end

			table.insert(areas, area)
			table.insert(rows, { custom_node = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
				{ n = G.UIT.O, config = { object = area } },
			} } })
		end
	end

	TFT._deck_picker = { opts = opts, areas = areas }

	TFT.show_picker_overlay({
		title = opts.title,
		subtitle = 'Click cards to select/deselect, then Confirm',
		subtitle_colour = G.C.GOLD,
		rows = rows,
		footer_rows = { { label = { 'Confirm' }, button = 'tft_confirm_deck_card_picker', colour = G.C.BLUE } },
		no_esc = true,
	})
end

G.FUNCS.tft_confirm_deck_card_picker = function()
	local picker = TFT._deck_picker
	if not picker then return end

	local selected = {}
	for _, area in ipairs(picker.areas) do
		for _, copy in ipairs(area.highlighted) do
			table.insert(selected, copy.tft_real_card)
		end
	end

	if picker.opts.exact and #selected ~= picker.opts.max_select then
		TFT.sendDebugMessage('Deck picker: need exactly ' .. picker.opts.max_select .. ', have ' .. #selected .. ' -- not confirming')
		return -- stay open; picker.opts.exact requires the precise count
	end

	for _, area in ipairs(picker.areas) do
		pcall(function() area:remove() end)
	end
	G.VIEWING_DECK = nil
	TFT._deck_picker = nil
	TFT.close_picker_overlay()

	local ok, err = pcall(picker.opts.on_confirm, selected)
	if not ok then TFT.sendWarnMessage('Deck picker on_confirm failed: ' .. tostring(err)) end
end
