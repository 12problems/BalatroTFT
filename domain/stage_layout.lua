-- The 7-stage/45-round layout. Source of truth: docs/design/architecture.md's
-- "Stage & Round Layout" section, corrected per the 2026-08-19 session decision:
-- stages 2-7 (all six, not just "after 2") are each 7 rounds -- 3 PvP, Carousel,
-- 2 PvP, PvE -- rather than the originally-pushed doc's 5-round version. Stage 1
-- is unchanged (3 PvE, no eliminations possible).
--
-- Total: 3 + 6*7 = 45 rounds (36 PvP, 6 Carousel, 9 PvE across the whole match).
--
-- chip_targets: a list of chip requirements for the "scoring" rounds in this
-- stage (PvE and PvP alike -- Carousel isn't a scoring round, it never consumes
-- an entry from this list). If the list has one entry, it applies uniformly to
-- every scoring round in the stage (this is an explicit assumption -- the design
-- docs only ever gave ONE number per stage for stages 2-7, because the original
-- 5-round layout only had one true PvE round per stage to apply it to; now that
-- single-player fallback turns every PvP slot into a real scored PvE round too,
-- something has to fill those chip targets, and reusing the stage's one number
-- uniformly was the simplest reading). If the list has multiple entries (stage 1
-- only, so far), they're consumed in round order, one per scoring round.
--
-- checkpoint / checkpoint_round_in_stage: which augment-pick checkpoint (1/2/3)
-- attaches to which round-in-stage. Per the locked schedule: checkpoints happen
-- before rounds 2-1, 3-2, 4-2. checkpoint must stay a plain number (not a table)
-- -- objects/round_flow code reads it directly as a tier-roll seed component.
TFT.StageLayout = {
	{
		stage = 1,
		rounds = { TFT.RoundType.PVE, TFT.RoundType.PVE, TFT.RoundType.PVE },
		chip_targets = { 100, 200, 300 },
	},
	{
		stage = 2,
		rounds = {
			TFT.RoundType.PVP, TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.CAROUSEL,
			TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.PVE,
		},
		chip_targets = { 1000 },
		checkpoint = 1,
		checkpoint_round_in_stage = 1,
	},
	{
		stage = 3,
		rounds = {
			TFT.RoundType.PVP, TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.CAROUSEL,
			TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.PVE,
		},
		chip_targets = { 3000 },
		checkpoint = 2,
		checkpoint_round_in_stage = 2,
	},
	{
		stage = 4,
		rounds = {
			TFT.RoundType.PVP, TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.CAROUSEL,
			TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.PVE,
		},
		chip_targets = { 8000 },
		checkpoint = 3,
		checkpoint_round_in_stage = 2,
	},
	{
		stage = 5,
		rounds = {
			TFT.RoundType.PVP, TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.CAROUSEL,
			TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.PVE,
		},
		chip_targets = { 20000 },
	},
	{
		stage = 6,
		rounds = {
			TFT.RoundType.PVP, TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.CAROUSEL,
			TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.PVE,
		},
		chip_targets = { 50000 },
	},
	{
		stage = 7,
		rounds = {
			TFT.RoundType.PVP, TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.CAROUSEL,
			TFT.RoundType.PVP, TFT.RoundType.PVP,
			TFT.RoundType.PVE,
		},
		chip_targets = { 120000 },
		-- Stage 7 draws exclusively from the 5 vanilla "finisher" bosses (The Amber
		-- Acorn, The Verdant Leaf, The Crimson Heart, The Cerulean Bell, The Violet
		-- Vessel) -- architecture.md's "Boss Blind assignment" section.
		finisher_bosses_only = true,
	},
}

-- Returns the chip target for the Nth scoring round (1-indexed, counting only
-- PvE/PvP rounds, not Carousel) within a given stage_def. See the uniform-vs-list
-- note above.
function TFT.get_chip_target(stage_def, scoring_round_index)
	local targets = stage_def.chip_targets
	if #targets == 1 then
		return targets[1]
	end
	return targets[scoring_round_index] or targets[#targets]
end

-- Flattens TFT.StageLayout into one ordered list of round descriptors for a full
-- match. is_multiplayer = false substitutes every PvP round with PvE (the
-- single-player fallback -- see architecture.md's "Single-player fallback"
-- section), and marks Carousel rounds as an instant free pick instead of a draft.
--
-- Each entry: { stage, round_in_stage, round_index (global, 1-45), round_type
-- (post-substitution), chip_target (nil for Carousel), is_checkpoint (bool),
-- checkpoint_tier_index (1/2/3, only when is_checkpoint), finisher_bosses_only }
function TFT.build_round_sequence(is_multiplayer)
	local sequence = {}
	local round_index = 0

	for _, stage_def in ipairs(TFT.StageLayout) do
		local scoring_round_index = 0
		for round_in_stage, base_type in ipairs(stage_def.rounds) do
			round_index = round_index + 1
			local effective_type = base_type
			local chip_target = nil

			if effective_type == TFT.RoundType.CAROUSEL then
				-- not a scoring round, consumes no chip_targets entry
			else
				if not is_multiplayer and effective_type == TFT.RoundType.PVP then
					effective_type = TFT.RoundType.PVE
				end
				scoring_round_index = scoring_round_index + 1
				chip_target = TFT.get_chip_target(stage_def, scoring_round_index)
			end

			local is_checkpoint = stage_def.checkpoint ~= nil
				and (stage_def.checkpoint_round_in_stage or 1) == round_in_stage

			table.insert(sequence, {
				stage = stage_def.stage,
				round_in_stage = round_in_stage,
				round_index = round_index,
				round_type = effective_type,
				base_round_type = base_type,
				chip_target = chip_target,
				is_checkpoint = is_checkpoint,
				checkpoint_tier_index = is_checkpoint and stage_def.checkpoint or nil,
				finisher_bosses_only = stage_def.finisher_bosses_only or false,
				is_carousel_solo_instant = (not is_multiplayer) and base_type == TFT.RoundType.CAROUSEL,
			})
		end
	end

	return sequence
end
