local PMPR = {
    version = '1.0.0',
    initialized = false,
    modules = {
        data = require('modules/data.lua'),
        debug = require('modules/debug.lua'),
        gameSession = require('external/GameSession.lua'),
        hooks = require('modules/hooks.lua'),
        interface = require('modules/interface.lua'),
        properties = require('properties.lua'),
        settings = require('user/settings.lua'),
        util = require('modules/utility.lua'),
    },
}

local isOverlayOpen = false

-- Accessors --

function PMPR.GetVEntity()
    return PMPR.modules.interface.GetVEntity()
end

function PMPR.GetJEntity()
    return PMPR.modules.interface.GetJEntity()
end

---@param character string ('V' or 'Johnny')
function PMPR.GetEntityByCharacter(character)
    if character == 'V' then
        return PMPR.GetVEntity()
    elseif character == 'Johnny' then
        return PMPR.GetJEntity()
    end
end

function PMPR.IsDefaultAppearance()
    return PMPR.modules.interface.IsDefaultAppearance()
end

function PMPR.ToggleDefaultAppearance(bool)
    PMPR.modules.interface.ToggleDefaultAppearance(bool)
end

---@param index integer (1-2)
function PMPR.GetEntityID(index)
    return PMPR.modules.data.GetEntityID(index)
end

-- Error Handling --

---@param message string
local function HandleError(message)
    PMPR.modules.interface.NotifyError(message)
    spdlog.info('[Photo Mode Player Replacer] Error: ' .. message)
end

-- Initialization --

local function CheckDependencies()
    if not ModArchiveExists('Photomode_NPCs_AMM.archive') then
        HandleError('Missing Requirement - Nibbles To NPCs')
    end
end

local function Initialize()
    -- Setup default appearance preferences
    for i, entry in ipairs(PMPR.modules.properties.defAppsV) do
        PMPR.modules.util.vDefaultAppearances[i] = entry.appearanceName
    end

    for i, entry in ipairs(PMPR.modules.properties.defAppsJ) do
        PMPR.modules.util.jDefaultAppearances[i] = entry.appearanceName
    end
end

local function ParseAppearanceLists()
    local censor = {
        oldTerms = {'Chubby', 'Freak', 'Junkie', 'Lowlife', 'Prostitute', 'Redneck'},
        newTerms = {'Curvy', 'Eccentric', 'Vagrant', 'Working Class', 'Sexworker', 'Rural'},
    }
    local filePath = "external/appearances.lua"
    local parsedTable = {}
    local parsedList = {}

    local requiredData = require(filePath)
    for index, group in ipairs(requiredData) do
        local groupedAppearances = {headers = {}, data = {}}
        local parsedGroup = {} -- Initialize a new table for this group's parsed names

        if index == 11 then
            -- Handle the last table specially
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

                    -- Add the censored appearance to the parsedGroup
                    local censoredLine = string.gsub(line, '(%w+)', function(word)
                        for i, term in ipairs(censor.oldTerms) do
                            word = string.gsub(word, term, censor.newTerms[i])
                        end
                        return word
                    end)
                    table.insert(parsedGroup, censoredLine)
                end
            end
        end
        table.insert(parsedTable, groupedAppearances)
        table.insert(parsedList, parsedGroup) -- Add the parsed group to the parsedList
    end
    PMPR.modules.hooks.SetParsedTable(parsedTable)
    PMPR.modules.interface.SetAppearanceLists(parsedList)
end


function SetupLocalization()
    local record = PMPR.modules.data.defaultLocNames
    local v = PMPR.modules.properties.locNames.V
    local johnny = PMPR.modules.properties.locNames.Johnny
    local nibbles = PMPR.modules.properties.locNames.Nibbles

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
    PMPR.modules.interface.Initialize(PMPR.modules.data)

    PMPR.modules.gameSession.OnStart(function()
        -- Initialize interface
        if not PMPR.modules.interface.ready then
            PMPR.modules.interface.PopulatePuppetTable(PMPR.modules.data)
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

return PMPRs