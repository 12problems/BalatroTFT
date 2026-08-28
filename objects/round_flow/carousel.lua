-- The real Carousel picker -- replaces the earlier flat +$5 stub. Each offer
-- pairs a "unit" (a Joker, power_tier drawn from the stage's scaling range --
-- domain/carousel_pool.lua) with a consumable (any Tarot/Spectral except Black
-- Hole/Soul, no Planets at all). Single-player fallback: a free guaranteed pick
-- from a generated pool, no draft race (architecture.md's "Single-player
-- fallback" section) -- 4 pair options offered, no reroll (matching the
-- reference screenshots, which showed Carousel with no reroll button, unlike
-- Augment Checkpoint).
--
-- ASSUMPTION (flagged): number of pair options offered (4) isn't specified
-- anywhere in the docs or reference screenshots (which showed a long
-- multiplayer draft-pool list, not applicable to a solo guaranteed pick) --
-- picked as a reasonable middle ground.
TFT.CAROUSEL_OPTION_COUNT = 4

-- Dispatcher (next-session-plan-4.md item 2): real multiplayer matches get an
-- actual shared-pool turn-based draft (objects/actions/carousel_draft.lua) --
-- everything below this function is the ORIGINAL single-player-only flow
-- (independent guaranteed picks, no draft, no contention), kept unchanged and
-- still used for real solo play and as a safety fallback if a multiplayer
-- state is somehow missing its lobby.
function TFT.open_carousel(round_def)
	local state = TFT.get_state()
	if state and state.is_multiplayer then
		local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
		if lobby then
			TFT.open_carousel_draft(round_def)
			return
		end
	end
	TFT.open_carousel_solo(round_def)
end

function TFT.open_carousel_solo(round_def)
	local state = TFT.get_state()
	if not state then return end

	-- table.unpack doesn't exist on LuaJIT (see stage_overview.lua's comment on
	-- the same real bug, caught live) -- indexed access instead.
	local tier_range = TFT.carousel_tier_range(round_def.stage)
	local min_tier, max_tier = tier_range[1], tier_range[2]
	-- Consumable-odds-by-level (next-session-plan-4.md item 6): same weighting
	-- domain/consumable_odds.lua applies to the real shop, via the same
	-- repeated-slot-array technique -- built once per Carousel offer rather
	-- than per-option, since the level (and therefore the weights) doesn't
	-- change mid-offer.
	local weighted_consumable_pool = TFT.apply_consumable_weights(TFT.CarouselConsumablePool, state.level)
	local options = {}
	for i = 1, TFT.CAROUSEL_OPTION_COUNT do
		local seed_suffix = 'tft_carousel_s' .. round_def.stage .. '_' .. i .. '_' .. tostring(G.GAME.seed)
		local joker_key = TFT.random_joker_in_tier_range(min_tier, max_tier, seed_suffix .. '_j')
		local consumable_key = pseudorandom_element(weighted_consumable_pool, pseudoseed(seed_suffix .. '_c'))
		if joker_key and consumable_key then
			table.insert(options, {
				joker_key = joker_key,
				joker_name = (G.P_CENTERS[joker_key] and G.P_CENTERS[joker_key].name) or joker_key,
				consumable_key = consumable_key,
				consumable_name = (G.P_CENTERS[consumable_key] and G.P_CENTERS[consumable_key].name) or consumable_key,
			})
		end
	end

	state.pending_carousel_offer = { round_def = round_def, options = options }
	TFT.render_carousel_overlay()
end

function TFT.render_carousel_overlay()
	local state = TFT.get_state()
	local offer = state and state.pending_carousel_offer
	if not offer then return end

	local rows = {}
	for i, opt in ipairs(offer.options) do
		rows[i] = {
			label = { opt.consumable_name .. '  +  ' .. opt.joker_name },
			button = 'tft_pick_carousel_' .. i,
			colour = G.C.GREY,
		}
	end

	TFT.show_picker_overlay({
		title = 'Carousel -- Stage ' .. offer.round_def.stage,
		subtitle = 'Your pick!',
		subtitle_colour = G.C.GOLD,
		rows = rows,
		no_esc = true,
	})
end

local function pick_carousel_slot(i)
	local state = TFT.get_state()
	local offer = state and state.pending_carousel_offer
	if not offer or not offer.options[i] then return end
	local opt = offer.options[i]

	local joker_card = create_card('Joker', G.jokers, nil, nil, nil, nil, opt.joker_key)
	joker_card:add_to_deck()
	G.jokers:emplace(joker_card)

	local consumable_type = (G.P_CENTERS[opt.consumable_key] and G.P_CENTERS[opt.consumable_key].set) or 'Tarot'
	local consumable_card = create_card(consumable_type, G.consumeables, nil, nil, nil, nil, opt.consumable_key)
	consumable_card:add_to_deck()
	G.consumeables:emplace(consumable_card)

	TFT.sendDebugMessage('Carousel picked: ' .. opt.joker_key .. ' + ' .. opt.consumable_key)

	state.pending_carousel_offer = nil
	TFT.close_picker_overlay()
	TFT.carousel_advance()
end

for i = 1, TFT.CAROUSEL_OPTION_COUNT do
	G.FUNCS['tft_pick_carousel_' .. i] = function() pick_carousel_slot(i) end
end

-- Carousel never becomes a real Blind, so it can't rely on ROUND_EVAL like a
-- normal scoring round -- this is its own advance path, called once a pick is
-- made (poll.lua no longer auto-resolves Carousel; it now just opens this
-- picker once per Carousel round-index).
function TFT.carousel_advance()
	local state = TFT.get_state()
	local sequence = TFT.ensure_sequence()
	if not state or not sequence then return end
	state.round_advanced_for_index = state.round_index

	TFT.grant_passive_xp() -- passive XP applies "regardless of round type" (architecture.md)
	TFT.grant_passive_money_for_level(state.level)
	pcall(TFT.trait_round_reset)

	if state.round_index < #sequence then
		state.round_index = state.round_index + 1
		TFT.announce_checkpoint_if_due()
		reset_blinds() -- re-apply ante/chip/boss-skip for the round we just moved to
	end
end
