-- Multiplayer core.lua
MP = SMODS.current_mod

-----------------------
-- Basic tables
-----------------------
MP.BANNED_MODS = {
    ["Incantation"]     = true,
    ["Brainstorm"]      = true,
    ["DVPreview"]       = true,
    ["Aura"]            = true,
    ["NotJustYet"]      = true,
    ["Showman"]         = true,
    ["TagPreview"]      = true,
    ["FantomsPreview"]  = true,   -- ← trailing comma is fine in Lua 5.1+
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
MP.ACTIONS = {}     -- will be filled later
MP.INTEGRATIONS = {}
MP.PREVIEW = {}
MP.EXPERIMENTAL = {
    use_new_networking          = true,
    show_sandbox_collection     = false,
    alt_stakes                  = false,
}

G.C.MULTIPLAYER = HEX("AC3232")
MP.SMODS_VERSION = "1.0.0~BETA-1221a"

-----------------------
-- INSANE_INT helper
-----------------------
do
    local INSANE_INT = 9007199254740991   -- 2⁵³-1 (safe JS integer)

    MP.INSANE_INT = setmetatable({}, {
        __index = function() return INSANE_INT end,
        __call = function() return INSANE_INT end
    })
end

-----------------------
-- Safe ACTIONS stubs (prevents very early crashes)
-----------------------
local function stub() end

local actions_list = {
    "lobby_options", "start_game", "ready_lobby", "unready_lobby",
    "leave_lobby", "update_player_usernames", "connect", "stop_game"
    -- you can add more here later
}

for _, action in ipairs(actions_list) do
    MP.ACTIONS[action] = stub
end

-----------------------
-- Lobby config
-----------------------
function MP.reset_lobby_config(persist_ruleset_and_gamemode)
    local prev = MP.LOBBY.config or {}

    MP.LOBBY.config = {
        gold_on_life_loss       = true,
        no_gold_on_round_loss   = false,
        death_on_round_loss     = true,
        different_seeds         = false,
        the_order               = true,
        starting_lives          = 4,
        pvp_start_round         = 2,
        timer_base_seconds      = 150,
        timer_increment_seconds = 60,
        pvp_countdown_seconds   = 3,
        showdown_starting_antes = 3,
        ruleset    = persist_ruleset_and_gamemode and prev.ruleset    or "ruleset_mp_blitz",
        gamemode   = persist_ruleset_and_gamemode and prev.gamemode   or "gamemode_mp_attrition",
        weekly     = nil,
        custom_seed = "random",
        different_decks = false,
        back       = "Red Deck",
        sleeve     = "sleeve_casl_none",
        stake      = 1,
        challenge  = "",
        cocktail   = "",
        multiplayer_jokers = true,
        timer      = true,
        timer_forgiveness = 0,
        forced_config  = false,
        preview_disabled = false,
        legacy_smallworld = false,
    }
end

MP.reset_lobby_config()   -- initial setup

-----------------------
-- Game states
-----------------------
function MP.reset_game_states()
    MP.GAME = {
        ready_blind          = false,
        ready_blind_text     = localize('b_ready'),
        processed_round_done = false,
        lives                = 0,
        loaded_ante          = 0,
        loading_blinds       = false,
        comeback_bonus_given = true,
        comeback_bonus       = 0,
        end_pvp              = false,

        enemy = {
            score         = MP.INSANE_INT(),
            score_text    = "0",
            hands         = 4,
            location      = localize("loc_selecting"),
            skips         = 0,
            lives         = MP.LOBBY.config.starting_lives or 4,
            sells         = 0,
            sells_per_ante = {},
            spent_in_shop = {},
            highest_score = MP.INSANE_INT(),
        },

        location      = "loc_selecting",
        timer         = MP.LOBBY.config.timer_base_seconds,
        timer_started = false,
        pvp_countdown = 0,
    }
end

MP.reset_game_states()

-----------------------
-- Generic loader helpers
-----------------------
function MP.load_mp_file(rel_path)
    local fullpath = MP.path .. "/" .. rel_path

    local chunk, err = SMODS.load_file(rel_path, "Multiplayer")
    if not chunk then
        sendWarnMessage("Failed to load/compile: " .. tostring(rel_path) .. "\n" .. tostring(err), "MULTIPLAYER")
        return nil
    end

    local ok, result = pcall(chunk)
    if not ok then
        sendWarnMessage("Runtime error in " .. rel_path .. ":\n" .. tostring(result), "MULTIPLAYER")
        return nil
    end

    return result   -- usually returns table / functions
end

function MP.load_mp_dir(directory, recursive)
    recursive = recursive or false

    local function has_prefix(name) return name:match("^_") ~= nil end

    local dir_path = MP.path .. "/" .. directory

    local success, items = pcall(NFS.getDirectoryItemsInfo, dir_path)
    if not success then
        sendWarnMessage("Cannot read directory: " .. dir_path, "MULTIPLAYER")
        return
    end

    table.sort(items, function(a, b)
        local ap = has_prefix(a.name)
        local bp = has_prefix(b.name)
        if ap ~= bp then return ap end   -- _files first

        if a.type ~= b.type then
            return a.type ~= "directory"   -- files before directories
        end

        return a.name < b.name
    end)

    for _, item in ipairs(items) do
        local path = directory .. "/" .. item.name
        sendDebugMessage("Loading: " .. path, "MULTIPLAYER")

        if item.type == "directory" then
            if recursive then
                MP.load_mp_dir(path, true)
            end
        else
            MP.load_mp_file(path)
        end
    end
end

-----------------------
-- Early initialization order
-----------------------
-- 1. Utilities should be loaded BEFORE we use them
MP.load_mp_file("utils.lua")           -- ← very important! many mods miss this

-- Now we can safely use MP.UTILS
MP.LOBBY.username   = MP.UTILS.get_username() or "Guest"
MP.LOBBY.blind_col  = MP.UTILS.get_blind_col() or 1
MP.LOBBY.config.weekly = MP.UTILS.get_weekly and MP.UTILS.get_weekly() or nil

-- 2. Networking (very important to load early)
local net_dir = MP.EXPERIMENTAL.use_new_networking and "networking" or "networking-old"

MP.load_mp_file(net_dir .. "/action_handlers.lua")   -- ← this should replace stubs

local socket_chunk = MP.load_mp_file(net_dir .. "/socket.lua")
if socket_chunk then
    MP.NETWORKING_THREAD = love.thread.newThread(socket_chunk)
    MP.NETWORKING_THREAD:start(
        SMODS.Mods["Multiplayer"].config.server_url or "multiplayer.example.com",
        SMODS.Mods["Multiplayer"].config.server_port or 14141
    )
else
    sendErrorMessage("Failed to load networking/socket.lua - multiplayer disabled", "MULTIPLAYER")
end

-- Optional: you can check which actions are still stubs after loading
-- for debugging purposes (remove later)
-- for k,v in pairs(MP.ACTIONS) do
--     if v == stub then
--         sendWarnMessage("Action still stubbed: " .. k, "MULTIPLAYER")
--     end
-- end