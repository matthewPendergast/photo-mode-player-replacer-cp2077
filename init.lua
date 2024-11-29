local PMPR = {
    version = '0.1.0',
    initialized = false,
    modules = {
        data = require('modules/data.lua'),
        debug = require('modules/debug.lua'),
        gameSession = require('external/GameSession.lua'),
        gameUI = require('external/GameUI.lua'),
        interface = require('modules/interface.lua'),
        properties = require('properties.lua'),
    },
}

-- External Dependencies --
local AMM = nil
local NibblesToNPCs = nil

-- Game State --
local isPhotoModeActive = false
local isOverlayOpen = false

-- Local Settings --
local vDefaultAppearances = {}
local jDefaultAppearances = {}
local parsedTable = {}
local appearanceTable = {}
local gameuiPMMC = nil

local menuController = {
    initialized = false,
    posePage = 2,
    characterAttribute = 38,
    visibleAttribute = 27,
    headerAttribute = 9000,
    appearanceAttribute = 9001,
    headerMenuItemLabel = 'REPLACER CHARACTER',
    appearanceMenuItemLabel = 'REPLACER APPEARANCE',
    isDefaultAppearance = true,
    vLocName = nil,
    johnnyLocName = nil,
    nibblesLocName = nil,
    currHeaderIndex = nil,
    currAppIndex = nil,
    currHeaderCount = nil,
    currAppCount = nil,
    currHeader = nil,
    currParsedApp = nil,
    currUnparsedApp = nil,
    parsedApps = {},
    unparsedApps = {},
}

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

local function HandleError(message)
    PMPR.modules.interface.NotifyError(message)
    spdlog.info('[Photo Mode Player Replacer] Error: ' .. message)
end

-- Core Logic --

local function ChangeAppearance(entity, appearance)
    if appearance ~= nil then
        entity:PrefetchAppearanceChange(appearance)
        entity:ScheduleAppearanceChange(appearance)
    end
end

local function SetDefaultAppearance(character, entity)
    local appearance
    if character == 'V' then
        appearance = vDefaultAppearances[PMPR.GetVEntity()]
    elseif character == 'Johnny' then
        appearance = jDefaultAppearances[PMPR.GetJEntity()]
    end
    PMPR.ToggleDefaultAppearance(false)
    ChangeAppearance(entity, appearance)
end

local function LocatePlayerPuppet()
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

local function SetupPMControllerVariables(this)
    local charactermenuItem = this:GetMenuItem(menuController.characterAttribute)
    local headerMenuItem = this:GetMenuItem(menuController.headerAttribute)
    local appearanceMenuItem = this:GetMenuItem(menuController.appearanceAttribute)
    local visibleMenuItem = this:GetMenuItem(menuController.visibleAttribute)

    local gameuiPMMC = {
        character = charactermenuItem.OptionLabelRef:GetText(),
        headerMenuItem = headerMenuItem,
        appearanceMenuItem = appearanceMenuItem,
        visibleMenuItem = visibleMenuItem,
        visibleMenuIndex = visibleMenuItem.OptionSelector.index,
    }
    return gameuiPMMC
end

local function RestrictAppearanceMenuItems(character, headerMenuItem, appearanceMenuItem)
    -- If Nibbles is selected, disable menu items
    if character == menuController.nibblesLocName then
        headerMenuItem.OptionLabelRef:SetText('-')
        headerMenuItem.OptionSelector.index = 0
        appearanceMenuItem.OptionLabelRef:SetText('-')
        appearanceMenuItem.OptionSelector.index = 0
    -- If default Johnny is selected
    elseif character == menuController.johnnyLocName and PMPR.GetJEntity() == 1 then
        appearanceMenuItem.OptionLabelRef:SetText(menuController.currParsedApp)
        appearanceMenuItem.OptionSelector.index = menuController.currAppIndex + 1
    else
        headerMenuItem.OptionLabelRef:SetText(menuController.currHeader)
        headerMenuItem.OptionSelector.index = menuController.currHeaderIndex
        appearanceMenuItem.OptionLabelRef:SetText(menuController.currParsedApp)
        appearanceMenuItem.OptionSelector.index = menuController.currAppIndex
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
    local filePaths = PMPR.modules.data.appearancesLists
    local censor = {
        oldTerms = {'Chubby', 'Freak', 'Junkie', 'Lowlife', 'Prostitute', 'Redneck', 'Youngster'},
        newTerms = {'Curvy', 'Eccentric', 'Vagrant', 'Working Class', 'Sexworker', 'Rural', 'Young Adult'},
    }

    for _, path in ipairs(filePaths) do
        local groupedAppearances = {headers = {}, data = {}}
        if path ~= '' then
            local requiredData = require(path)
            for _, line in ipairs(requiredData) do
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
end

