-- Applies per-level passive benefits (domain/xp_curve.lua's TFT.LevelBenefits)
-- as a player crosses from old_level+1 up through new_level (a single XP grant
-- can cross more than one level at once against this curve, so this loops
-- rather than assuming a single-level step).
--
-- Money/hand-size/discard/slot bonuses are applied here directly against
-- G.GAME.starting_params / G.hand / G.jokers / G.consumeables where vanilla
-- itself exposes a simple additive field; the two "Voucher Choice" benefits
-- (levels 5 and 9) and the level-8 Deck Refinement pick are STUBBED this
-- session (logged only, no real pick UI) -- same "engine present, content pass
-- pending" scoping as the checkpoint stub in poll.lua.
function TFT.apply_level_up(from_level, to_level)
	for level = from_level, to_level do
		local benefit = TFT.LevelBenefits[level]
		if benefit then
			if benefit.hand_size and G.hand then
				G.hand.config.card_limit = (G.hand.config.card_limit or 0) + benefit.hand_size
			end
			if benefit.hands_played then
				G.GAME.round_resets.hands = (G.GAME.round_resets.hands or 0) + benefit.hands_played
			end
			if benefit.discards then
				G.GAME.round_resets.discards = (G.GAME.round_resets.discards or 0) + benefit.discards
			end
			if benefit.joker_slots and G.jokers then
				G.jokers.config.card_limit = (G.jokers.config.card_limit or 0) + benefit.joker_slots
			end
			if benefit.consumable_slots and G.consumeables then
				G.consumeables.config.card_limit = (G.consumeables.config.card_limit or 0) + benefit.consumable_slots
			end

			if benefit.voucher_choice_tier1_count or benefit.voucher_choice_level9 or benefit.deck_refinement_remove_up_to then
				TFT.sendDebugMessage('Level ' .. level .. ' voucher/deck-refinement benefit due (stub, no pick UI this session)')
			end
		end
	end

	if G.GAME then
		TFT.sendDebugMessage('TFT level up: ' .. from_level .. ' -> ' .. to_level)
	end
end

-- Per-round passive money (levels 5/8's stacking +$5 bonuses). Not wired to a
-- specific vanilla hook this session (no shop-end/round-end money tick exists
-- to attach to that we've verified) -- exposed as a plain function so poll.lua
-- or a later shop hook can call it; currently unused, flagged as an assumption
-- gap rather than silently wired to a guessed hook point.
function TFT.grant_passive_money_for_level(level)
	local amount = TFT.passive_money_per_round(level)
	if amount > 0 and G.GAME then
		ease_dollars(amount)
	end
end
