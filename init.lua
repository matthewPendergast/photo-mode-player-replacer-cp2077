vReplacer = {
    ready = false,
    config = require('modules/config.lua'),
    interface = require('modules/interface.lua'),
    settings = require('settings'),
    -- AMM Compatibility variables:
    vEntity = 1,
    jEntity = 1,
    isReplacerManBig = false
}

local AMM = nil
local playerGender = nil
local isOverlayOpen = false
local isPhotoModeActive = nil

function vReplacer.SetVEntity(index)
    vReplacer.vEntity = index
end

function vReplacer.SetJEntity(index)
    vReplacer.jEntity = index
end

function vReplacer.ToggleReplacerManBig(bool)
    vReplacer.isReplacerManBig = bool
end

function SetupLocalization()
    local record = 'photo_mode.general.localizedNameForPhotoModePuppet'
    local locNameNibbles = TweakDB:GetFlat(record)[3]

    -- If Nibbles Replacer exists, change naming convention to match this mod; else use default localized name
    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        locNameNibbles = settings.locNames.Nibbles
    end

    TweakDB:SetFlat(record, {settings.locNames.V, settings.locNames.Johnny, locNameNibbles})
end

function Listeners()
    Override('PhotoModeSystem', 'IsPhotoModeActive', function(this, wrappedMethod)
        if isPhotoModeActive ~= wrappedMethod() then
            isPhotoModeActive = wrappedMethod()
        end
    end)
end

function GetDefaultAppearances()
    for i, entry in ipairs(settings.defNamesV) do
        vDefaultAppearances[i] = entry.appearanceName
    end
end

function UpdatePlayerGender()
    -- Ugly check for changes to player gender until a check can be implemented for when the game loads a new save file
    if playerGender ~= string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')() then
        playerGender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
        vReplacer.config.SetupReplacer(playerGender)
    end
end

registerForEvent('onTweak', SetupLocalization)

registerForEvent('onInit', function()
    if not vReplacer.ready then
        vReplacer.ready = true
    end
    if not AMM then
        AMM = GetMod('AppearanceMenuMod')
    end
    Listeners()
    GetDefaultAppearances()
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
    elseif isOverlayOpen and playerGender ~= nil then
        interface.SetupUI()
    end
end)

registerForEvent('onUpdate', function()
    UpdatePlayerGender()
end)

return vReplacer