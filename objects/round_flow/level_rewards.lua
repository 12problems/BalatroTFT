-- Level-up rewards (next-session-plan-4.md item 1): Voucher Choice at levels 5
-- and 9, Deck Refinement at level 8. Replaces leveling.lua's old debug-log
-- stub with real pickers, built on the same overlay machinery (ui/picker.lua)
-- and deck-card picker (objects/augments/deck_picker.lua) already proven live
-- by Augment Checkpoints and Deck Surgeon/Seal Artisan respectively.
--
-- Sequencing: a single XP grant can cross more than one reward level at once
-- (leveling.lua's apply_level_up already loops for exactly this reason), and
-- a level-up can coincide with the SAME round transition as an Augment
-- Checkpoint (checkpoints are fixed to stages 2/4/6; level-ups are XP-paced
-- and can land anywhere) -- both use the same one-overlay-at-a-time
-- G.FUNCS.overlay_menu, so opening two in the same frame would stomp one.
-- Fixed with a small bounded queue (at most 3 reward levels ever exist, so a
-- generic priority-queue system would be over-engineering this): apply_level_
-- up collects which of 5/8/9 are due into state.pending_level_reward_queue and
-- shows them one at a time, each one's own confirm handler advancing to the
-- next; once the queue drains, TFT.open_deferred_checkpoint_if_any() (called
-- from objects/round_flow/poll.lua's announce_checkpoint_if_due, which defers
-- instead of opening immediately if this queue is non-empty) opens that
-- round's checkpoint for real, if one was waiting.

-- Confirmed via live source read of the real installed card.lua: Hieroglyph/
-- Petroglyph are the only voucher pair that changes Ante ("-1 Ante, -1 hand"
-- / "-1 Ante, -1 discard", G.localization.descriptions.Voucher). A REAL
-- technical conflict, not just thematic -- objects/round_flow/hooks.lua's
-- TFT.apply_current_round_blind_state force-pins G.GAME.round_resets.ante to
-- match our stage every round, so an Ante-modifying voucher would just fight
-- that pin. Excluded from every voucher pool this file builds.
TFT.VoucherExcluded = {
	v_hieroglyph = true,
	v_petroglyph = true,
}

-- Every currently-eligible Tier-1 (no prerequisite) voucher: not excluded,
-- not already owned. Built lazily from G.P_CENTERS each call (small pool,
-- ~16 Tier-1 vouchers total -- no caching needed, matches this file's own
-- "small enough to just recompute" scale).
function TFT.eligible_tier1_vouchers()
	local out = {}
	for key, center in pairs(G.P_CENTERS or {}) do
		if center.set == 'Voucher' and not center.requires and not TFT.VoucherExcluded[key]
			and not G.GAME.used_vouchers[key] then
			table.insert(out, key)
		end
	end
	return out
end

-- Every currently-eligible Tier-2 upgrade: has a `requires` (its Tier-1 pair),
-- that pair is owned, this Tier-2 itself isn't owned yet, not excluded.
-- Confirmed real vanilla eligibility shape via source read of
-- functions/common_events.lua's own get_current_pool Voucher branch --
-- `v.requires` is an array of prerequisite voucher keys (only ever 1 entry
-- for the real vanilla pairs, but walked in full to match vanilla's own
-- convention exactly rather than assuming length 1).
function TFT.eligible_tier2_upgrades()
	local out = {}
	for key, center in pairs(G.P_CENTERS or {}) do
		if center.set == 'Voucher' and center.requires and not TFT.VoucherExcluded[key]
			and not G.GAME.used_vouchers[key] then
			local all_owned = true
			for _, req in pairs(center.requires) do
				if not G.GAME.used_vouchers[req] then all_owned = false end
			end
			if all_owned then table.insert(out, key) end
		end
	end
	return out
end

-- Fisher-Yates via the game's own pseudorandom (reproducible/seeded, matching
-- checkpoint.lua's TFT.roll_augment_option_keys convention) rather than
-- love's raw math.random.
function TFT.pick_n_random_keys(pool, n, seed_suffix)
	local shuffled = {}
	for i, key in ipairs(pool) do shuffled[i] = key end
	for i = #shuffled, 2, -1 do
		local j = math.floor(pseudorandom(seed_suffix .. '_shuf' .. i) * i) + 1
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	local result = {}
	for i = 1, math.min(n, #shuffled) do result[i] = shuffled[i] end
	return result
end

-- Grants a voucher's real gameplay effect immediately, outside of any real
-- shop/redeem context. Deliberately NOT calling Card:redeem() (card.lua) --
-- that method sets `G.STATE = G.STATES.SMODS_REDEEM_VOUCHER` and drives a
-- real multi-second UI animation sequence meant for "you're standing in the
-- shop about to redeem this," which would collide with OUR OWN picker
-- overlay already showing (the exact class of mistake this same session's
-- Double Pack investigation hit twice: reaching around a real vanilla entry
-- point and calling a lower-level piece directly). Instead calls
-- Card:apply_to_run(center) directly -- confirmed via source read to be the
-- actual data-only effect-application function with NO G.STATE/animation
-- side effects, explicitly designed to be callable with no real Card
-- instance (`self and copy_card(self) or Card(0,0,...)` -- the nil-self
-- fallback exists in the real vanilla source for exactly this kind of call).
function TFT.grant_voucher(key)
	local center = G.P_CENTERS[key]
	if not center then return end
	G.GAME.used_vouchers[key] = true
	if not center.discovered then discover_card(center) end
	Card.apply_to_run(nil, center)
	TFT.sendDebugMessage('Voucher granted: ' .. key)
end

-- Advances the bounded level-reward queue (see header). Called once at
-- level-up time (leveling.lua) and again from the end of every reward
-- picker's own confirm handler below.
function TFT.show_next_level_reward()
	local state = TFT.get_state()
	if not state then return end
	local queue = state.pending_level_reward_queue
	if not queue or #queue == 0 then
		state.pending_level_reward_queue = nil
		TFT.open_deferred_checkpoint_if_any()
		return
	end
	local level = table.remove(queue, 1)
	if level == 5 then
		TFT.open_level5_voucher_choice()
	elseif level == 8 then
		TFT.open_level8_deck_refinement()
	elseif level == 9 then
		TFT.open_level9_reward()
	else
		TFT.show_next_level_reward() -- unknown level entry, skip forward rather than stall the queue
	end
end

------------------------------------------------------------------------------
-- Level 5: offer 3 random eligible Tier-1 vouchers, pick 1.
------------------------------------------------------------------------------
function TFT.open_level5_voucher_choice()
	local state = TFT.get_state()
	local pool = TFT.eligible_tier1_vouchers()
	if #pool == 0 then
		TFT.sendWarnMessage('Level 5 Voucher Choice: no eligible Tier-1 vouchers left -- skipping')
		TFT.show_next_level_reward()
		return
	end
	state.pending_level_reward = {
		kind = 'level5_voucher',
		option_keys = TFT.pick_n_random_keys(pool, 3, 'tft_lvl5_' .. tostring(G.GAME.seed) .. '_' .. tostring(state.xp)),
	}
	TFT.render_level5_voucher_overlay()
end

function TFT.render_level5_voucher_overlay()
	local state = TFT.get_state()
	local offer = state and state.pending_level_reward
	if not offer or offer.kind ~= 'level5_voucher' then return end

	local rows = {}
	for i, key in ipairs(offer.option_keys) do
		local center = G.P_CENTERS[key]
		rows[i] = { label = { center and center.name or key }, button = 'tft_pick_level5_voucher_' .. i, colour = G.C.GREY }
	end
	TFT.show_picker_overlay({
		title = 'Level 5 Reward',
		subtitle = 'Choose a Voucher',
		subtitle_colour = G.C.GOLD,
		rows = rows,
		no_esc = true,
	})
end

local function pick_level5_voucher(i)
	local state = TFT.get_state()
	local offer = state and state.pending_level_reward
	if not offer or offer.kind ~= 'level5_voucher' or not offer.option_keys[i] then return end
	TFT.grant_voucher(offer.option_keys[i])
	state.pending_level_reward = nil
	TFT.close_picker_overlay()
	TFT.show_next_level_reward()
end

for i = 1, 3 do
	G.FUNCS['tft_pick_level5_voucher_' .. i] = function() pick_level5_voucher(i) end
end

------------------------------------------------------------------------------
-- Level 8: Deck Refinement -- remove 0 to 5 cards, real card-art picker.
-- Reuses objects/augments/deck_picker.lua as-is: its `exact` flag already
-- supports "up to N" (exact=false) vs "exactly N" (exact=true, what Deck
-- Surgeon uses) -- no changes needed to that file at all.
------------------------------------------------------------------------------
function TFT.open_level8_deck_refinement()
	TFT.open_deck_card_picker({
		title = 'Level 8 Reward -- Deck Refinement',
		max_select = 5,
		exact = false,
		on_confirm = function(cards)
			for _, card in ipairs(cards) do
				if SMODS.shatters(card) then
					card:shatter()
				else
					card:start_dissolve()
				end
			end
			TFT.show_next_level_reward()
		end,
	})
end

------------------------------------------------------------------------------
-- Level 9: "Upgrade an existing Voucher" (pick 1 of all eligible Tier-2
-- upgrades) OR "3 Tier-1 Vouchers, Randomly" (grants all 3, no further pick).
-- The upgrade option is hidden entirely (not shown greyed-out) if there are
-- zero eligible upgrades, rather than offering an empty sub-list.
------------------------------------------------------------------------------
function TFT.open_level9_reward()
	local state = TFT.get_state()
	local upgrades = TFT.eligible_tier2_upgrades()
	state.pending_level_reward = { kind = 'level9_top', upgrade_keys = upgrades }
	TFT.render_level9_top_overlay()
end

function TFT.render_level9_top_overlay()
	local state = TFT.get_state()
	local offer = state and state.pending_level_reward
	if not offer or offer.kind ~= 'level9_top' then return end

	local rows = {}
	if #offer.upgrade_keys > 0 then
		rows[#rows + 1] = { label = { 'Upgrade an existing Voucher' }, button = 'tft_pick_level9_upgrade_path', colour = G.C.GREY }
	end
	rows[#rows + 1] = { label = { '3 Tier-1 Vouchers, Randomly' }, button = 'tft_pick_level9_random_path', colour = G.C.GREY }

	TFT.show_picker_overlay({
		title = 'Level 9 Reward',
		subtitle = 'Choose your reward',
		subtitle_colour = G.C.GOLD,
		rows = rows,
		no_esc = true,
	})
end

G.FUNCS.tft_pick_level9_upgrade_path = function()
	local state = TFT.get_state()
	local offer = state and state.pending_level_reward
	if not offer or offer.kind ~= 'level9_top' then return end
	local upgrades = offer.upgrade_keys
	state.pending_level_reward = { kind = 'level9_upgrade_pick', option_keys = upgrades }
	TFT.close_picker_overlay()
	TFT.render_level9_upgrade_pick_overlay()
end

function TFT.render_level9_upgrade_pick_overlay()
	local state = TFT.get_state()
	local offer = state and state.pending_level_reward
	if not offer or offer.kind ~= 'level9_upgrade_pick' then return end

	local rows = {}
	for i, key in ipairs(offer.option_keys) do
		local center = G.P_CENTERS[key]
		rows[i] = { label = { center and center.name or key }, button = 'tft_pick_level9_upgrade_' .. i, colour = G.C.GREY }
	end
	TFT.show_picker_overlay({
		title = 'Level 9 Reward',
		subtitle = 'Choose an Upgrade',
		subtitle_colour = G.C.GOLD,
		rows = rows,
		no_esc = true,
	})
end

local function pick_level9_upgrade(i)
	local state = TFT.get_state()
	local offer = state and state.pending_level_reward
	if not offer or offer.kind ~= 'level9_upgrade_pick' or not offer.option_keys[i] then return end
	TFT.grant_voucher(offer.option_keys[i])
	state.pending_level_reward = nil
	TFT.close_picker_overlay()
	TFT.show_next_level_reward()
end

for i = 1, 16 do -- generous upper bound on real Tier-2 voucher count (16 real pairs exist)
	G.FUNCS['tft_pick_level9_upgrade_' .. i] = function() pick_level9_upgrade(i) end
end

G.FUNCS.tft_pick_level9_random_path = function()
	local state = TFT.get_state()
	local offer = state and state.pending_level_reward
	if not offer or offer.kind ~= 'level9_top' then return end
	local pool = TFT.eligible_tier1_vouchers()
	local granted = TFT.pick_n_random_keys(pool, 3, 'tft_lvl9_' .. tostring(G.GAME.seed) .. '_' .. tostring(state.xp))
	for _, key in ipairs(granted) do
		TFT.grant_voucher(key)
	end
	state.pending_level_reward = nil
	TFT.close_picker_overlay()
	TFT.show_next_level_reward()
end
