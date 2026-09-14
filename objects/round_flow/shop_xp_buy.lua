-- Buy XP button (explicit user request, 2026-09-01): a third button in the
-- shop's left-hand button column, alongside "Next Round" and "Reroll",
-- letting a player directly convert money into XP. Spliced into the real
-- vanilla shop UI tree (G.UIDEF.shop, functions/UI_definitions.lua) the same
-- way objects/round_flow/standings.lua splices G.UIDEF.run_info and
-- objects/round_flow/hud.lua splices create_UIBox_HUD -- rather than
-- reimplementing the whole shop screen, find the real "Next Round"/"Reroll"
-- column vanilla already builds and add a third row to it, shrinking all
-- three to fit the same vertical space.
--
-- ASSUMPTIONS (flagged, not confirmed): the exact cost/XP numbers weren't
-- specified -- cost scales like reroll per the user's own explicit choice
-- (a flat +1 per purchase within a shop visit, reset each visit, mirroring
-- calculate_reroll_cost exactly), but the BASE cost ($5) and the XP granted
-- per purchase (+5) are both reasonable-guess placeholders, easy to retune
-- once real playtesting gives a sense of how much XP is worth relative to
-- money at various points in a run.
TFT.XP_BUY_BASE_COST = 5
TFT.XP_BUY_AMOUNT = 5

-- Mirrors calculate_reroll_cost's own real shape (functions/common_events.lua)
-- exactly: a flat +1 per purchase, tracked per shop visit (reset in
-- poll.lua's shop-entry block), reset to a clean base each new visit.
function TFT.xp_buy_cost()
	local state = TFT.get_state()
	local count = (state and state.xp_buy_count_this_visit) or 0
	return TFT.XP_BUY_BASE_COST + count
end

G.FUNCS.tft_buy_xp = function(e)
	local state = TFT.get_state()
	if not state then return end
	local cost = TFT.xp_buy_cost()
	if G.GAME.dollars - G.GAME.bankrupt_at < cost then return end
	ease_dollars(-cost)
	state.xp_buy_count_this_visit = (state.xp_buy_count_this_visit or 0) + 1
	TFT.grant_xp(TFT.XP_BUY_AMOUNT)
end

-- Same real enable/disable pattern vanilla's own can_reroll uses (confirmed
-- by reading the real installed button_callbacks.lua) -- greys the button
-- out and strips its click handler once unaffordable, rather than letting a
-- click silently no-op.
G.FUNCS.can_buy_xp = function(e)
	local cost = TFT.xp_buy_cost()
	if (G.GAME.dollars - G.GAME.bankrupt_at) - cost < 0 then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
	else
		e.config.colour = G.C.BLUE
		e.config.button = 'tft_buy_xp'
	end
end

-- Live cost display, refreshed every frame the same way hud.lua's own
-- persistent-timer field is (TFT.update_hud_display_texts, poll.lua) --
-- bound into the button below via a plain {ref_table=TFT, ref_value=...}
-- DynaText, same pattern already used throughout this project.
TFT.xp_buy_cost_text = TFT.xp_buy_cost_text or '$' .. TFT.XP_BUY_BASE_COST

local _tft_orig_update_hud_for_xp_buy = TFT.update_hud_display_texts
function TFT.update_hud_display_texts()
	_tft_orig_update_hud_for_xp_buy()
	TFT.xp_buy_cost_text = '$' .. TFT.xp_buy_cost()
end

local function build_buy_xp_row()
	return { n = G.UIT.R, config = { align = 'cm', minw = 2.8, minh = 1.0, r = 0.15, colour = G.C.BLUE, button = 'tft_buy_xp', func = 'can_buy_xp', hover = true, shadow = true }, nodes = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.07 }, nodes = {
			{ n = G.UIT.R, config = { align = 'cm', maxw = 1.3 }, nodes = {
				{ n = G.UIT.T, config = { text = 'Buy XP', scale = 0.35, colour = G.C.WHITE, shadow = true } },
			} },
			{ n = G.UIT.R, config = { align = 'cm', maxw = 1.3, minw = 1 }, nodes = {
				{ n = G.UIT.T, config = { text = '+' .. TFT.XP_BUY_AMOUNT .. ' XP', scale = 0.3, colour = G.C.WHITE, shadow = true } },
				{ n = G.UIT.O, config = { object = DynaText({
					string = { { ref_table = TFT, ref_value = 'xp_buy_cost_text' } },
					colours = { G.C.WHITE }, shadow = true, font = G.LANGUAGES['en-us'].font, scale = 0.3 * 0.4,
				}) } },
			} },
		} },
	} }
end

local _tft_orig_uidef_shop = G.UIDEF.shop
function G.UIDEF.shop()
	local def = _tft_orig_uidef_shop()
	if not TFT.is_run_active() then return def end

	local ok, err = pcall(function()
		local next_round_node, column = TFT.find_hud_def_node(def, 'next_round_button')
		if not next_round_node or not column or not column.nodes then return end

		-- column.nodes[1] is next_round_button, [2] is the reroll row (it has
		-- no id of its own in vanilla, confirmed by reading the real installed
		-- UI_definitions.lua -- positional access is the only way to reach it).
		local reroll_node = column.nodes[2]

		-- Shrink all three to fit the same vertical space the original two
		-- occupied -- 1.5/1.6 down to 1.0 each, close enough to the old
		-- combined height (3.1) for three rows (3.0) without visibly growing
		-- the shop's left column.
		next_round_node.config.minh = 1.0
		if reroll_node and reroll_node.config then reroll_node.config.minh = 1.0 end

		table.insert(column.nodes, build_buy_xp_row())
	end)
	if not ok then TFT.sendWarnMessage('Buy XP button: failed to splice into shop UI: ' .. tostring(err)) end

	return def
end
