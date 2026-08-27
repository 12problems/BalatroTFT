-- See round_result.lua's header note -- same scaffold-only scope, same
-- corrected real-API shape.
MPAPI.ActionType({
	key = 'tft_augment_pick',
	on_receive = function(action_type, from_player_id, params)
		TFT._collected_augment_picks = TFT._collected_augment_picks or {}
		TFT._collected_augment_picks[from_player_id] = params
	end,
})

function TFT.broadcast_augment_pick(augment_key, tier)
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return end
	lobby:action(MPAPI.ActionTypes['tft_augment_pick']):broadcast({ augment_key = augment_key, tier = tier })
end
