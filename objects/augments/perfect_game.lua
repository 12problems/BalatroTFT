-- Perfect Game (Combat & Stats, tier 3): "Beat a non-PvP blind by the EXACT
-- chip requirement to choose a permanent bonus." augments.md itself flags
-- the reward pool as undesigned ("Reward pool not designed yet — open
-- item") -- next-session-plan.md priority #3 asks for a real design pass
-- here, not just leaving it stubbed.
--
-- ASSUMPTION (flagged, not confirmed with you): a small, fixed 3-option pool
-- of permanent bonuses, reusing effects already established elsewhere in
-- this augment roster (definitions.lua's own +1 hand/+1 discard patterns,
-- and a flat cash grant) rather than inventing a new mechanic -- consistent
-- with how Monopoly/Suit Yourself already scope down an open-ended design
-- into something auto-resolved or reused rather than building bespoke new
-- systems per augment. Presented via the same ui/picker.lua overlay every
-- other pick-time screen in this mod uses (Augment Checkpoint, Carousel),
-- for visual consistency -- not a new UI pattern.
local PERFECT_GAME_REWARDS = {
	{
		key = 'hand', name = 'Precision Reflexes', desc = '+1 hand, permanently.',
		apply = function() G.GAME.round_resets.hands = (G.GAME.round_resets.hands or 0) + 1 end,
	},
	{
		key = 'discard', name = 'Exact Fit', desc = '+1 discard, permanently.',
		apply = function() G.GAME.round_resets.discards = (G.GAME.round_resets.discards or 0) + 1 end,
	},
	{
		key = 'cash', name = 'Flawless Bonus', desc = 'Gain $25 immediately.',
		apply = function() ease_dollars(25) end,
	},
}

-- Trigger check: called from poll.lua's TFT.round_flow_advance right after a
-- round is confirmed complete, while G.GAME.chips still holds that round's
-- final score (round_result.lua's own PvP broadcast reads it at this exact
-- same point, for the same reason -- see that file's header note on why
-- G.GAME.chips resets almost immediately after this point). Reads the
-- ROUND'S OWN chip_target (domain/stage_layout.lua) rather than
-- G.GAME.blind.chips, since the latter may already reflect whatever the
-- round AFTER this one rolls by the time this runs.
function TFT.check_perfect_game(round_def)
	if not TFT.has_augment('perfect_game') or not round_def or not round_def.chip_target then return end
	if round_def.round_type == TFT.RoundType.PVP or round_def.round_type == TFT.RoundType.CAROUSEL then return end
	if G.GAME.chips ~= round_def.chip_target then return end

	TFT.sendDebugMessage('Perfect Game triggered: scored exactly ' .. round_def.chip_target)
	TFT.open_perfect_game_picker()
end

function TFT.open_perfect_game_picker()
	local rows = {}
	for i, reward in ipairs(PERFECT_GAME_REWARDS) do
		rows[i] = {
			label = { reward.name, reward.desc },
			button = 'tft_pick_perfect_game_' .. i,
			colour = G.C.GOLD,
		}
	end
	TFT.show_picker_overlay({
		title = 'Perfect Game!',
		subtitle = 'Exact chip requirement -- choose a permanent bonus',
		subtitle_colour = G.C.GOLD,
		rows = rows,
		no_esc = true,
	})
end

local function pick_perfect_game_reward(i)
	local reward = PERFECT_GAME_REWARDS[i]
	if not reward then return end
	local ok, err = pcall(reward.apply)
	if not ok then TFT.sendWarnMessage('Perfect Game reward apply() failed for ' .. reward.key .. ': ' .. tostring(err)) end
	TFT.sendDebugMessage('Perfect Game reward picked: ' .. reward.key)
	TFT.close_picker_overlay()
end

G.FUNCS.tft_pick_perfect_game_1 = function() pick_perfect_game_reward(1) end
G.FUNCS.tft_pick_perfect_game_2 = function() pick_perfect_game_reward(2) end
G.FUNCS.tft_pick_perfect_game_3 = function() pick_perfect_game_reward(3) end
