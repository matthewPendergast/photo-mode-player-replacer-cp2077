local PMPR = {
    version = '0.1.0',
    initialized = false,
    modules = {
        data = require('modules/data.lua'),
        debug = require('modules/debug.lua'),
        gameSession = require('external/GameSession.lua'),
        gameUI = require('external/GameUI.lua'),
        hooks = require('modules/hooks.lua'),
        interface = require('modules/interface.lua'),
        properties = require('properties.lua'),
    },
}

-- External Dependencies --
local AMM = nil
local NibblesToNPCs = nil

-- Game State --
local isOverlayOpen = false

-- Local Settings --
local vDefaultAppearances = {}
local jDefaultAppearances = {}

-- Accessors --

function PMPR.GetVEntity()
    return PMPR.modules.interface.vEntity
end

function PMPR.GetJEntity()
    return PMPR.modules.interface.jEntity
end

function PMPR.IsDefaultAppearance()
    return PMPR.modules.interface.isDefaultAppearance
end

function PMPR.ToggleDefaultAppearance(bool)
    PMPR.modules.interface.isDefaultAppearance = bool
end

---@param index integer (1-11)
function PMPR.GetEntityID(index)
    return PMPR.modules.data.GetEntityID(index)
end

-- Error Handling --

---@param message string
local function HandleError(message)
    PMPR.modules.interface.NotifyError(message)
    spdlog.info('[Photo Mode Player Replacer] Error: ' .. message)
end

-- Core Logic --

---@param entity userData
---@param appearance string (valid appearanceName)
function PMPR.ChangeAppearance(entity, appearance)
    if appearance ~= nil then
        entity:PrefetchAppearanceChange(appearance)
        entity:ScheduleAppearanceChange(appearance)
    end
end

---@param character string ('V' or 'Johnny')
---@param entity userData
function PMPR.SetDefaultAppearance(character, entity)
    local appearance
    if character == 'V' then
        appearance = vDefaultAppearances[PMPR.GetVEntity()]
    elseif character == 'Johnny' then
        appearance = jDefaultAppearances[PMPR.GetJEntity()]
    end
    PMPR.ToggleDefaultAppearance(false)
    PMPR.ChangeAppearance(entity, appearance)
end

function PMPR.LocatePlayerPuppet()
    local player = Game.GetPlayer()
    local tsq = TSQ_ALL()
    local success, parts = Game.GetTargetingSystem():GetTargetParts(player, tsq)
    if success then
        for _, part in ipairs(parts) do
            local entity = part:GetComponent(part):GetEntity()
            if entity then
                local ID = AMM:GetScanID(entity)
                if ID == PMPR.GetEntityID(1) then
                    return 'V', entity
                elseif ID == PMPR.GetEntityID(11) then
                    return 'Johnny', entity
                end
            end
        end
    end
end

-- Initialization --

local function CheckDependencies()
    AMM = GetMod('AppearanceMenuMod')

    if not AMM then
        HandleError('Missing Requirement - Appearance Menu Mod')
    end

    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        NibblesToNPCs = true
    else
        HandleError('Missing Requirement - Nibbles To NPCs')
    end

end

local function Initialize()
    -- Setup default appearance preferences
    for i, entry in ipairs(PMPR.modules.properties.defAppsV) do
        vDefaultAppearances[i] = entry.appearanceName
    end

    for i, entry in ipairs(PMPR.modules.properties.defAppsJ) do
        jDefaultAppearances[i] = entry.appearanceName
    end
end

local function ParseAppearanceLists()
    local censor = {
        oldTerms = {'Chubby', 'Freak', 'Junkie', 'Lowlife', 'Prostitute', 'Redneck'},
        newTerms = {'Curvy', 'Eccentric', 'Vagrant', 'Working Class', 'Sexworker', 'Rural'},
    }
    local filePath = "external/appearances.lua"
    local parsedTable = {}

    local requiredData = require(filePath)
    for index, group in ipairs(requiredData) do
        local groupedAppearances = {headers = {}, data = {}}

        if index == 1 then
            -- Handle the first table specially
            table.insert(groupedAppearances.headers, group.headers)
            groupedAppearances.data[group.headers] = {
                {parsed = group.parsed, unparsed = group.unparsed}
            }
        else
            for _, line in ipairs(group) do
                local header, appearance = line:match('^(.-)_(.+)$')
                if header and appearance then

                    -- Capitalize all parsed headers and appearances
                    header = string.gsub(header, '(%w)(%w*)', function(first, rest)
                        return string.upper(first) .. string.lower(rest)
                    end)

                    appearance = string.gsub(appearance, '(%w)(%w*)', function(first, rest)
                        return string.upper(first) .. string.lower(rest)
                    end)

                    -- Remove underscores from headers and appearances
                    header = string.gsub(header, '_', ' ')
                    appearance = string.gsub(appearance, '_+', ' ')

                    -- Change potentially offensive terms
                    for i, term in ipairs(censor.oldTerms) do
                        header = string.gsub(header, term, censor.newTerms[i])
                        appearance = string.gsub(appearance, term, censor.newTerms[i])
                    end

                    -- Add header to headers list if it's new
                    if not groupedAppearances.data[header] then
                        groupedAppearances.data[header] = {}
                        table.insert(groupedAppearances.headers, header)
                    end

                    -- Add appearance to the header's list
                    table.insert(groupedAppearances.data[header], {
                        parsed = appearance,
                        unparsed = line
                    })
                end
            end
        end
        table.insert(parsedTable, groupedAppearances)
    end
    PMPR.modules.hooks.SetParsedTable(parsedTable)
end


function SetupLocalization()
    local record = PMPR.modules.data.defaultLocNames
    local v = PMPR.modules.properties.locNames.V
    local johnny = PMPR.modules.properties.locNames.Johnny
    local nibbles = TweakDB:GetFlat(record)[3]

    -- If Nibbles Replacer exists, change naming convention to match this mod; else use default localized name
    if NibblesToNPCs then
        PMPR.locName.nibbles = PMPR.modules.properties.locNames.Nibbles
    end

    PMPR.modules.hooks.SetLocNames(v, johnny, nibbles)
    TweakDB:SetFlat(record, {v, johnny, nibbles})
end

-- CET Event Handling --

registerForEvent('onTweak', SetupLocalization)

registerForEvent('onInit', function()
    CheckDependencies()
    Initialize()
    ParseAppearanceLists()
    PMPR.modules.hooks.SetupObservers(PMPR)

    PMPR.modules.gameSession.OnStart(function()
        -- Initialize interface
        if not PMPR.modules.interface.initialized then
            PMPR.modules.interface.Initialize(PMPR.modules.data)
        end
        -- Reset V default paths and switch interface to replacer options
        PMPR.modules.interface.SetupDefaultV()
        PMPR.modules.interface.ToggleLoadingSaveFile(false)
    end)

    PMPR.modules.gameSession.OnEnd(function()
        -- Switch interface to status feed and reset values
        PMPR.modules.interface.ToggleLoadingSaveFile(true)
        PMPR.modules.interface.ResetInterface()
        PMPR.modules.interface.SetNotificationMessage('Re-initializing... \n')
    end)
end)

registerForEvent('onOverlayOpen', function()
    isOverlayOpen = true
end)

registerForEvent('onOverlayClose', function()
    isOverlayOpen = false
end)

registerForEvent('onDraw', function()
    if not isOverlayOpen then
        return
    elseif isOverlayOpen then
        PMPR.modules.interface.DrawUI()
    end
end)

return PMPR