function SetupLocalization()
    local record = PMPR.modules.data.defaultLocNames
    menuController.vLocName = PMPR.modules.properties.locNames.V
    menuController.johnnyLocName = PMPR.modules.properties.locNames.Johnny
    menuController.nibblesLocName = TweakDB:GetFlat(record)[3]

    -- If Nibbles Replacer exists, change naming convention to match this mod; else use default localized name
    if NibblesToNPCs then
        menuController.nibblesLocName = PMPR.modules.properties.locNames.Nibbles
    end

    TweakDB:SetFlat(record, {menuController.vLocName, menuController.johnnyLocName, menuController.nibblesLocName})
end

local function SetupObservers()
    Override("PhotoModeSystem", "IsPhotoModeActive", function(this, wrappedMethod)
        -- Prevent multiple callbacks on Override
        if isPhotoModeActive ~= wrappedMethod() then
            isPhotoModeActive = wrappedMethod()
            PMPR.modules.interface.ToggleInPhotoMode(wrappedMethod())
            -- Updates default appearance of replacer
            if isPhotoModeActive then
                PMPR.modules.interface.SetNotificationMessage('Unavailable within Photo Mode \n')
            end
            -- Resets the condition for updating default appearance if user doesn't change replacers before reopening photo mode
            if not isPhotoModeActive and not PMPR.IsDefaultAppearance() then
                PMPR.ToggleDefaultAppearance(true)
                menuController.isDefaultAppearance = true
            end
        end
        -- Presently needs the extra callbacks to work as intended
        if isPhotoModeActive and PMPR.IsDefaultAppearance() then
            local character, entity = LocatePlayerPuppet()
            if character and entity then
                SetDefaultAppearance(character, entity)
            end
        end
        if not isPhotoModeActive then
            menuController.currHeaderIndex = nil
            menuController.currAppIndex = nil
            menuController.currHeader = nil
            menuController.parsedApps = {}
            menuController.unparsedApps = {}
            menuController.initialized = false
        end
    end)

    Override("gameuiPhotoModeMenuController", "AddMenuItem", function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        wrappedMethod(label, attributeKey, page, isAdditional)
        if page == menuController.posePage and attributeKey == menuController.visibleAttribute then
            this:AddMenuItem(menuController.headerMenuItemLabel, menuController.headerAttribute, page, false)
            this:AddMenuItem(menuController.appearanceMenuItemLabel, menuController.appearanceAttribute, page, false)
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnShow", function(this, reversedUI)
        local headerMenuItem = this:GetMenuItem(menuController.headerAttribute)
        local appearanceMenuItem = this:GetMenuItem(menuController.appearanceAttribute)
        local charactermenuItem = this:GetMenuItem(menuController.characterAttribute)
        local character = charactermenuItem.OptionLabelRef:GetText()
        local headerIndex = 0
        local appIndex = 0
        local defaultAppearance, entIndex

        -- Initialize menu item values
        headerMenuItem.GridRoot:SetVisible(false)
        headerMenuItem.ScrollBarRef:SetVisible(false)
        headerMenuItem.OptionSelector:Clear()
        headerMenuItem.photoModeController = this
        appearanceMenuItem.GridRoot:SetVisible(false)
        appearanceMenuItem.ScrollBarRef:SetVisible(false)
        appearanceMenuItem.OptionSelector:Clear()
        appearanceMenuItem.photoModeController = this

        -- Get base character (V or Johnny) based on the 'Character' menu name and get parsed table
        if character == menuController.vLocName then
            entIndex = PMPR.GetVEntity()
            if entIndex == 1 then
                appearanceTable = {headers = {'-'}, data = {['-'] = {{parsed = '-', unparsed = '-'}}}}
                headerIndex = 1
                appIndex = 1
            else
                defaultAppearance = PMPR.modules.properties.defAppsV[PMPR.GetVEntity()].appearanceName
            end
        elseif character == menuController.johnnyLocName then
            entIndex = PMPR.GetJEntity()
            -- Set to Johnny's appearances list if Default option selected
            if entIndex == 1 then
                entIndex = 11
                headerIndex = 11
            end
            defaultAppearance = PMPR.modules.properties.defAppsJ[PMPR.GetJEntity()].appearanceName
        end
        
        -- Populate appearance table for selected entity if not default photo mode V
        if entIndex ~= 1 then
            appearanceTable = parsedTable[entIndex]
        end

        -- Update UI for default appearance settings if not default photo mode V
        if defaultAppearance then
            local found = false
            -- Search for replacer being set
            for h, replacer in ipairs(appearanceTable.headers) do
                if found then break end
                -- Search for matching appearance
                for a, appearanceData in ipairs(appearanceTable.data[replacer]) do
                    if appearanceData.unparsed == defaultAppearance then
                        -- Return indexes of replacer and appearance
                        headerIndex = h
                        appIndex = a
                        found = true
                        break
                    end
                end
            end
        end

        -- Populate appearance data
        for _, appearanceData in ipairs(appearanceTable.data[appearanceTable.headers[headerIndex]]) do
            table.insert(menuController.parsedApps, appearanceData.parsed)
            table.insert(menuController.unparsedApps, appearanceData.unparsed)
        end

        -- Setup header menu item
        headerMenuItem.OptionSelector.index = headerIndex - 1
        headerMenuItem.OptionLabelRef:SetText(appearanceTable.headers[headerIndex])
        headerMenuItem.OptionSelector.values = appearanceTable.headers

        -- Setup appearance menu item
        appearanceMenuItem.OptionSelector.index = appIndex - 1
        appearanceMenuItem.OptionLabelRef:SetText(menuController.parsedApps[appIndex])
        appearanceMenuItem.OptionSelector.values = menuController.parsedApps

        -- Setup persistent data
        menuController.currHeaderIndex = headerIndex
        menuController.currAppIndex = appIndex
        menuController.currHeaderCount = headerMenuItem.OptionSelector:GetValuesCount()
        menuController.currAppCount = appearanceMenuItem.OptionSelector:GetValuesCount()
        menuController.currHeader = appearanceTable.headers[headerIndex]
        menuController.currParsedApp = menuController.parsedApps[appIndex]
        menuController.currUnparsedApp = menuController.unparsedApps[appIndex]
        menuController.initialized = true
    end)

    Observe("gameuiPhotoModeMenuController", "OnAttributeUpdated", function(this, attributeKey, attributeValue, doApply)
        if  menuController.initialized then

            -- If character attribute is updated
            if attributeKey == menuController.characterAttribute then
                gameuiPMMC = SetupPMControllerVariables(this)
                RestrictAppearanceMenuItems(gameuiPMMC.character, gameuiPMMC.headerMenuItem, gameuiPMMC.appearanceMenuItem)
            end

            -- If header attribute is updated
            if attributeKey == menuController.headerAttribute then
                gameuiPMMC = SetupPMControllerVariables(this)

                -- Prevent header options from changing in Nibbles options, when 'Character Visible' is set to 'Off' for V/Johnny, or when there is only one header value
                if gameuiPMMC.character == menuController.nibblesLocName or gameuiPMMC.visibleMenuIndex == 0 or menuController.currHeaderCount == 1 then
                    RestrictAppearanceMenuItems(gameuiPMMC.character, gameuiPMMC.headerMenuItem, gameuiPMMC.appearanceMenuItem)
                else
                    local headerIndex = gameuiPMMC.headerMenuItem.OptionSelector.index + 1
                    local unused, entity = LocatePlayerPuppet()
                    -- Clear appearance data
                    menuController.parsedApps = {}
                    menuController.unparsedApps = {}

                    -- Repopulate appearance data
                    for _, appearanceData in ipairs(appearanceTable.data[appearanceTable.headers[headerIndex]]) do
                        table.insert(menuController.parsedApps, appearanceData.parsed)
                        table.insert(menuController.unparsedApps, appearanceData.unparsed)
                    end

                    -- Update appearance menu item
                    gameuiPMMC.appearanceMenuItem.OptionSelector.values = menuController.parsedApps
                    gameuiPMMC.appearanceMenuItem.OptionSelector.index = 0
                    gameuiPMMC.appearanceMenuItem.OptionLabelRef:SetText(menuController.parsedApps[1])

                    -- Update persistent data
                    menuController.currHeaderIndex = headerIndex - 1
                    menuController.currAppIndex = 1
                    menuController.currHeaderCount = gameuiPMMC.headerMenuItem.OptionSelector:GetValuesCount()
                    menuController.currAppCount = gameuiPMMC.appearanceMenuItem.OptionSelector:GetValuesCount()
                    menuController.currHeader = appearanceTable.headers[headerIndex]
                    menuController.currParsedApp = menuController.parsedApps[menuController.currAppIndex]
                    menuController.currUnparsedApp = menuController.unparsedApps[menuController.currAppIndex]

                    ChangeAppearance(entity, menuController.currUnparsedApp)
                end
            end

            -- If appearance attribute is updated
            if attributeKey == menuController.appearanceAttribute then
                gameuiPMMC = SetupPMControllerVariables(this)

                -- Prevent appearance options from changing in Nibbles options, when 'Character Visible' is set to 'Off' for V/Johnny, or when there is only one header value
                if gameuiPMMC.character == menuController.nibblesLocName or gameuiPMMC.visibleMenuIndex == 0 or menuController.currAppCount == 1 then
                    RestrictAppearanceMenuItems(gameuiPMMC.character, gameuiPMMC.headerMenuItem, gameuiPMMC.appearanceMenuItem)
                else
                    local unused, entity = LocatePlayerPuppet()

                    -- Update persistent data
                    menuController.currAppIndex = gameuiPMMC.appearanceMenuItem.OptionSelector.index + 1
                    menuController.currParsedApp = menuController.parsedApps[menuController.currAppIndex]
                    menuController.currUnparsedApp = menuController.unparsedApps[menuController.currAppIndex]

                    ChangeAppearance(entity, menuController.currUnparsedApp)
                end
            end
        end
    end)
end

registerForEvent('onTweak', SetupLocalization)

registerForEvent('onInit', function ()
    CheckDependencies()
    Initialize()
    ParseAppearanceLists()
    SetupObservers()

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