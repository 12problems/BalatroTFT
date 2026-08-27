-- Elimination / placement / match-end. Closes the gap flagged throughout this
-- session (objects/actions/life_total_change.lua's own header note,
-- objects/round_flow/pvp.lua's "alive = everyone in the lobby" comment,
-- objects/actions/round_result.lua's Second Wind/All or Nothing notes) --
-- next-session-plan.md priority #1.
--
-- ASSUMPTIONS (flagged, per that plan doc's own open questions #2/#3, going
-- with its documented defaults since this is an unmanaged/autonomous pass):
--  * Match-end condition: LAST PLAYER STANDING (not "everyone finishes the
--    sequence regardless of elimination") -- matches the TFT-style framing
--    architecture.md's own notes lean toward.
--  * Eliminated-player UX: a real "You were eliminated -- Placement #N"
--    screen, reusing ui/picker.lua's existing overlay helper -- this
--    project's own proven, already-live-tested overlay mechanism (Carousel,
--    Augment Checkpoint), simpler and more visually consistent with every
--    other TFT-specific screen this session built than reverse-engineering
--    vanilla's real create_UIBox_game_over from scratch would be -- with a
--    single button back to the main menu. No spectator/solo-continuation
--    mode this pass: a real "watch the rest of the match" view is
--    materially bigger scope than this pass's budget, flagged rather than
--    half-built.
--  * Placement is computed as "how many players (including you) were still
--    alive the instant you died" -- TFT's own convention (last to die = 1st
--    place) -- via a lobby-wide alive count that only accounts for
--    eliminations actually BROADCAST AND RECEIVED by this client so far; a
--    real network delay could theoretically show a placement number briefly
--    off by one if two players die in the same instant, but this converges
--    correctly as broadcasts land and isn't worth a full ack/consensus
--    scheme for this pass.

-- Tracks other players' known-eliminated state -- objects/actions/
-- life_total_change.lua sets this alongside TFT._opponent_life_totals on
-- every received life-total broadcast (every elimination is necessarily
-- preceded by a life-total change, so no separate action was added).
TFT._eliminated_players = TFT._eliminated_players or {}

-- Alive count from THIS client's own point of view right now: everyone in
-- the lobby, minus this client itself if state.eliminated, minus anyone
-- TFT._eliminated_players says is out. Called BEFORE marking yourself
-- eliminated in round_result.lua (so you still count as alive for your own
-- placement number), and from life_total_change.lua's on_receive after
-- someone ELSE'S elimination broadcast lands (to check for a last-player-
-- standing win).
function TFT.count_alive_players()
	local lobby = MPAPI.get_current_lobby and MPAPI.get_current_lobby()
	if not lobby then return 1 end
	local state = TFT.get_state()
	local my_id = lobby.player_id
	local count = 0
	for player_id, _ in pairs(lobby._players or {}) do
		local eliminated
		if player_id == my_id then
			eliminated = state and state.eliminated
		else
			eliminated = TFT._eliminated_players[player_id]
		end
		if not eliminated then count = count + 1 end
	end
	return count
end

function TFT.show_elimination_screen(placement)
	TFT.show_picker_overlay({
		title = 'Eliminated',
		subtitle = 'Placement #' .. tostring(placement),
		subtitle_colour = G.C.RED,
		no_esc = true,
		footer_rows = {
			{ label = { 'Return to Menu' }, button = 'go_to_menu', colour = G.C.RED },
		},
	})
end

function TFT.show_victory_screen()
	TFT.show_picker_overlay({
		title = 'Victory!',
		subtitle = 'Last one standing',
		subtitle_colour = G.C.GOLD,
		no_esc = true,
		footer_rows = {
			{ label = { 'Return to Menu' }, button = 'go_to_menu', colour = G.C.GOLD },
		},
	})
end
