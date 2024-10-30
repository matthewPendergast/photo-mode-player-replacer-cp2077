vReplacer = {
    ready = false,
    config = require('config'),
    vEntSelected = 1 -- necessary for AMM compatibility
}

local isOverlayOpen = false
local DropdownOptions = {
    'Default', 'Feminine', 'Masculine', 'Big Body Type',
    'NPV Feminine 1', 'NPV Feminine 2', 'NPV Masculine 1', 'NPV Masculine 2',
    'NPV Big Body Type 1', 'NPV Big Body Type 2'
}
local DropdownSelected = 'Default'
local playerGender = nil

function SetupLocalization()
    local record = 'photo_mode.general.localizedNameForPhotoModePuppet'
    local newVName = 'V Replacer'
    local newJohnnyName = 'Johnny Replacer'
    local newNibblesName = TweakDB:GetFlat(record)[3]

    if ModArchiveExists('Photomode_NPCs_AMM.archive') then
        newNibblesName = 'Nibbles Replacer'
    end

    TweakDB:SetFlat(record, {newVName, newJohnnyName, newNibblesName})
end

function SetupUI ()

    if not isOverlayOpen then
        return
    end

    if ImGui.Begin('V Replacer Menu', ImGuiWindowFlags.AlwaysAutoResize) then
        -- Prevents user from setting gender to nil before it has loaded
        -- Seems as if it is slowing down initialization of all CET mods
        -- This check might be better implemented in config
        -- Maybe set defaults to Johnny if gender is nil
        if playerGender == nil then
            ImGui.Text('Initializing')
        else
            ImGui.Text('Select an entity:')

            if playerGender ~= nil then
                if ImGui.BeginCombo('', DropdownSelected) then
    
                    for index, option in ipairs(DropdownOptions) do
            
                        if ImGui.Selectable(option, (option == DropdownSelected)) then
                            DropdownSelected = option
                            vReplacer.vEntSelected = index
                            vReplacer.config.SetPuppetTable(index)
                            ImGui.SetItemDefaultFocus()
                        end
            
                    end
                    ImGui.EndCombo()
                end
            end
        end
        -- To Do: Johnny Replacer option
        -- No need to do V -> Johnny (already covered in Masculine swap)
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

registerForEvent('onTweak', SetupLocalization)

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

-- Needs to be moved out of onUpdate and only checked when a save file is loaded
registerForEvent('onUpdate', UpdatePlayerGender)

return vReplacer