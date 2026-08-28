-- The real Augment Checkpoint picker -- replaces poll.lua's earlier log-only
-- stub. Rolls a tier via the real conditional odds table (domain/
-- augment_tier_odds.lua), offers 3 augments from that tier, lets the player
-- pick one (applying its `apply()` effect if it has one) or reroll once for
-- free (matching the reference screenshots' "Reroll (free, 1x)" button).
--
-- CRITICAL FIX (live-crash-diagnosed, 2026-08-25): `state.pending_augment_offer`
-- lives on G.GAME.tft_state, which is part of the run's SAVE DATA -- Balatro
-- periodically pushes G.ARGS.save_run through a real LÖVE thread Channel
-- (G.SAVE_MANAGER.channel:push) to the save-writer thread. LÖVE Channels can
-- only carry booleans/numbers/strings/LÖVE types/tables of those -- NOT
-- functions. The first version of this file stored the full augment
-- DEFINITION table (from TFT.AugmentDefinitions, including its `apply`
-- function field) directly in that offer -- the very next autosave crashed the
-- whole game with "bad argument #1 to 'push' (... expected)" the moment a
-- checkpoint was reached. Fixed by storing only KEYS (plain strings) in
-- pending_augment_offer.options, and resolving the real definition (function
-- included) via TFT.get_augment(key) only transiently, at render/pick time --
-- never stored back onto G.GAME.
--
-- Per-slot handler functions (tft_pick_augment_1/2/3) rather than passing data
-- through the click event's ref_table/id -- simpler and avoids relying on
-- exactly how UIBox_button wires ref_table through to the click handler, which
-- wasn't confirmed against real source before writing this.

function TFT.open_augment_checkpoint(round_def)
	local state = TFT.get_state()
	if not state then return end

	local checkpoint_index = round_def.checkpoint_tier_index
	local tier = TFT.roll_augment_tier(
		checkpoint_index,
		state.augment_tier_1,
		state.augment_tier_2,
		'tft_aug_cp' .. checkpoint_index .. '_' .. tostring(G.GAME.seed)
	)
	if checkpoint_index == 1 then state.augment_tier_1 = tier
	elseif checkpoint_index == 2 then state.augment_tier_2 = tier end

	local pool = TFT.augments_by_tier(tier)
	if #pool == 0 then
		TFT.sendWarnMessage('No augments defined for tier ' .. tier .. ' -- skipping checkpoint')
		return
	end

	-- Real timer (domain/round_timers.lua, full timer functionality
	-- 2026-08-28), multiplayer only, matching the round/shop timers' own
	-- scope -- see TFT.round_flow_poll's enforcement (objects/round_flow/
	-- poll.lua) and TFT.checkpoint_timer_text's live display below.
	local deadline_at = (state.is_multiplayer and state.timer_enabled ~= false)
		and (love.timer.getTime() + TFT.AUGMENT_PICK_TIMER_SECONDS) or nil
	state.pending_augment_offer = {
		tier = tier,
		checkpoint_index = checkpoint_index,
		option_keys = TFT.roll_augment_option_keys(pool, 3, checkpoint_index),
		rerolled = false,
		deadline_at = deadline_at,
	}
	TFT.render_augment_checkpoint_overlay()
end

-- Returns plain augment KEYS (strings), never the definition tables
-- themselves -- see this file's header note on why that matters.
function TFT.roll_augment_option_keys(pool, n, seed_suffix)
	local shuffled = {}
	for i, aug in ipairs(pool) do shuffled[i] = aug.key end
	-- Fisher-Yates using the game's own pseudorandom, so offers are seeded/
	-- reproducible rather than using love's raw math.random.
	for i = #shuffled, 2, -1 do
		local j = math.floor(pseudorandom('tft_aug_shuffle' .. seed_suffix .. i) * i) + 1
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local result = {}
	for i = 1, math.min(n, #shuffled) do result[i] = shuffled[i] end
	return result
end

function TFT.render_augment_checkpoint_overlay()
	local state = TFT.get_state()
	local offer = state and state.pending_augment_offer
	if not offer then return end

	local rows = {}
	for i, key in ipairs(offer.option_keys) do
		local aug = TFT.get_augment(key)
		rows[i] = {
			label = { aug.name, aug.desc },
			button = 'tft_pick_augment_' .. i,
			colour = G.C.GREY,
		}
	end

	local footer = {}
	if not offer.rerolled then
		footer[1] = { label = { 'Reroll (free, 1x)' }, button = 'tft_reroll_augment', colour = G.C.BLUE }
	end

	TFT.show_picker_overlay({
		title = 'Augment Checkpoint',
		subtitle = TFT.AugmentTierName[offer.tier],
		subtitle_colour = TFT.AugmentTierColour[offer.tier],
		rows = rows,
		footer_rows = footer,
		no_esc = true, -- must pick, matches "not skippable" design intent
		timer_ref = offer.deadline_at and { t = TFT, v = 'checkpoint_timer_text' } or nil,
	})
end

local function pick_augment_slot(i)
	local state = TFT.get_state()
	local offer = state and state.pending_augment_offer
	if not offer or not offer.option_keys[i] then return end

	local key = offer.option_keys[i]
	local aug = TFT.get_augment(key)
	state.augments_picked = state.augments_picked or {}
	table.insert(state.augments_picked, key)
	if aug and aug.apply then
		local ok, err = pcall(aug.apply)
		if not ok then TFT.sendWarnMessage('Augment apply() failed for ' .. key .. ': ' .. tostring(err)) end
	end
	TFT.sendDebugMessage('Augment picked: ' .. key .. ' (tier ' .. offer.tier .. ')')

	state.pending_augment_offer = nil
	TFT.close_picker_overlay()
end

G.FUNCS.tft_pick_augment_1 = function() pick_augment_slot(1) end
G.FUNCS.tft_pick_augment_2 = function() pick_augment_slot(2) end
G.FUNCS.tft_pick_augment_3 = function() pick_augment_slot(3) end

G.FUNCS.tft_reroll_augment = function()
	local state = TFT.get_state()
	local offer = state and state.pending_augment_offer
	if not offer or offer.rerolled then return end
	offer.rerolled = true
	local pool = TFT.augments_by_tier(offer.tier)
	offer.option_keys = TFT.roll_augment_option_keys(pool, 3, offer.checkpoint_index .. '_reroll')
	TFT.close_picker_overlay()
	TFT.render_augment_checkpoint_overlay()
end

-- Tip Jar (+$1/scoring hand) is the one curated augment whose effect lives
-- here rather than at pick time -- checked from the Traits Engine's calculate()
-- (see objects/traits/engine.lua), since that's already a proven, working
-- joker_main scoring hook.
function TFT.has_augment(key)
	local state = TFT.get_state()
	if not state or not state.augments_picked then return false end
	for _, k in ipairs(state.augments_picked) do
		if k == key then return true end
	end
	return false
end
