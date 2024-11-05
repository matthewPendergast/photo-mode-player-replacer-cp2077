--[[ To Do:
    - Update how AMM pulls appearances for V Replacer
    - Need to fix how AMM chooses available poses so that it accurately reflects gender and frame swaps
    - Currently, AMM's Big poses probably won't work at all, since they are hidden by AMM
]]

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
local newVDefaults = {}

function vReplacer.SetVEntSelected(index)
    vReplacer.vEntSelected = index
end

function vReplacer.ToggleIsDefaultAppearance(bool)
    vReplacer.isDefaultAppearance = bool
end

function SetupLocalization()
    local record = 'photo_mode.general.localizedNameForPhotoModePuppet'
    local newNibblesName = TweakDB:GetFlat(record)[3]

    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        newNibblesName = settings.locNames.Nibbles
    end

    TweakDB:SetFlat(record, {settings.locNames.V, settings.locNames.Johnny, newNibblesName})
end

function Listeners()
    Override('PhotoModeSystem', 'IsPhotoModeActive', function(this, wrappedMethod)
        if isPhotoModeActive ~= wrappedMethod() then
            isPhotoModeActive = wrappedMethod()
        end
    end)
end

function GetUserDefaults()
    for i, entry in ipairs(settings.defNamesV) do
        newVDefaults[i] = entry.appearanceName
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
    if isPhotoModeActive and vReplacer.vEntSelected ~= 1 and vReplacer.isDefaultAppearance then
        local target = AMM.Tools:GetVTarget()
        -- Use for v entity:
        --print(target)
        --print(target.handle)
        if target then
            -- If NPV selected, cycle before restoring default
            if vReplacer.vEntSelected > 4 then
                AMM.API.ChangeAppearance(target.handle, 'Cycle')
            end
            AMM.API.ChangeAppearance(target.handle, newVDefaults[vReplacer.vEntSelected])
            vReplacer.ToggleIsDefaultAppearance(false)
        end
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
    GetUserDefaults()
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

-- UpdatePlayerGender() to be moved out of onUpdate and only checked when a save file is loaded
-- Similarly, FixDefaultAppearance() should be called when photo mode is entered, then check for conditions
registerForEvent('onUpdate', function()
    UpdatePlayerGender()
    FixDefaultAppearance()
end)

return vReplacer