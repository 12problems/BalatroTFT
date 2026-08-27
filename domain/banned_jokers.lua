-- Jokers banned from this mode -- each lets a player bypass a mechanic this
-- mod's stakes depend on. See architecture.md's "Banned Jokers" section. Keys
-- verified against Balatro Source/localization/en-us.lua.
TFT.BannedJokers = {
	j_luchador = true, -- sell to disable the current Boss Blind's ability
	j_chicot = true, -- disables all Boss Blind abilities for the rest of the run
	j_mr_bones = true, -- prevents a loss once, then self-destructs
}

function TFT.is_joker_banned(card_key)
	return TFT.BannedJokers[card_key] == true
end
