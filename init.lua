vReplacer = {
    ready = false,
    data = require('modules/data.lua'),
    interface = require('modules/interface.lua'),
    settings = require('settings'),
}

-- External Modules --

local AMM = nil
local NibblesToNPCs = nil
local GameSession = require('external/GameSession')

-- Game State --

local playerGender = nil
local isOverlayOpen = false
local isPhotoModeActive = false

-- Mod Settings --

local vDefaultAppearances = {}
local jDefaultAppearances = {}
local isDefaultAppearance = false
local isReplacerManBig = false

-- Accessors --

function vReplacer.GetVEntity()
    vEntity = vReplacer.vEntity
    return vEntity
end

-- @param index: integer 1-10
function vReplacer.SetVEntity(index)
    vReplacer.vEntity = index
end

function vReplacer.GetJEntity()
    return jEntity
end

-- @param index: integer 1-10
function vReplacer.SetJEntity(index)
    jEntity = index
end

function vReplacer.isDefaultAppearance()
    return isDefaultAppearance
end

function vReplacer.ToggleDefaultAppearance(bool)
    isDefaultAppearance = bool
end

function vReplacer.IsReplacerManBig()
    return isReplacerManBig
end

function vReplacer.ToggleReplacerManBig(bool)
    isReplacerManBig = bool
end

-- Initialization --

function InitializeMod()
    AMM = GetMod('AppearanceMenuMod')
    if not AMM then
        spdlog.info('[VReplacer] AppearanceMenuMod not installed')
    end
    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        NibblesToNPCs = true
    else
        spdlog.info('[VReplacer] Nibbles To NPCs 2.0 not installed')
    end
    vReplacer.ready = true
end

function SetupLocalization()
    local record = 'photo_mode.general.localizedNameForPhotoModePuppet'
    local locNameNibbles = TweakDB:GetFlat(record)[3]

    -- If Nibbles Replacer exists, change naming convention to match this mod; else use default localized name
    if NibblesToNPCs then
        locNameNibbles = settings.locNames.Nibbles
    end

    TweakDB:SetFlat(record, {settings.locNames.V, settings.locNames.Johnny, locNameNibbles})
end

function SetupEventHandlers()
    Override('PhotoModeSystem', 'IsPhotoModeActive', function(this, wrappedMethod)
        isPhotoModeActive = wrappedMethod()
        -- Sets default appearance of Johnny Replacer
        if isPhotoModeActive and jEntity ~= 1 and isDefaultAppearance then
            SetDefaultAppearance()
        end
        -- Resets the condition for updating default appearance if user doesn't change replacers before reopening photo mode
        if not isPhotoModeActive and not isDefaultAppearance then
            vReplacer.ToggleDefaultAppearance(true)
        end
    end)
    
end

function PopulateDefaultAppearances()
    for i, entry in ipairs(settings.defNamesV) do
        vDefaultAppearances[i] = entry.appearanceName
    end
    for i, entry in ipairs(settings.defNamesJ) do
        jDefaultAppearances[i] = entry.appearanceName
    end
end

-- Currently hard-coded to fix Johnny default appearance cycling
-- TODO: Needs to be implemented to work for both V and Johnny
function SetDefaultAppearance()
    local player = Game.GetPlayer()
    local tsq = TSQ_ALL()
    local success, parts = Game.GetTargetingSystem():GetTargetParts(player, tsq)
    if success then
        for _, part in ipairs(parts) do
            local entity = part:GetComponent(part):GetEntity()
            if entity then
                local ID = AMM:GetScanID(entity)
                if ID == vReplacer.data.GetEntityID(11) then
                    AMM.API.ChangeAppearance(entity, jDefaultAppearances[jEntity])
                    vReplacer.ToggleDefaultAppearance(false)
                end
            end
        end
    end
end

function UpdatePlayerGender()
    if not playerGender then
        playerGender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
        vReplacer.data.SetupReplacer(playerGender)
    end
end

-- Event Handlers --

registerForEvent('onTweak', SetupLocalization)

registerForEvent('onInit', function()
    InitializeMod()
    SetupEventHandlers()
    PopulateDefaultAppearances()
    GameSession.OnStart(function()
        if not playerGender then
            UpdatePlayerGender()
        end
    end)
    GameSession.OnEnd(function()
        if playerGender then
            playerGender = nil
        end
    end)
end)

registerForEvent('onOverlayOpen', function()
    isOverlayOpen = true
end)

registerForEvent('onOverlayClose', function()
    isOverlayOpen = false
end)

registerForEvent('onDraw', function ()
    if not isOverlayOpen then
        return
    elseif isOverlayOpen and playerGender then
        interface.SetupUI()
    end
end)

return vReplacer