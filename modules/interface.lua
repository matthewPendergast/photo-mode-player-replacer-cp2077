interface = {}

local vReplacer = require('init')
local config = require('modules/config.lua')
local vOptions = {
    'Default',
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
local vSelection = vOptions[1]
local jSelection = jOptions[1]

function interface.SetupUI()

    ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, 245, 0)

    if not ImGui.Begin('Photo Mode Character Selector', true, ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.MenuBar) then
        ImGui.End()
        return
    end

    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("Menu") then
            if ImGui.MenuItem("Set Default Appearances") then
                -- TODO
            end
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end

    if ImGui.BeginTabBar('##TabBar') then
        if ImGui.BeginTabItem('V Replacer') then
            ImGui.TextDisabled("Choose a character model:")
            if ImGui.BeginCombo('##Combo1', vSelection) then
                for index, option in ipairs(vOptions) do
                    if ImGui.Selectable(option, (option == vSelection)) then
                        vSelection = option
                        vReplacer.SetVEntSelected(index)
                        config.SetPuppetTable(index)
                        ImGui.SetItemDefaultFocus()
                        if index ~= 1 then
                            vReplacer.ToggleIsDefaultAppearance(true)
                        end
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Johnny Replacer') then
            ImGui.TextDisabled("Choose a character model:")
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

return interface