--[[ To Do:
    - Need to fix how AMM chooses available poses so that it accurately reflects gender and frame swaps
    - Currently, AMM's Big poses probably won't work at all, since they are hidden by AMM
]]

vReplacer = {
    ready = false,
    config = require('modules/config.lua'),
    UI = require('interface.lua'),
    settings = require('settings'),
    vEntSelected = 1, -- necessary for AMM compatibility
}

local AMM = nil
local playerGender = nil
local isOverlayOpen = false
local isPhotoModeActive = nil
local isDefaultAppearance = nil
local newDefaults = {
    nil,
    'Panam Palmer_Default',
    'Johnny Silverhand_Default',
    'Jackie Welles_Default',
    'appearance_01',
    'appearance_01',
    'appearance_01',
    'appearance_01',
    'appearance_01',
    'appearance_01',
}
local vOptions = {
    'Default (V)',
    'Feminine NPCs',
    'Masculine NPCs (average build)',
    'Masculine NPCs (big build)',
    'Feminine NPV 1',
    'Feminine NPV 2',
    'Masculine NPV 1 (average build)',
    'Masculine NPV 2 (average build)',
    'Masculine NPV 1 (big build)',
    'Masculine NPV 2 (big build'
}
local jOptions = vOptions
jOptions[1] = 'Default (Johnny)'
local vSelection = 'Default (V)'
local jSelection = 'Default (Johnny)'

function SetupLocalization()
    local record = 'photo_mode.general.localizedNameForPhotoModePuppet'
    local newNibblesName = TweakDB:GetFlat(record)[3]

    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        newNibblesName = settings.Nibbles
    end

    TweakDB:SetFlat(record, {settings.V, settings.Johnny, newNibblesName})
end

function Listeners()
    Override('PhotoModeSystem', 'IsPhotoModeActive', function(this, wrappedMethod)
        if isPhotoModeActive ~= wrappedMethod() then
            isPhotoModeActive = wrappedMethod()
        end
    end)
end

function SetupUI()

    ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, 250, 0)

    if not ImGui.Begin('Photo Mode Character Selector', true, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.End()
        return
    end

    if ImGui.BeginTabBar('##TabBar1') then
        if ImGui.BeginTabItem('V Replacer') then
            if ImGui.BeginCombo('##Combo1', vSelection) then
                for index, option in ipairs(vOptions) do
                    if ImGui.Selectable(option, (option == vSelection)) then
                        vSelection = option
                        vReplacer.vEntSelected = index
                        vReplacer.config.SetPuppetTable(index)
                        ImGui.SetItemDefaultFocus()
                        if index ~= 1 then
                            isDefaultAppearance = true
                        end
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Johnny Replacer') then
            if ImGui.BeginCombo('##Combo2', jSelection) then
                for index, option in ipairs(vOptions) do
                    if ImGui.Selectable(option, (option == jSelection)) then
                        jSelection = option
                        -- Set Puppet Table for Johnny (function needs second parameter and conditions for Johnny)
                        -- may also need to FixDefaultAppearance
                        ImGui.SetItemDefaultFocus()
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
    ImGui.End()
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
    if isPhotoModeActive and vReplacer.vEntSelected ~= 1 and isDefaultAppearance then
        local target = AMM.Tools:GetVTarget()
        if target then
            -- If NPV selected, cycle before restoring default
            if vReplacer.vEntSelected > 4 then
                AMM.API.ChangeAppearance(target.handle, 'Cycle')
            end
            AMM.API.ChangeAppearance(target.handle, newDefaults[vReplacer.vEntSelected])
            isDefaultAppearance = false
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
        SetupUI()
    end
end)

-- UpdatePlayerGender() to be moved out of onUpdate and only checked when a save file is loaded
-- Similarly, FixDefaultAppearance() should be called when photo mode is entered, then check for conditions
registerForEvent('onUpdate', function()
    UpdatePlayerGender()
    FixDefaultAppearance()
end)

return vReplacer