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

-- Game State --
local isPhotoModeActive = false
local isOverlayOpen = false

-- Local Settings --
local vDefaultAppearances = {}
local jDefaultAppearances = {}

local menuController = {
    posePage = 2,
    characterAttribute = 38,
    visibleAttribute = 27,
    appearanceAttribute = 9000,
    menuItemLabel = 'CHARACTER APPEARANCE',
    isDefaultAppearance = true
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

local function PullAppearancesList(index)
    local files = PMPR.modules.data.appearancesLists
    return files[index]
end

local function GetUserDefaultAppIndex(appearanceList, character)
    -- To Do: Account for Johnny replacer
    local defaultAppearance = PMPR.modules.properties.defAppsV[PMPR.GetVEntity()].appearanceName
    local index
    for i, appearance in ipairs(appearanceList) do
        if appearance == defaultAppearance then
            index = i
        end
    end
    return index
end

-- Initialization --

local function CheckDependencies()
    AMM = GetMod('AppearanceMenuMod')

    if not AMM then
        HandleError('Missing Requirement - Appearance Menu Mod')
    end

    if not ModArchiveExists('Photomode_NPCs_AMM.archive') then
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
    end)

    Override("gameuiPhotoModeMenuController", "AddMenuItem", function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        wrappedMethod(label, attributeKey, page, isAdditional)
        if page == menuController.posePage and attributeKey == menuController.visibleAttribute then
            this:AddMenuItem(menuController.menuItemLabel, menuController.appearanceAttribute, page, false)
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnShow", function(this, reversedUI)
        local charactermenuItem = this:GetMenuItem(menuController.characterAttribute)
        local character = charactermenuItem.OptionLabelRef:GetText()
        local appearanceMenuItem = this:GetMenuItem(menuController.appearanceAttribute)
        local index = appearanceMenuItem.OptionSelector.index + 1
        local filePath, appearances

        if character == 'V' then
            filePath = PullAppearancesList(PMPR.GetVEntity())
        elseif character == 'Johnny' then
            local entIndex = PMPR.GetJEntity()
            -- Set to Johnny's appearance list index
            if entIndex == 1 then
                entIndex = 11
            end
            filePath = PullAppearancesList(entIndex)
        end

        if filePath ~= '' then
            appearances = require(filePath)
        else
            -- To Do: Set menu item invisible instead
            appearances = 'V'
        end

        -- Initialize menu item values
        appearanceMenuItem.GridRoot:SetVisible(false)
        appearanceMenuItem.ScrollBarRef:SetVisible(false)
        appearanceMenuItem.allowHold = true
        appearanceMenuItem.OptionSelector:Clear()
        appearanceMenuItem.OptionSelector.values = appearances
        appearanceMenuItem.photoModeController = this

        if menuController.isDefaultAppearance then
            index = GetUserDefaultAppIndex(appearances)
            appearanceMenuItem.OptionSelector.index = index - 1
            menuController.isDefaultAppearance = false
        end

        appearanceMenuItem.OptionLabelRef:SetText(appearances[index])
    end)

    Observe("gameuiPhotoModeMenuController", "OnAttributeUpdated", function(this, attributeKey, attributeValue, doApply)
        if attributeKey == menuController.appearanceAttribute then
            local appearanceMenuItem = this:GetMenuItem(menuController.appearanceAttribute)
            local appearance = appearanceMenuItem.OptionLabelRef:GetText()
            local unused, entity = LocatePlayerPuppet()
            ChangeAppearance(entity, appearance)
        end
    end)
end

registerForEvent('onInit', function ()
    CheckDependencies()
    Initialize()
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