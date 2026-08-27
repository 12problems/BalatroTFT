-- Run-scoped TFT state, stored on G.GAME (which vanilla already persists/saves
-- across the run) under its own namespaced key so we don't collide with vanilla
-- fields. Single-player only this session -- is_multiplayer is hardcoded false
-- here; multiplayer activation is objects/actions' job later, out of scope now.

function TFT.get_state()
	if not G.GAME then return nil end
	if not G.GAME.tft_state then
		G.GAME.tft_state = {
			initialized = false,
			is_multiplayer = false,
			sequence = nil, -- built lazily, cached (see TFT.ensure_sequence)
			round_index = 1, -- 1-based index into `sequence`, the round about to be/being played
			round_advanced_for_index = 0, -- last round_index we've already applied advance-side-effects for
			level = 1,
			xp = 0,
			-- last G.STATE seen by the poller, to detect transitions rather than
			-- re-triggering every single frame we happen to be in a given state.
			last_seen_state = nil,
		}
	end
	return G.GAME.tft_state
end

function TFT.ensure_sequence()
	local state = TFT.get_state()
	if not state then return nil end
	if not state.sequence then
		state.sequence = TFT.build_round_sequence(state.is_multiplayer)
	end
	return state.sequence
end

-- The round descriptor (see domain/stage_layout.lua's build_round_sequence doc
-- comment for the shape) for whichever round we're currently on.
function TFT.current_round_def()
	local state = TFT.get_state()
	local sequence = TFT.ensure_sequence()
	if not state or not sequence then return nil end
	return sequence[state.round_index]
end

function TFT.is_run_active()
	-- Mirrors the same "are we actually in a run" check other TFT-mode gating
	-- uses -- G.GAME exists during MENU too (leftover from the last run), so we
	-- specifically check we're in the RUN stage, not just that G.GAME is present.
	return G.STAGE == G.STAGES.RUN and G.GAME and G.GAME.tft_state ~= nil and G.GAME.tft_state.initialized
end
