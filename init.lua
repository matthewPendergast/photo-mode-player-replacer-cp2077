vReplacer = {
    ready = false,
    config = require('config')
}

local isOverlayOpen = false
local DropdownOptions = {
    "Default", "Feminine", "Masculine", "Big Body Type",
    "NPV Feminine 1", "NPV Feminine 2", "NPV Masculine 1", "NPV Masculine 2",
    "NPV Big Body Type 1", "NPV Big Body Type 2"
}
local DropdownSelected = "Default"
local playerGender = nil

function SetupReplacer()

    SetupLocalization()
    --SetPlayerGender()

end

function SetupUI ()

    if not isOverlayOpen then
        return
    end

    if ImGui.Begin('V Replacer Menu', ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.Text('Select an entity:')

        if ImGui.BeginCombo("", DropdownSelected) then

            for _, option in ipairs(DropdownOptions) do
    
                if ImGui.Selectable(option, (option == DropdownSelected)) then
                    DropdownSelected = option
                    ImGui.SetItemDefaultFocus()
                    -- To Do: Implement table for options and related values for SetPuppetTable()
                    if option == "NPV Feminine 2" then
                        vReplacer.config.SetPuppetTable()
                        -- To Do: Somehow change which appearances list AMM points to depending on new entity
                        -- Almost certainly will need to be done within AMM
                    end
                end
    
            end
    
            ImGui.EndCombo()
        end

        -- To Do: Johnny Replacer option

    end

    ImGui.End()
end

function SetPlayerGender()
    -- To Do: Needs better implementation
    -- Currently updates onUpdate
    -- Player's gender is only needed for setting default V values; potentially not needed at all
    if playerGender == nil then
        playerGender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
        vReplacer.config.SetPlayerEntity(playerGender)
    end
end

function SetupLocalization()
    local record = 'photo_mode.general.localizedNameForPhotoModePuppet'
    local defaultNames = TweakDB:GetFlat(record)
    local newVName = 'V Replacer'
    local newJohnnyName = 'Johnny Replacer'
    local newNibblesName = defaultNames[3]

    -- To Do: Find LocKey value similar to 'Replacer' in order to have non-English localization; concatenate with default names

    -- If load order changes, retains AMM localization changes for Nibbles Replacer, unless naming is still default
    -- To Do: This doesn't account for non-English LocKey values for Nibbles, though
        -- Need to figure out how to return LocKey values through CET and possibly convert to a string for comparison to newNibblesName
    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        if newNibblesName == 'Nibbles' then
            newNibblesName = 'Nibbles Replacer'
        end
    end

    TweakDB:SetFlat(record, {newVName, newJohnnyName, newNibblesName})
end

registerForEvent('onTweak', SetupReplacer)

registerForEvent('onInit', function()
    vReplacer.ready = true
end)

registerForEvent('onOverlayOpen', function()
    isOverlayOpen = true
end)

registerForEvent('onOverlayClose', function()
    isOverlayOpen = false
end)

registerForEvent('onDraw', SetupUI)

--registerForEvent('onUpdate', SetPlayerGender)

return vReplacer