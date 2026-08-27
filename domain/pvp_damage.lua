-- PvP damage formula, ported directly from architecture.md's "PvP Damage
-- Formula (revised -- score-margin based, not Board Strength)" section.

TFT.STARTING_LIFE = 100

TFT.PvPBaseDamageByStage = { [2] = 5, [3] = 8, [4] = 12, [5] = 16, [6] = 20, [7] = 25 }

-- winner_score/loser_score: the two players' final round scores. Returns the
-- damage the loser takes, before any damage-mitigation augments are applied
-- (Thick Skin/Iron Wall/Fortress etc. -- those multiply this result down,
-- applied by the caller, not here, since they're per-player augment state).
function TFT.compute_pvp_damage(stage, winner_score, loser_score)
	local base = TFT.PvPBaseDamageByStage[stage] or TFT.PvPBaseDamageByStage[7]
	local ratio
	if loser_score <= 0 then
		ratio = 10
	else
		ratio = winner_score / loser_score
		if ratio < 1 then ratio = 1 end
		if ratio > 10 then ratio = 10 end
	end
	local bonus = base * (math.log(ratio, 10))
	return base + bonus
end
