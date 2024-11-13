vReplacer = {
    ready = false,
    config = require('modules/config.lua'),
    interface = require('modules/interface.lua'),
    settings = require('settings'),
    -- AMM Compatibility --
    vEntity = 1,
    jEntity = 1,
    isDefaultAppearance = false,
    isReplacerManBig = false
}

local AMM = nil
local playerGender = nil
local isOverlayOpen = false
local isPhotoModeActive = nil
local vDefaultAppearances = {}
local jDefaultAppearances = {}
local entityIDs = {
    -- 1: Default V
    '0x9EDC71E0, 33',
    -- 2: Feminine NPCs
    '0x0A3C562E, 27',
    -- 3: Masculine NPCs (average build)
    '0xFE8C160B, 25',
    -- 4: Masculine NPCs (big build)
    '0xC7412FD0, 21',
    -- 5: Feminine NPV 1
    '0xD9FCEA9A, 22',
    -- 6: Feminine NPV 2
    '0x40F5BB20, 22',
    -- 7: Masculine NPV 1 (average build)
    '0xF5587EED, 23',
    -- 8: Masculine NPV 2 (average build)
    '0x6C512F57, 23',
    -- 9: Masculine NPV 1 (big build)
    '0xA56B6C23, 22',
    -- 10: Masculine NPV 2 (big build)
    '0x3C623D99, 22',
    -- 11: Johnny Default
    '0xA773A53F, 33',
}

function vReplacer.SetVEntity(index)
    vReplacer.vEntity = index
end

function vReplacer.SetJEntity(index)
    vReplacer.jEntity = index
end

function vReplacer.ToggleDefaultAppearance(bool)
    vReplacer.isDefaultAppearance = bool
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

function SetupEventHandlers()
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
                if ID == entityIDs[11] then
                    AMM.API.ChangeAppearance(entity, jDefaultAppearances[vReplacer.jEntity])
                    vReplacer.isDefaultAppearance = false
                end
            end
        end
    end
end

function UpdatePlayerGender()
    -- TODO: Ugly check for changes to player gender until a check is implemented with Codeware
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
    SetupEventHandlers()
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
    -- TODO: This check needs to be changed when SetDefaultAppearance is fully implemented
    if isPhotoModeActive and vReplacer.jEntity ~= 1 and vReplacer.isDefaultAppearance == true then
        SetDefaultAppearance()
    end
end)

return vReplacer