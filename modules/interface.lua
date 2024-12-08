local interface = {
    ready = false,
    userSettings = require('user/settings.lua'),
    options = {
        vIndex = 1,
        jIndex = 1,
    },
    state = {
        errorOccurred = false,
        isDefaultAppearance = false,
        isAppearancesListUpdated = false,
        isPhotoModeActive = false,
        isGameLoadingSaveFile = false,
    },
    modName = 'Photo Mode Player Replacer',
    menuA = 'Menu',
    menuItemA = 'Set Default Appearances',
    menuItemB = 'Set Custom NPV Names',
    notificationArea = 'Status Feed',
    statusFeedLines = 3,
    notificationMessage = 'Initializing... \n',
}

local replacer = {
    puppetTable = {},
    characterTypes = {},
    defaultPaths = {},
    entityPaths = {},
    defaultTemplate = '',
    defaultEntity = '',
    puppetTorsoRecord = nil,
    puppetTorsoAppearance = nil,
    appearanceLists = {},
}

-- ImGui: Menu Bar --

local showModal = false
local modalName = ''

-- ImGui: Default Appearance Menu --

local radioGroupV = 2
local radioGroupJ = 1
local sameLineIntervals = { [2] = true, [4] = true, [6] = true, [8] = true }
local comboIndexV = 0
local comboIndexJ = 0
local defaultComboValuesV = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local defaultComboValuesJ = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local prevRadioGroupV = radioGroupV
local prevComboIndexV = comboIndexV
local prevRadioGroupJ = radioGroupJ
local prevComboIndexJ = comboIndexJ
local comboStateV = {}
local comboStateJ = {}

-- ImGui: NPV Menu --

local radioGroupNPV = 5
local prevRadioGroupNPV = radioGroupNPV
local sameLineIntervalsNPV = { [5] = true, [9] = true}
local comboIndexNPV = 0
local prevComboIndexNPV = comboIndexNPV
local defaultComboValuesNPV = {0, 0, 0, 0, 0, 0}
local npvCharacterInput = ''
local npvAppearanceInput = ''
local comboStateNPV = {
    [5] = 0,
    [6] = 0,
    [7] = 0,
    [8] = 0,
    [9] = 0,
    [10] = 0,
}
local isWarningChecked = false

-- ImGui: Main Options --

local vSelection = 'Default'
local jSelection = 'Default'

-- Accessors --

---@param message string
function interface.SetNotificationMessage(message)
    interface.notificationMessage = message
end

function interface.SetAppearanceLists(table)
    replacer.appearanceLists = table
end

-- Error Handling --

---@param message string
function interface.NotifyError(message)
    local errorType, errorMessage = message:match('^(.-)( %-.*)$')
    -- Clear initializing notification but retain prior error messages
    if not interface.state.errorOccurred then
        interface.notificationMessage = ''
    end
    interface.notificationMessage = interface.notificationMessage .. errorType .. '\n' .. errorMessage .. '\n'
    interface.statusFeedLines = interface.statusFeedLines + 2
    interface.state.errorOccurred = true
end

