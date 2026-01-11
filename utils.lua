-- Multiplayer/utils.lua

MP.UTILS = MP.UTILS or {}

function MP.UTILS.get_username()
    local cfg = SMODS.Mods["Multiplayer"].config
    return cfg.username or ("Guest" .. math.random(100,999))
end

function MP.UTILS.get_blind_col()
    return G.SETTINGS.blind_color or 1
end

function MP.UTILS.get_weekly()
    if G.CHALLENGES and G.CHALLENGES[1] and G.CHALLENGES[1].weekly then
        return G.CHALLENGES[1].id
    end
    return nil
end

-- You will need these too (most common ones used in multiplayer mod):
function MP.UTILS.wrapText(text, width)
    -- very simple word wrap, can be improved later
    local lines = {}
    local current = ""
    for word in text:gmatch("%S+") do
        if #current + #word + 1 > width then
            table.insert(lines, current)
            current = word
        else
            current = current == "" and word or current .. " " .. word
        end
    end
    if current ~= "" then table.insert(lines, current) end
    return lines
end

function MP.UTILS.get_phantom_joker(key)
    for _, card in ipairs(MP.shared.cards) do
        if card.config.center_key == key and card.edition and card.edition.mp_phantom then
            return card
        end
    end
    return nil
end

-- stub for now - implement properly later if needed
function MP.UTILS.joker_to_string(card)
    return card.config.center_key or "unknown_joker"
end

function MP.UTILS.card_to_string(card)
    return (card.base.suit or "?") .. "-" .. (card.base.id or "?")
end

-- Very basic string split (you use it in nemesis deck)
function MP.UTILS.string_split(str, sep)
    local fields = {}
    for field in string.gmatch(str, "([^" .. sep .. "]+)") do
        fields[#fields+1] = field
    end
    return fields
end
function sendTraceMessage(msg, tag)
    print(string.format("[TRACE] [%s] %s", tag or "GLOBAL", msg))
end

function sendDebugMessage(msg, tag)
    print(string.format("[DEBUG] [%s] %s", tag or "GLOBAL", msg))
end

function sendWarnMessage(msg, tag)
    print(string.format("[WARN]  [%s] %s", tag or "GLOBAL", msg))
end

function sendErrorMessage(msg, tag)
    print(string.format("[ERROR] [%s] %s", tag or "GLOBAL", msg))
    if MP and MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
        MP.UI.UTILS.overlay_message(msg)
    end
end

