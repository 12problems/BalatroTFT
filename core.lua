--- STEAMODDED HEADER
--- MOD_NAME: Balatro TFT
--- MOD_ID: BalatroTFT
--- MOD_AUTHOR: [thatonecsguy]
--- MOD_DESCRIPTION: A crossover episode between Balatro and TFT (Teamfight Tactics).
--- PRIORITY: 0

TFT = SMODS.current_mod

-- DEV-ONLY: this environment's real Steam auth against MPAPI's backend fails
-- (confirmed live: "Steam auth failed: Server returned status 502", leaving
-- MPAPI.connection_state permanently "disconnected"/"Offline" -- the exact
-- state visible in every earlier reference screenshot's Multiplayer sidebar
-- too, so this was never actually connected in any prior session either).
-- MPAPI ships its own dev-auth bypass (BalatroMultiplayerAPI/dev/init.lua,
-- stripped from release builds) for exactly this -- authenticates against a
-- temp/ephemeral account via the local server instead of real Steam. Applied
-- here (our own mod) rather than editing MPAPI's shared source directly, and
-- as early as possible (top of core.lua, before any of our own directory
-- loads) since auth fires automatically during boot -- this needs to land
-- before that first attempt, not just before our other code runs.
-- Also respects BMP_IMPERSONATE_ID/BMP_IMPERSONATE_NAME (mirroring MPAPI's own
-- dev/init.lua logic exactly), so a second/third test instance can log in as a
-- distinct real player row instead of every instance colliding on the same
-- ephemeral "DevPlayer" temp identity -- needed for lobby join to make sense
-- across 2+ locally-tested instances.
if MPAPI and MPAPI.networking and MPAPI.networking.connection then
	local imp_id = os.getenv('BMP_IMPERSONATE_ID')
	local imp_name = os.getenv('BMP_IMPERSONATE_NAME')
	if imp_id or imp_name then
		local target = imp_id and { playerId = imp_id } or { steamName = imp_name }
		function MPAPI.networking.connection:_do_auth()
			self:_try_impersonate_auth(target)
		end
	else
		function MPAPI.networking.connection:_do_auth()
			self:_try_dev_auth()
		end
	end
end

function TFT.sendDebugMessage(msg)
	sendDebugMessage(msg, TFT.id)
end

function TFT.sendWarnMessage(msg)
	sendWarnMessage(msg, TFT.id)
end

function TFT.load_tft_file(file)
	local chunk, err = SMODS.load_file(file, TFT.id)
	if chunk then
		local ok, func = pcall(chunk)
		if ok then
			return func
		else
			TFT.sendWarnMessage('Failed to process file: ' .. func)
		end
	else
		TFT.sendWarnMessage('Failed to find or compile file: ' .. tostring(err))
	end
	return nil
end

function TFT.load_tft_dir(directory, recursive)
	recursive = recursive or false

	local dir_path = TFT.path .. '/' .. directory
	local items = NFS.getDirectoryItemsInfo(dir_path)

	for _, item in ipairs(items) do
		local path = directory .. '/' .. item.name
		TFT.sendDebugMessage('Loading item: ' .. path)
		if item.type ~= 'directory' then
			TFT.load_tft_file(path)
		elseif recursive then
			TFT.load_tft_dir(path, recursive)
		end
	end
end

-- Pure data/enum tables -- no MPAPI or SMODS calls, safe to load unconditionally
-- and first, since everything else below reads from these.
TFT.load_tft_dir('domain', true)

-- The single-player round/stage/leveling/shop engine. Deliberately loaded
-- unconditionally (not gated behind MPAPI.on_loaded below) -- per this session's
-- scope, single-player is the primary supported path and must work even if MPAPI
-- never finishes loading for some reason. Multiplayer-specific wiring (actual
-- action broadcast/receive) is scaffolded separately under objects/actions and
-- gated behind MPAPI.on_loaded, since it needs MPAPI's ActionType registry ready.
TFT.load_tft_dir('objects/round_flow', true)
TFT.load_tft_dir('objects/traits', true)
TFT.load_tft_dir('objects/jokers', true)
TFT.load_tft_dir('objects/augments', true)
TFT.load_tft_dir('ui', true)

-- Balatro has no single "you lost"/"round advanced" callback (confirmed against
-- BalatroMultiplayerSpeedrun's own source, see technical.md). We poll for those
-- transitions off the update loop, same workaround. Registered unconditionally so
-- solo play works without any MPAPI lobby.
if not TFT._update_hooked then
	TFT._update_hooked = true
	local _tft_update_ref = Game.update
	function Game:update(dt)
		_tft_update_ref(self, dt)
		pcall(TFT.round_flow_poll)
	end
end

MPAPI.on_loaded(function()
	MPAPI.register_mod({
		id = TFT.id,
		name = 'BalatroTFT',
		colour = G.C.SECONDARY_SET.Tarot,
		prevent_pause = true,

		main_menu_ui = {
			TFT.build_pre_lobby_ui,
			function(uibox)
				return 0.4, function(new_uibox) end
			end,
		},

		lobby_ui = {
			TFT.build_in_lobby_ui,
			function(uibox)
				return 0.4, function(new_uibox) end
			end,
		},
	})

	-- MPAPI-specific action broadcast/receive wiring. Scaffolded this session per
	-- explicit scope (see docs/design/README.md) -- not live-tested with a second
	-- instance yet.
	TFT.load_tft_dir('objects/actions', true)
end)

TFT.is_active = function()
	return MPAPI.is_active(TFT.id)
end