local function SaveData()
    local filePath = 'user/settings.lua'
    local file = io.open(filePath, 'w')
    if not file then
        spdlog.info('Error: Unable to open file for writing: ', filePath)
    else
        file:write('local settings = {\n')
        file:write('\tdefaultAppsV = {\n')
        for k, v in pairs(interface.userSettings.defaultAppsV) do
            file:write(string.format('\t\t[%d] = \'%s\',\n', k, v))
        end
        file:write('\t},\n')
        file:write('\tdefaultAppsJ = {\n')
        for k, v in pairs(interface.userSettings.defaultAppsJ) do
            file:write(string.format('\t\t[%d] = \'%s\',\n', k, v))
        end
        file:write('\t},\n')
        file:write('\tcomboStateV = {\n')
        for k, v in pairs(interface.userSettings.comboStateV) do
            file:write(string.format('\t\t[%d] = %d,\n', k, v))
        end
        file:write('\t},\n')
        file:write('\tcomboStateJ = {\n')
        for k, v in pairs(interface.userSettings.comboStateJ) do
            file:write(string.format('\t\t[%d] = %d,\n', k, v))
        end
        file:write('\t},\n')
        file:write('\tdefaultTemplate = {\n')
        local defaultTemplate = replacer.defaultTemplate:gsub('\\', '\\\\')
        file:write(string.format('\t\t\'%s\',\n', defaultTemplate))
        file:write('\t},\n')
        file:write('\tdefaultEntity = {\n')
        local defaultEntity = replacer.defaultEntity:gsub('\\', '\\\\')
        file:write(string.format('\t\t\'%s\',\n', defaultEntity))
        file:write('\t},\n')
        file:write('}\n\nreturn settings')
        file:close()
    end
end

local function SerializeTable(table, indent)
    indent = indent or ''
    local serialized = '{\n'
    for k, v in ipairs(table) do
        if type(v) == 'table' then
            serialized = serialized .. indent .. '    ' .. SerializeTable(v, indent .. '    ') .. ',\n'
        else
            serialized = serialized .. indent .. '    ' .. string.format('%q', v) .. ',\n'
        end
    end
    serialized = serialized .. indent .. '}'
    return serialized
end

function SaveAppearanceNameChange(newAppearanceName, tableIndex, appearanceIndex)
    local filePath = 'external/appearances.lua'
    local appearances = dofile(filePath)

    -- Modify the specific appearance
    if appearances[tableIndex] and appearances[tableIndex][appearanceIndex] then
        appearances[tableIndex][appearanceIndex] = newAppearanceName
    end

    local file = io.open(filePath, 'w')
    if not file then
        spdlog.info('Error: Unable to open file for writing: ', filePath)
    else
        file:write('-- Credit: xBaebsae\n--- For assembling these appearance lists\n\n')
        file:write('local appearances = ' .. SerializeTable(appearances) .. '\n\nreturn appearances')
        file:close()
        interface.state.isAppearancesListUpdated = true
    end
end

-- Initialization --

---@param data table (data.lua)
function interface.Initialize(data)
    -- Pull values from data module
    replacer.characterTypes = data.characterTypes
    replacer.defaultPaths = data.defaultPaths
    replacer.entityPaths = data.entityPaths
    replacer.puppetTorsoRecord = data.puppetTorsoRecord
    replacer.puppetTorsoAppearance = data.puppetTorsoAppearance

    -- Initialize interface settings
    vSelection = replacer.characterTypes[1]
    jSelection = replacer.characterTypes[1]

    -- Setup default user settings
    for i, v in pairs(interface.userSettings.comboStateV) do
        defaultComboValuesV[i] = v
    end

    for i, v in pairs(interface.userSettings.comboStateJ) do
        defaultComboValuesJ[i] = v
    end

    comboIndexV = interface.userSettings.comboStateV[2]
    prevComboIndexV = interface.userSettings.comboStateV[2]
    comboIndexJ = interface.userSettings.comboStateJ[1]
    prevComboIndexJ = interface.userSettings.comboStateJ[1]
end

-- Core Logic --

function interface.SetupDefaultV()
    local gender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
    local index = 1

    if gender == 'Female' then
        index = index + 2
    end

    if IsEP1() then
        index = index + 4
    end

    replacer.defaultTemplate = replacer.defaultPaths[index]
    replacer.defaultEntity = replacer.defaultPaths[index + 1]

    -- Save file paths for troubleshooting non-PL users
    SaveData()
    interface.SetPuppetTable(1, 'V')
end

---@param data table (data.lua)
function interface.PopulatePuppetTable(data)
    -- Populate puppetTable
    for i = 1, 4 do
        table.insert(replacer.puppetTable, {
            characterRecord = data.tweakDBID[i],
            path = data.defaultPaths[9]
        })
    end

    interface.ready = true
