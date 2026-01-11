-- Multiplayer core.lua
MP = SMODS.current_mod

-----------------------
-- Basic tables
-----------------------
MP.BANNED_MODS = {
	["Incantation"] = true,
	["Brainstorm"] = true,
	["DVPreview"] = true,
	["Aura"] = true,
	["NotJustYet"] = true,
	["Showman"] = true,
	["TagPreview"] = true,
	["FantomsPreview"] = true,
}

MP.LOBBY = {
	connected = false,
	temp_code = "",
	temp_seed = "",
	code = nil,
	type = "",
	config = {}, -- set below
	deck = {
		back = "Red Deck",
		sleeve = "sleeve_casl_none",
		stake = 1,
		challenge = "",
	},
	username = "Guest",
	blind_col = 1,
	host = {},
	guest = {},
	is_host = false,
	ready_to_start = false,
}

MP.GAME = {}
MP.UI = {}
MP.ACTIONS = {} -- fill later
MP.INTEGRATIONS = {}
MP.PREVIEW = {}
MP.EXPERIMENTAL = {
	use_new_networking = true,
	show_sandbox_collection = false,
	alt_stakes = false,
}

G.C.MULTIPLAYER = HEX("AC3232")
MP.SMODS_VERSION = "1.0.0~BETA-1221a"

-----------------------
-- INSANE_INT helper
-----------------------
MP.INSANE_INT = {}
function MP.INSANE_INT.empty()
	return 9007199254740991
end

-----------------------
-- Safe ACTIONS stubs
-----------------------
-- This prevents early crashes from lobby/UI referencing them
local stub = function() end
local actions_list = {
	"lobby_options", "start_game", "ready_lobby", "unready_lobby",
	"leave_lobby", "update_player_usernames", "connect", "stop_game"
}
for _, a in ipairs(actions_list) do
	MP.ACTIONS[a] = stub
end

-----------------------
-- Lobby config
-----------------------
function MP.reset_lobby_config(persist_ruleset_and_gamemode)
	MP.LOBBY.config = {
		gold_on_life_loss = true,
		no_gold_on_round_loss = false,
		death_on_round_loss = true,
		different_seeds = false,
		the_order = true,
		starting_lives = 4,
		pvp_start_round = 2,
		timer_base_seconds = 150,
		timer_increment_seconds = 60,
		pvp_countdown_seconds = 3,
		showdown_starting_antes = 3,
		ruleset = persist_ruleset_and_gamemode and MP.LOBBY.config.ruleset or "ruleset_mp_blitz",
		gamemode = persist_ruleset_and_gamemode and MP.LOBBY.config.gamemode or "gamemode_mp_attrition",
		weekly = nil,
		custom_seed = "random",
		different_decks = false,
		back = "Red Deck",
		sleeve = "sleeve_casl_none",
		stake = 1,
		challenge = "",
		cocktail = "",
		multiplayer_jokers = true,
		timer = true,
		timer_forgiveness = 0,
		forced_config = false,
		preview_disabled = false,
		legacy_smallworld = false,
	}
end
MP.reset_lobby_config()

-----------------------
-- Game states
-----------------------
function MP.reset_game_states()
	MP.GAME = {
		ready_blind = false,
		ready_blind_text = localize("b_ready"),
		processed_round_done = false,
		lives = 0,
		loaded_ante = 0,
		loading_blinds = false,
		comeback_bonus_given = true,
		comeback_bonus = 0,
		end_pvp = false,
		enemy = {
			score = MP.INSANE_INT.empty(),
			score_text = "0",
			hands = 4,
			location = localize("loc_selecting"),
			skips = 0,
			lives = MP.LOBBY.config.starting_lives,
			sells = 0,
			sells_per_ante = {},
			spent_in_shop = {},
			highest_score = MP.INSANE_INT.empty(),
		},
		location = "loc_selecting",
		timer = MP.LOBBY.config.timer_base_seconds,
		timer_started = false,
		pvp_countdown = 0,
	}
end
MP.reset_game_states()

-----------------------
-- Generic loader
-----------------------
function MP.load_mp_file(file)
	local chunk, err = SMODS.load_file(file, "Multiplayer")
	if chunk then
		local ok, func = pcall(chunk)
		if ok then return func end
		sendWarnMessage("Failed to process file: " .. func, "MULTIPLAYER")
	else
		sendWarnMessage("Failed to find or compile file: " .. tostring(err), "MULTIPLAYER")
	end
	return nil
end

function MP.load_mp_dir(directory, recursive)
	recursive = recursive or false
	local function has_prefix(name) return name:match("^_") ~= nil end

	local dir_path = MP.path .. "/" .. directory
	local items = NFS.getDirectoryItemsInfo(dir_path)
	table.sort(items, function(a,b)
		if has_prefix(a.name) ~= has_prefix(b.name) then return has_prefix(a.name) end
		return (a.type == "directory") ~= (b.type == "directory") and a.type ~= "directory" or false
	end)

	for _, item in ipairs(items) do
		local path = directory .. "/" .. item.name
		sendDebugMessage("Loading item: " .. path, "MULTIPLAYER")
		if item.type ~= "directory" then
			MP.load_mp_file(path)
		elseif recursive then
			MP.load_mp_dir(path, recursive)
		end
	end
end

-----------------------
-- Load utilities and networking
-----------------------
MP.LOBBY.username = MP.UTILS.get_username()
MP.LOBBY.blind_col = MP.UTILS.get_blind_col()
MP.LOBBY.config.weekly = MP.UTILS.get_weekly()

-- Load networking actions FIRST
local networking_dir = MP.EXPERIMENTAL.use_new_networking and "networking" or "networking-old"
MP.load_mp_file(networking_dir .. "/action_handlers.lua") -- this populates MP.ACTIONS
local SOCKET = MP.load_mp_file(networking_dir .. "/socket.lua")
MP.NETWORKING_THREAD = love.thread.newThread(SOCKET)
MP.NETWORKING_THREAD:start(SMODS.Mods["Multiplayer"].config.server_url, SMODS.Mods["Multiplayer"].config.server_port)

-----------------------
-- Optional: remove stubs if real actions loaded
-----------------------
-- (No code needed; `action_handlers.lua` replaces the stubs automatically)
