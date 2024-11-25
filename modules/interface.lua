local interface = {
    initialized = false,
    errorOccurred = false,
    vEntity = 1,
    jEntity = 1,
    isDefaultAppearance = false,
    characterTypes = {},
    tweakDBID = {},
    defaultPaths = {},
    entityPaths = {},
    puppetTable = {},
    puppetTorsoRecord = nil,
    puppetTorsoAppearance = nil,
    modName = 'Photo Mode Player Replacer',
    mainMenu = 'Menu',
    mainMenuItemA = 'Set Default Appearances',
    notificationArea = 'Status Feed',
    statusFeedLines = 3,
    notificationMessage = 'Initializing... \n',
}

local user = {
    isLoadingSaveFile = false,
    isInPhotoMode = false,
}

local vSelection = 'Default'
local jSelection = 'Default'
local defaultTemplate = nil
local defaultEntity = nil

-- Accessors --

function interface.SetNotificationMessage(message)
    interface.notificationMessage = message
end

function interface.IsLoadingSaveFile()
    return user.isLoadingSaveFile
end

function interface.ToggleLoadingSaveFile(bool)
    user.isLoadingSaveFile = bool
end

function interface.IsInPhotoMode()
    return user.isInPhotoMode
end

function interface.ToggleInPhotoMode(bool)
    user.isInPhotoMode = bool
end

-- Error Handling --

function interface.NotifyError(message)
    local errorType, errorMessage = message:match("^(.-)( %-.*)$")
    -- Clear initializing notification but retain prior error messages
    if not interface.errorOccurred then
        interface.notificationMessage = ''
    end
    interface.notificationMessage = interface.notificationMessage .. errorType .. '\n' .. errorMessage .. '\n'
    interface.statusFeedLines = interface.statusFeedLines + 2
    interface.errorOccurred = true
end

-- Initialization --

function interface.Initialize(data)
    -- Pull values from data module
    interface.characterTypes = data.characterTypes
    interface.tweakDBID = data.tweakDBID
    interface.defaultPaths = data.defaultPaths
    interface.entityPaths = data.entityPaths
    interface.puppetTorsoRecord = data.puppetTorsoRecord
    interface.puppetTorsoAppearance = data.puppetTorsoAppearance

    -- Initialize interface settings
    vSelection = interface.characterTypes[1]
    jSelection = interface.characterTypes[1]

    -- Populate puppetTable
    for i = 1, 4 do
        table.insert(interface.puppetTable, {
            characterRecord = data.tweakDBID[i],
            path = data.defaultPaths[9]
        })
    end

    interface.initialized = true
end

-- Core Logic --

function interface.SetupDefaultV(gender)
    local index = 1

    if gender == 'Female' then
        index = index + 2
    end

    if IsEP1() then
        index = index + 4
    end

    defaultTemplate = interface.defaultPaths[index]
    defaultEntity = interface.defaultPaths[index + 1]

    interface.SetPuppetTable(1, 'V')
end

function interface.SetPuppetTable(index, character)
    if character == 'V' then
        for i, entry in ipairs(interface.puppetTable) do
            -- If entry is not Johnny
            if i ~= 4 then
                -- If resetting to default V
                if index == 1 then
                    if i == 1 then
                        TweakDB:SetFlat(entry.characterRecord, defaultTemplate)
                    else
                        TweakDB:SetFlat(entry.characterRecord, defaultEntity)
                    end
                -- If replacing V
                else
                    TweakDB:SetFlat(entry.characterRecord, interface.entityPaths[index])
                end
            end
        end
    elseif character == 'Johnny' then
        -- If resetting to Johnny
        if index == 1 then
            TweakDB:SetFlat(interface.puppetTable[4].characterRecord, interface.defaultPaths[9])
        -- If replacing Johnny
        else
            TweakDB:SetFlat(interface.puppetTable[4].characterRecord, interface.entityPaths[index])
        end
    end

    -- Toggle TPP for player or replacer
    if index == 1 then
        TweakDB:SetFlat(interface.puppetTorsoRecord, interface.puppetTorsoAppearance)
    else
        TweakDB:SetFlat(interface.puppetTorsoRecord, '')
    end
end

function interface.ResetInterface()
    vSelection = 'Default'
    jSelection = 'Default'
    interface.vEntity = 1
    interface.jEntity = 1
    interface.SetPuppetTable(1, 'Johnny')
end

-- ImGui --

function interface.DrawUI()

    ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, 330, 0)

    if not ImGui.Begin(interface.modName, true, ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.MenuBar) then
        ImGui.End()
        return
    end

    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu(interface.mainMenu) then
            if ImGui.MenuItem(interface.mainMenuItemA) then
                -- To Do: open modal with dropdown menu populated with appearances pulled from AMM, which are then saved to settings.lua
            end
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end

    -- Pre-load
    if not interface.initialized or interface.errorOccurred or user.isLoadingSaveFile or user.isInPhotoMode then
        ImGui.TextColored(0.5, 0.5, 0.5, 1, interface.notificationArea)
        interface.notificationMessage = ImGui.InputTextMultiline("##InputTextMultiline9", interface.notificationMessage, 330, -1, interface.statusFeedLines * ImGui.GetTextLineHeight())
    -- Post-load
    elseif interface.initialized and not interface.errorOccurred then
        if ImGui.BeginTabBar('##TabBar') then
            if ImGui.BeginTabItem('V Replacer') then
                ImGui.TextDisabled('Choose a character model:')
                if ImGui.BeginCombo('##Combo1', vSelection) then
                    for index, option in ipairs(interface.characterTypes) do
                        if ImGui.Selectable(option, (option == vSelection)) then
                            vSelection = option
                            interface.vEntity = index
                            interface.SetPuppetTable(index, 'V')
                            ImGui.SetItemDefaultFocus()
                            if index ~= 1 then
                                interface.isDefaultAppearance = true
                            end
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem('Johnny Replacer') then
                ImGui.TextDisabled('Choose a character model:')
                if ImGui.BeginCombo('##Combo2', jSelection) then
                    for index, option in ipairs(interface.characterTypes) do
                        if ImGui.Selectable(option, (option == jSelection)) then
                            jSelection = option
                            interface.jEntity = index
                            interface.SetPuppetTable(index, 'Johnny')
                            ImGui.SetItemDefaultFocus()
                            if index ~= 1 then
                                interface.isDefaultAppearance = true
                            end
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

end

return interface