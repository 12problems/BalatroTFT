-- Real multiplayer Carousel draft (next-session-plan-4.md item 2): a shared
-- 8-pair pool, players pick one at a time in ascending-life-total order
-- (lowest life first -- a real comeback mechanic, matching README's own
-- locked "turn-order snake draft by life total" decision), each pick
-- removing that pair from everyone's view of the pool. Single pick per
-- player per Carousel event -- confirmed not a multi-round snake.
--
-- Host-authoritative sequencing, the same pattern this project's round-timer
-- design (technical.md) and TFT.round_flow_advance already use: the host
-- alone decides turn order, broadcasts whose turn it is, and watches for a
-- turn timing out (10s pre-timer to look at the pool once broadcast, then
-- 10s per player's own turn, auto-picking a random remaining pair for
-- whoever doesn't act in time) -- avoids every client racing to independently
-- decide "did the current picker time out," the same class of desync this
-- project's other timer logic already sidesteps by having exactly one
-- authority act and broadcast the result.
--
-- Broadcast-then-locally-compute for the actual pool CONTENTS too, not just
-- the pick: the pool itself is generated once (by the host) and broadcast,
-- rather than trusting every client to independently derive the identical 8
-- pairs -- the DRAFT PROGRESS (who's picked what, whose turn it is) needs a
-- single shared source of truth regardless, so there's no benefit to
-- computing the pool independently only to immediately need a broadcast
-- anyway for everything downstream of it.
TFT.CAROUSEL_DRAFT_POOL_SIZE = 8
TFT.CAROUSEL_PRE_TIMER_SECONDS = 10
TFT.CAROUSEL_TURN_TIMER_SECONDS = 10

function TFT.open_carousel_draft(round_def)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby or not lobby.is_host then return end -- non-host clients wait for the real broadcast below

	local tier_range = TFT.carousel_tier_range(round_def.stage)
	local min_tier, max_tier = tier_range[1], tier_range[2]
	-- ASSUMPTION (flagged): consumable-odds-by-level (item 6) is scoped per
	-- PLAYER level elsewhere (the real shop, each player's own client); a
	-- single shared draft pool needs ONE level to weight against, so this
	-- uses the host's own level as a stand-in for "the lobby's level" rather
	-- than, say, an average -- simplest reasonable choice for a purely
	-- cosmetic weighting, not something the user asked to be decided a
	-- particular way.
	local state = TFT.get_state()
	local weighted_consumable_pool = TFT.apply_consumable_weights(TFT.CarouselConsumablePool, state and state.level or 1)

	local pool = {}
	for i = 1, TFT.CAROUSEL_DRAFT_POOL_SIZE do
		local seed_suffix = 'tft_carousel_draft_s' .. round_def.stage .. '_' .. i .. '_' .. tostring(G.GAME.seed)
		local joker_key = TFT.random_joker_in_tier_range_biased(min_tier, max_tier, round_def.stage, seed_suffix .. '_j')
		local consumable_key = pseudorandom_element(weighted_consumable_pool, pseudoseed(seed_suffix .. '_c'))
		pool[i] = { joker_key = joker_key, consumable_key = consumable_key }
	end

	lobby:action(MPAPI.ActionTypes['tft_carousel_offer']):broadcast({ pool = pool })
end

MPAPI.ActionType({
	key = 'tft_carousel_offer',
	on_receive = function(action_type, from_player_id, params)
		local state = TFT.get_state()
		if not state then return end
		state.carousel_draft = {
			pool = params.pool,
			turn_order = nil,
			current_turn_index = 0,
			current_player_id = nil,
			turn_started_at = nil,
		}
		TFT.render_carousel_draft_overlay()

		local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
		if lobby and lobby.is_host then
			G.E_MANAGER:add_event(Event({
				trigger = 'after',
				delay = TFT.CAROUSEL_PRE_TIMER_SECONDS,
				blocking = false,
				blockable = false,
				func = function()
					TFT.host_advance_carousel_turn(1)
					return true
				end,
			}))
		end
	end,
})

-- Host-only. turn_index == 1 also computes and broadcasts the turn order
-- (alive players, ascending by last-known life total) alongside the first
-- turn -- one broadcast covers both rather than a separate action, since
-- nothing downstream needs the order before the first turn starts anyway.
function TFT.host_advance_carousel_turn(turn_index)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby or not lobby.is_host then return end
	local state = TFT.get_state()
	local draft = state and state.carousel_draft
	if not draft then return end -- draft already finished/cleared

	local turn_order = draft.turn_order
	if not turn_order then
		local my_id = lobby.player_id
		local alive = {}
		for player_id, _ in pairs(lobby._players or {}) do
			local eliminated = (player_id == my_id) and state.eliminated or TFT._eliminated_players[player_id]
			if not eliminated then table.insert(alive, player_id) end
		end
		table.sort(alive, function(a, b)
			local life_a = (a == my_id) and (state.life_total or TFT.STARTING_LIFE) or ((TFT._opponent_life_totals and TFT._opponent_life_totals[a]) or TFT.STARTING_LIFE)
			local life_b = (b == my_id) and (state.life_total or TFT.STARTING_LIFE) or ((TFT._opponent_life_totals and TFT._opponent_life_totals[b]) or TFT.STARTING_LIFE)
			return life_a < life_b
		end)
		turn_order = alive
		draft.turn_order = turn_order
	end

	if turn_index > #turn_order then
		lobby:action(MPAPI.ActionTypes['tft_carousel_finish']):broadcast({})
		return
	end

	local player_id = turn_order[turn_index]
	local started_at = love.timer.getTime()
	lobby:action(MPAPI.ActionTypes['tft_carousel_turn']):broadcast({
		turn_index = turn_index,
		player_id = player_id,
		started_at = started_at,
		turn_order = (turn_index == 1) and turn_order or nil,
	})

	-- Timeout watchdog: fires slightly after the client-visible timer so a
	-- real last-instant pick isn't raced by this. Checks current_turn_index
	-- is UNCHANGED before acting -- if a real pick already advanced the
	-- draft, this is a no-op, not a double-advance.
	G.E_MANAGER:add_event(Event({
		trigger = 'after',
		delay = TFT.CAROUSEL_TURN_TIMER_SECONDS + 0.5,
		blocking = false,
		blockable = false,
		func = function()
			TFT.host_check_carousel_turn_timeout(turn_index, player_id)
			return true
		end,
	}))
end

function TFT.host_check_carousel_turn_timeout(turn_index, player_id)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby or not lobby.is_host then return end
	local state = TFT.get_state()
	local draft = state and state.carousel_draft
	if not draft or draft.current_turn_index ~= turn_index then return end -- already resolved for real

	local remaining = {}
	for i, slot in ipairs(draft.pool) do
		if not slot.taken_by then table.insert(remaining, i) end
	end
	if #remaining == 0 then
		lobby:action(MPAPI.ActionTypes['tft_carousel_finish']):broadcast({})
		return
	end
	local pool_index = pseudorandom_element(remaining, pseudoseed('tft_carousel_auto_pick' .. turn_index .. tostring(G.GAME.seed)))
	lobby:action(MPAPI.ActionTypes['tft_carousel_pick']):broadcast({ turn_index = turn_index, player_id = player_id, pool_index = pool_index, auto = true })
end

MPAPI.ActionType({
	key = 'tft_carousel_turn',
	on_receive = function(action_type, from_player_id, params)
		local state = TFT.get_state()
		local draft = state and state.carousel_draft
		if not draft then return end
		if params.turn_order then draft.turn_order = params.turn_order end
		draft.current_turn_index = params.turn_index
		draft.current_player_id = params.player_id
		draft.turn_started_at = params.started_at
		TFT.render_carousel_draft_overlay()
	end,
})

-- Granting a pick applies to THIS client's own board only when the pick
-- belongs to this client -- every client sees every carousel_pick broadcast
-- (so the pool display updates for everyone), but only the picker's own
-- client's G.jokers/G.consumeables actually change, same "broadcast to all,
-- apply your own consequence" pattern as round_result.lua.
function TFT.grant_carousel_pick(slot)
	local joker_card = create_card('Joker', G.jokers, nil, nil, nil, nil, slot.joker_key)
	joker_card:add_to_deck()
	G.jokers:emplace(joker_card)

	local consumable_type = (G.P_CENTERS[slot.consumable_key] and G.P_CENTERS[slot.consumable_key].set) or 'Tarot'
	local consumable_card = create_card(consumable_type, G.consumeables, nil, nil, nil, nil, slot.consumable_key)
	consumable_card:add_to_deck()
	G.consumeables:emplace(consumable_card)
end

MPAPI.ActionType({
	key = 'tft_carousel_pick',
	on_receive = function(action_type, from_player_id, params)
		local state = TFT.get_state()
		local draft = state and state.carousel_draft
		if not draft then return end
		if draft.current_turn_index ~= params.turn_index then return end -- stale/duplicate, ignore
		local slot = draft.pool[params.pool_index]
		if not slot or slot.taken_by then return end -- already resolved
		slot.taken_by = params.player_id

		local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
		local my_id = lobby and lobby.player_id
		if params.player_id == my_id then
			TFT.grant_carousel_pick(slot)
			TFT.sendDebugMessage('Carousel draft: picked ' .. slot.joker_key .. ' + ' .. slot.consumable_key
				.. (params.auto and ' (auto-picked, turn timed out)' or ''))
		end

		TFT.render_carousel_draft_overlay()

		if lobby and lobby.is_host then
			TFT.host_advance_carousel_turn(params.turn_index + 1)
		end
	end,
})

MPAPI.ActionType({
	key = 'tft_carousel_finish',
	on_receive = function()
		local state = TFT.get_state()
		if not state then return end
		state.carousel_draft = nil
		TFT.close_picker_overlay()
		-- Carousel Blind (objects/round_flow/carousel.lua): the 5s post-pick
		-- delay before the shop is ADDITIVE on top of this draft's own
		-- CAROUSEL_PRE_TIMER_SECONDS/CAROUSEL_TURN_TIMER_SECONDS above --
		-- this finish action already only fires once every player's turn is
		-- done (turn_index > #turn_order), so the delay starts right here.
		TFT.carousel_finish_after_delay()
	end,
})

function TFT.render_carousel_draft_overlay()
	local state = TFT.get_state()
	local draft = state and state.carousel_draft
	if not draft then return end
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	local my_id = lobby and lobby.player_id
	local is_my_turn = draft.current_player_id ~= nil and draft.current_player_id == my_id

	local rows = {}
	for i, slot in ipairs(draft.pool) do
		local joker_name = (G.P_CENTERS[slot.joker_key] and G.P_CENTERS[slot.joker_key].name) or slot.joker_key
		local consumable_name = (G.P_CENTERS[slot.consumable_key] and G.P_CENTERS[slot.consumable_key].name) or slot.consumable_key
		local base_label = consumable_name .. '  +  ' .. joker_name
		if slot.taken_by then
			local p = lobby and lobby._players and lobby._players[slot.taken_by]
			local taken_name = (p and p.displayName) or slot.taken_by
			rows[i] = { label = { base_label, '(taken by ' .. taken_name .. ')' }, colour = G.C.UI.BACKGROUND_INACTIVE }
		elseif is_my_turn then
			rows[i] = { label = { base_label }, button = 'tft_pick_carousel_draft_' .. i, colour = G.C.GREY }
		else
			rows[i] = { label = { base_label }, colour = G.C.GREY }
		end
	end

	local subtitle, subtitle_colour
	if not draft.current_player_id then
		subtitle, subtitle_colour = 'Draft starting soon...', G.C.WHITE
	elseif is_my_turn then
		subtitle, subtitle_colour = 'Your turn! Pick one.', G.C.GOLD
	else
		local p = lobby and lobby._players and lobby._players[draft.current_player_id]
		local name = (p and p.displayName) or draft.current_player_id
		subtitle, subtitle_colour = 'Waiting for ' .. name .. '...', G.C.WHITE
	end

	-- Live ticking countdown (next-session-plan-4.md item "no live-updating
	-- on-screen countdown", closed 2026-08-28) -- only shown once a turn has
	-- actually started (current_player_id set); the pre-timer window before
	-- turn 1 has no single "whose clock is it" countdown to show.
	TFT.show_picker_overlay({
		title = 'Carousel Draft',
		subtitle = subtitle,
		subtitle_colour = subtitle_colour,
		rows = rows,
		no_esc = true,
		timer_ref = draft.current_player_id and { t = TFT, v = 'carousel_timer_text' } or nil,
	})
end

for i = 1, TFT.CAROUSEL_DRAFT_POOL_SIZE do
	G.FUNCS['tft_pick_carousel_draft_' .. i] = function()
		local state = TFT.get_state()
		local draft = state and state.carousel_draft
		if not draft then return end
		local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
		local my_id = lobby and lobby.player_id
		if not my_id or draft.current_player_id ~= my_id then return end -- not your turn
		if draft.pool[i].taken_by then return end -- already taken
		lobby:action(MPAPI.ActionTypes['tft_carousel_pick']):broadcast({ turn_index = draft.current_turn_index, player_id = my_id, pool_index = i })
	end
end
