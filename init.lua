local PMPR = {
    version = '1.0.0',
    modules = {
        data = require('modules/data.lua'),
        gameSession = require('external/GameSession.lua'),
        hooks = require('modules/hooks.lua'),
        interface = require('modules/interface.lua'),
        settings = require('user/settings.lua'),
        util = require('modules/utility.lua'),
    },
}

-- CET State --

local isOverlayOpen = false

-- Accessors --

function PMPR.GetVEntity()
    return PMPR.modules.interface.options.vIndex
end

function PMPR.GetJEntity()
    return PMPR.modules.interface.options.jIndex
end

function PMPR.IsDefaultAppearance()
    return PMPR.modules.interface.state.IsDefaultAppearance
end

function PMPR.ToggleDefaultAppearance(bool)
    PMPR.modules.interface.state.IsDefaultAppearance = bool
end

---@param index integer (1-2)
function PMPR.GetEntityID(index)
    return PMPR.modules.data.entityIDs[index]
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

local function ParseAppearanceLists()
    local censor = PMPR.modules.data.censor
    local filePath = 'external/appearances.lua'
    local parsedTable = {}
    local parsedList = {}

    local requiredData = dofile(filePath)
    local success, customAppearances = pcall(require, 'custom/customAppearances.lua')
    if success and type(customAppearances) == "table" then
        for i = 1, #customAppearances do
            requiredData[i + 4] = customAppearances[i]
        end
    end
    for index, group in ipairs(requiredData) do
        local groupedAppearances = {headers = {}, data = {}}
        local parsedGroup = {}
        local counter = 1

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

                -- Change potentially offensive terms for NPC replacers only
                if index <= 4 then
                    for i, term in ipairs(censor.oldTerms) do
                        header = string.gsub(header, term, censor.newTerms[i])
                        appearance = string.gsub(appearance, term, censor.newTerms[i])
                    end
                end

                -- Add header to headers list if it's new
                if not groupedAppearances.data[header] then
                    groupedAppearances.data[header] = {}
                    table.insert(groupedAppearances.headers, header)
                end

                -- Add the censored appearance to the parsedGroup
                local censoredLine = string.gsub(line, '(%w+)', function(word)
                    for i, term in ipairs(censor.oldTerms) do
                        word = string.gsub(word, term, censor.newTerms[i])
                    end
                    return word
                end)

                table.insert(parsedGroup, censoredLine)

                -- Convert custon NPV names back to valid appearanceNames
                if index > 4 and not success then
                    line = string.format('appearance_%02d', counter)
                    counter = counter + 1
                end

                -- Add appearance to the header's list
                table.insert(groupedAppearances.data[header], {
                    parsed = appearance,
                    unparsed = line
                })
            end
        end
        table.insert(parsedTable, groupedAppearances)
        table.insert(parsedList, parsedGroup)
    end
    PMPR.modules.hooks.SetParsedTable(parsedTable)
    PMPR.modules.interface.SetAppearanceLists(parsedList)
end

function SetupLocalization()
    local locNames = TweakDB:GetFlat(PMPR.modules.data.defaultLocNames)
    locNames[1] = Game.GetLocalizedText(locNames[1])
    locNames[2] = Game.GetLocalizedText(locNames[2])

    PMPR.modules.hooks.SetLocNames(locNames[1], locNames[2])
end

-- CET Event Handling --

registerForEvent('onTweak', SetupLocalization)

registerForEvent('onInit', function()
    CheckDependencies()
    ParseAppearanceLists()

    PMPR.modules.hooks.Initialize(PMPR)
    PMPR.modules.interface.Initialize(PMPR.modules.data)

    PMPR.modules.gameSession.OnStart(function()
        -- Initialize/reinitialize interface
        if not PMPR.modules.interface.ready then
            PMPR.modules.interface.PopulatePuppetTable(PMPR.modules.data)
        end
        -- Reset V default paths and switch interface to replacer options
        PMPR.modules.interface.SetupDefaultV()
        PMPR.modules.interface.state.isGameLoadingSaveFile = false
    end)

    PMPR.modules.gameSession.OnEnd(function()
        -- Switch interface to status feed and reset values
        PMPR.modules.interface.state.isGameLoadingSaveFile = true
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

registerForEvent('onUpdate', function ()
    -- Update appearance lists for changes to NPV names
    if PMPR.modules.interface.state.isAppearancesListUpdated == true then
        ParseAppearanceLists()
        PMPR.modules.interface.state.isAppearancesListUpdated = false
    end
end)

registerForEvent('onDraw', function()
    if isOverlayOpen then
        PMPR.modules.interface.DrawUI()
    end
end)

return PMPR