vReplacer = {
    ready = false,
    config = require('modules/config.lua'),
    interface = require('modules/interface.lua'),
    settings = require('settings'),
    vEntSelected = 1, -- necessary for AMM compatibility
    isDefaultAppearance = nil
}

local AMM = nil
local playerGender = nil
local isOverlayOpen = false
local isPhotoModeActive = nil
local vDefaultAppearances = {}

function vReplacer.SetVEntSelected(index)
    vReplacer.vEntSelected = index
end

function vReplacer.ToggleDefaultAppearance(bool)
    vReplacer.isDefaultAppearance = bool
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
    if playerGender == nil then
        playerGender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
        if playerGender then
            vReplacer.config.SetupReplacer(playerGender)
        end
    end
end

function FixDefaultAppearance()
    local target = AMM.Tools:GetVTarget()
    if target then
        -- If NPV selected, cycle before restoring default
        if vReplacer.vEntSelected > 4 then
            AMM.API.ChangeAppearance(target.handle, 'Cycle')
        end
        AMM.API.ChangeAppearance(target.handle, vDefaultAppearances[vReplacer.vEntSelected])
        vReplacer.ToggleDefaultAppearance(false)
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
    UpdatePlayerGender() -- needs to only be checked when a save file is loaded
    if isPhotoModeActive and vReplacer.vEntSelected ~= 1 and vReplacer.isDefaultAppearance then
        FixDefaultAppearance()
    end
end)

return vReplacer