end

---@param index integer (1-11)
---@param character string ('V' or 'Johnny')
function interface.SetPuppetTable(index, character)
    if character == 'V' then
        for i, entry in ipairs(replacer.puppetTable) do
            -- If entry is not Johnny
            if i ~= 4 then
                -- If resetting to default V
                if index == 1 then
                    if i == 1 then
                        TweakDB:SetFlat(entry.characterRecord, replacer.defaultTemplate)
                    else
                        TweakDB:SetFlat(entry.characterRecord, replacer.defaultEntity)
                    end
                -- If replacing V
                else
                    TweakDB:SetFlat(entry.characterRecord, replacer.entityPaths[index])
                end
            end
        end
    elseif character == 'Johnny' then
        -- If resetting to Johnny
        if index == 1 then
            TweakDB:SetFlat(replacer.puppetTable[4].characterRecord, replacer.defaultPaths[9])
        -- If replacing Johnny
        else
            TweakDB:SetFlat(replacer.puppetTable[4].characterRecord, replacer.entityPaths[index])
        end
    end

    -- Toggle TPP for player or replacer
    if index == 1 then
        TweakDB:SetFlat(replacer.puppetTorsoRecord, replacer.puppetTorsoAppearance)
    else
        TweakDB:SetFlat(replacer.puppetTorsoRecord, '')
    end
end

function interface.ResetInterface()
    vSelection = 'Default'
    jSelection = 'Default'
    interface.options.vIndex = 1
    interface.options.jIndex = 1
    interface.statusFeedLines = 3
    interface.SetPuppetTable(1, 'Johnny')
end

local function CreateRadioButtons(radioGroup, labels, intervals, startIndex)
    for i = startIndex, math.min(#labels, 10) do
        local label = labels[i]
        radioGroup = ImGui.RadioButton(label, radioGroup, i)
        if intervals and intervals[i] then
            ImGui.SameLine()
        end
    end
    return radioGroup
end

function interface.DrawUI()

    ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, 330, 0)

    if not ImGui.Begin(interface.modName, true, ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.MenuBar) then
        ImGui.End()
        return
    end

    -- Menu Bar

    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu(interface.menuA) then
            if ImGui.MenuItem(interface.menuItemA) then
                showModal = true
                modalName = interface.menuItemA
            end
            if ImGui.MenuItem(interface.menuItemB) then
                showModal = true
                modalName = interface.menuItemB
            end
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end

    -- Menu Modals --

    if showModal then
        ImGui.OpenPopup(modalName)
        showModal = false -- Reset flag
        modalName = ''
    end
    
    if ImGui.BeginPopupModal(interface.menuItemA, true, ImGuiWindowFlags.AlwaysAutoResize) then
        if ImGui.BeginTabBar('##TabBar2') then
            if ImGui.BeginTabItem('V Replacer') then

                radioGroupV = CreateRadioButtons(radioGroupV, replacer.characterTypes, sameLineIntervals, 2)

                if radioGroupV ~= prevRadioGroupV then
                    -- Save the current combo index at the index of the previous radio button
                    comboStateV[prevRadioGroupV] = comboIndexV
                
                    -- Update to the new radio button and restore the previous combo index (or use default)
                    prevRadioGroupV = radioGroupV
                    comboIndexV = comboStateV[radioGroupV] or (defaultComboValuesV[radioGroupV] or 0)
                end

                comboIndexV = ImGui.Combo('##Combo 10', comboIndexV, replacer.appearanceLists[radioGroupV], #replacer.appearanceLists[radioGroupV])

                comboStateV[radioGroupV] = comboIndexV

                if comboIndexV ~= prevComboIndexV then
                    prevComboIndexV = comboIndexV
                end

                if comboIndexV ~= interface.userSettings.comboStateV[radioGroupV] then
                    interface.userSettings.comboStateV[radioGroupV] = comboIndexV
                    interface.userSettings.defaultAppsV[radioGroupV] = replacer.appearanceLists[radioGroupV][comboIndexV + 1]
                    SaveData()
                end
                
                ImGui.EndTabItem()
            end
            
            ImGui.EndTabBar()
        end
        
        if ImGui.BeginTabBar('##TabBar2') then
            if ImGui.BeginTabItem('Johnny Replacer') then

                radioGroupJ = CreateRadioButtons(radioGroupJ, replacer.characterTypes, sameLineIntervals, 1)

                if radioGroupJ ~= prevRadioGroupJ then
                    -- Save the current combo index at the index of the previous radio button
                    comboStateJ[prevRadioGroupJ] = comboIndexV
                
                    -- Update to the new radio button and restore the previous combo index (or use default)
                    prevRadioGroupV = radioGroupV
                    comboIndexJ = comboStateJ[radioGroupV] or (defaultComboValuesJ[radioGroupJ] or 0)
                end

                comboIndexJ = ImGui.Combo('##Combo 11', comboIndexJ, replacer.appearanceLists[radioGroupJ], #replacer.appearanceLists[radioGroupJ])

                comboStateJ[radioGroupJ] = comboIndexJ

                if comboIndexJ ~= prevComboIndexJ then
                    prevComboIndexJ = comboIndexJ
                end

                if comboIndexJ ~= interface.userSettings.comboStateJ[radioGroupJ] then
                    interface.userSettings.comboStateJ[radioGroupJ] = comboIndexJ
                    interface.userSettings.defaultAppsJ[radioGroupJ] = replacer.appearanceLists[radioGroupJ][comboIndexJ + 1]
                    SaveData()
                end

                ImGui.EndTabItem()
            end
            
            ImGui.EndTabBar()
        end
        ImGui.EndPopup()
    end

    if ImGui.BeginPopupModal(interface.menuItemB, true, ImGuiWindowFlags.AlwaysAutoResize) then
        if ImGui.CollapsingHeader("Help") then
            local function StyledText(text)
                local color = {ImGui.GetStyleColorVec4(ImGuiCol.TextDisabled)}
                ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3], color[4])
                ImGui.TextWrapped(text)
                ImGui.PopStyleColor()
            end
        
            ImGui.TextWrapped("This feature is primarily for modders who want custom display names for their NPV appearances")
            ImGui.Separator()
            ImGui.TextWrapped("What this means:")
        
            ImGui.Bullet()
            StyledText("If you have created an NPV Replacer for xBaebsae's Nibbles To NPCs mod, you can set custom appearance names here.")
        
            ImGui.Bullet()
            StyledText("This only affects how the appearanceName is displayed within this mod--it does not change the names within the .ent or .app files.")
        
            ImGui.TextWrapped("In other words:")
        
            ImGui.Bullet()
            StyledText("Rather than seeing something like this:")
            StyledText("         Replacer Character: Appearance")
            StyledText("         Replacer Appearance: 01")
        
            ImGui.Bullet()
            StyledText("You can rename it to be:")
            StyledText("         Replacer Character: Valerie")
            StyledText("         Replacer Appearance: Merc Gear")
        
            ImGui.TextWrapped("Also:")
        
            ImGui.Bullet()
            StyledText("If your NPV file contains multiple different characters, setting different names will also sort them individually into distinct categories for faster browsing.")
        
            ImGui.Separator()
        end

        radioGroupNPV = CreateRadioButtons(radioGroupNPV, replacer.characterTypes, sameLineIntervalsNPV, 5)

        if radioGroupNPV ~= prevRadioGroupNPV then
            -- Save the current combo index at the index of the previous radio button
            comboStateNPV[prevRadioGroupNPV] = comboIndexNPV

            -- Update to the new radio button and restore the previous combo index (or use default)
            prevRadioGroupNPV = radioGroupNPV
            comboIndexNPV = comboStateNPV[radioGroupNPV] or (defaultComboValuesNPV[radioGroupNPV] or 0)
        end

        comboIndexNPV = ImGui.Combo('##Combo12', comboIndexNPV, replacer.appearanceLists[radioGroupNPV], #replacer.appearanceLists[radioGroupNPV])

        comboStateNPV[radioGroupNPV] = comboIndexNPV

        if comboIndexNPV ~= prevComboIndexNPV then
            prevComboIndexNPV = comboIndexNPV
        end

        local changedCharacter = ImGui.InputTextWithHint("Character", "V", npvCharacterInput, 256)
        local changedAppearance = ImGui.InputTextWithHint("Appearance", "Casual", npvAppearanceInput, 256)

        if changedCharacter then
            npvCharacterInput = changedCharacter
        end
        if changedAppearance then
            npvAppearanceInput = changedAppearance
        end
        
        if ImGui.Button("Save Changes", -1, 0) then
            if npvCharacterInput ~= '' and npvAppearanceInput ~= '' then
                if #npvCharacterInput > 35 then
                    npvCharacterInput = npvCharacterInput:sub(1, 35)
                elseif #npvAppearanceInput > 35 then
                    npvAppearanceInput = npvAppearanceInput:sub(1, 35)
                end
                local newAppearance = npvCharacterInput .. '_' .. npvAppearanceInput
                local replacements = {
                    ['\\'] = '\\\\',
                    ["'"] = "\\'",
                    ['"'] = '\\"',
                    ['\n'] = ' ',
                    ['\t'] = ' ',
                }
                replacer.appearanceLists[radioGroupNPV][comboIndexNPV + 1] = string.gsub(newAppearance, "[\\'\"%c]", replacements)
                SaveAppearanceNameChange(newAppearance, radioGroupNPV, comboIndexNPV + 1)
            end
        end

        if interface.state.isPhotoModeActive and not isWarningChecked then
            ImGui.Separator()
            ImGui.TextColored(1, 0.9098039215686274, 0, 1, "Changes are not immediate inside of Photo Mode")
            
            if ImGui.Button("OK", -1, 0) then
                isWarningChecked = true
            end
        end
        
        ImGui.EndPopup()
    end

    -- Pre-load
    if not interface.ready or interface.state.errorOccurred or interface.state.isGameLoadingSaveFile or interface.state.isPhotoModeActive then
        ImGui.TextColored(0.5, 0.5, 0.5, 1, interface.notificationArea)
        interface.notificationMessage = ImGui.InputTextMultiline('##InputTextMultiline', interface.notificationMessage, 330, -1, interface.statusFeedLines * ImGui.GetTextLineHeight())
    -- Post-load
    elseif interface.ready and not interface.state.errorOccurred then
        if ImGui.BeginTabBar('##TabBar') then
            if ImGui.BeginTabItem('V Replacer') then
                ImGui.TextDisabled('Choose a character model:')
                if ImGui.BeginCombo('##Combo1', vSelection) then
                    for index, option in ipairs(replacer.characterTypes) do
                        if ImGui.Selectable(option, (option == vSelection)) then
                            vSelection = option
                            interface.options.vIndex = index
                            interface.SetPuppetTable(index, 'V')
                            ImGui.SetItemDefaultFocus()
                            interface.state.isDefaultAppearance = true
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem('Johnny Replacer') then
                ImGui.TextDisabled('Choose a character model:')
                if ImGui.BeginCombo('##Combo2', jSelection) then
                    for index, option in ipairs(replacer.characterTypes) do
                        if ImGui.Selectable(option, (option == jSelection)) then
                            jSelection = option
                            interface.options.jIndex = index
                            interface.SetPuppetTable(index, 'Johnny')
                            ImGui.SetItemDefaultFocus()
                            interface.state.isDefaultAppearance = true
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