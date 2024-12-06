local interface = {
    ready = false,
    errorOccurred = false,
    modName = 'Photo Mode Player Replacer',
    menuA = 'Menu',
    menuItemA = 'Set Default Appearances',
    notificationArea = 'Status Feed',
    statusFeedLines = 3,
    notificationMessage = 'Initializing... \n',
}

local user = {
    isLoadingSaveFile = false,
    isInPhotoMode = false,
    settings = require('user/settings.lua'),
}

local replacer = {
    vEntity = 1,
    jEntity = 1,
    isDefaultAppearance = false,
    data = {
        puppetTable = {},
        characterTypes = {},
        defaultPaths = {},
        entityPaths = {},
        defaultTemplate = nil,
        defaultEntity = nil,
        puppetTorsoRecord = nil,
        puppetTorsoAppearance = nil,
        appearanceLists = {}
    }
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
local prevRadioGroupV = radioGroupV or 0
local prevComboIndexV = comboIndexV or 0
local prevRadioGroupJ = radioGroupJ or 0
local prevComboIndexJ = comboIndexJ or 0
local comboStateV = {}
local comboStateJ = {}

-- ImGui: Main Options --

local vSelection = 'Default'
local jSelection = 'Default'

-- Accessors --

---@param message string
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

function interface.SetAppearanceLists(table)
    replacer.data.appearanceLists = table
end

function interface.GetVEntity()
    return replacer.vEntity
end

function interface.GetJEntity()
    return replacer.jEntity
end

function interface.IsDefaultAppearance()
    return replacer.isDefaultAppearance
end

function interface.ToggleDefaultAppearance(bool)
    replacer.isDefaultAppearance = bool
end

-- Error Handling --

---@param message string
function interface.NotifyError(message)
    local errorType, errorMessage = message:match('^(.-)( %-.*)$')
    -- Clear initializing notification but retain prior error messages
    if not interface.errorOccurred then
        interface.notificationMessage = ''
    end
    interface.notificationMessage = interface.notificationMessage .. errorType .. '\n' .. errorMessage .. '\n'
    interface.statusFeedLines = interface.statusFeedLines + 2
    interface.errorOccurred = true
end

-- Initialization --

---@param data table (data.lua)
function interface.Initialize(data)
    -- Pull values from data module
    replacer.data.characterTypes = data.characterTypes
    replacer.data.defaultPaths = data.defaultPaths
    replacer.data.entityPaths = data.entityPaths
    replacer.data.puppetTorsoRecord = data.puppetTorsoRecord
    replacer.data.puppetTorsoAppearance = data.puppetTorsoAppearance

    -- Initialize interface settings
    vSelection = replacer.data.characterTypes[1]
    jSelection = replacer.data.characterTypes[1]

    -- Setup default user settings
    for i, v in pairs(user.settings.comboStateV) do
        defaultComboValuesV[i] = v
    end

    for i, v in pairs(user.settings.comboStateJ) do
        defaultComboValuesJ[i] = v
    end
    comboIndexV = user.settings.comboStateV[2]
    prevComboIndexV = user.settings.comboStateV[2]
    comboIndexJ = user.settings.comboStateV[2]
    prevComboIndexJ = user.settings.comboStateV[2]
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

    replacer.data.defaultTemplate = replacer.data.defaultPaths[index]
    replacer.data.defaultEntity = replacer.data.defaultPaths[index + 1]

    interface.SetPuppetTable(1, 'V')
end

---@param data table (data.lua)
function interface.PopulatePuppetTable(data)
    -- Populate puppetTable
    for i = 1, 4 do
        table.insert(replacer.data.puppetTable, {
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
        for i, entry in ipairs(replacer.data.puppetTable) do
            -- If entry is not Johnny
            if i ~= 4 then
                -- If resetting to default V
                if index == 1 then
                    if i == 1 then
                        TweakDB:SetFlat(entry.characterRecord, replacer.data.defaultTemplate)
                    else
                        TweakDB:SetFlat(entry.characterRecord, replacer.data.defaultEntity)
                    end
                -- If replacing V
                else
                    TweakDB:SetFlat(entry.characterRecord, replacer.data.entityPaths[index])
                end
            end
        end
    elseif character == 'Johnny' then
        -- If resetting to Johnny
        if index == 1 then
            TweakDB:SetFlat(replacer.data.puppetTable[4].characterRecord, replacer.data.defaultPaths[9])
        -- If replacing Johnny
        else
            TweakDB:SetFlat(replacer.data.puppetTable[4].characterRecord, replacer.data.entityPaths[index])
        end
    end

    -- Toggle TPP for player or replacer
    if index == 1 then
        TweakDB:SetFlat(replacer.data.puppetTorsoRecord, replacer.data.puppetTorsoAppearance)
    else
        TweakDB:SetFlat(replacer.data.puppetTorsoRecord, '')
    end
end

function interface.ResetInterface()
    vSelection = 'Default'
    jSelection = 'Default'
    replacer.vEntity = 1
    replacer.jEntity = 1
    interface.statusFeedLines = 3
    interface.SetPuppetTable(1, 'Johnny')
end

local function CreateRadioButtons(radioGroup, labels, intervals, omitDefault)
    local startIndex = omitDefault and 2 or 1  -- Start from the second label if omitDefault is true
    for i = startIndex, math.min(#labels, 10) do
        local label = labels[i]
        radioGroup = ImGui.RadioButton(label, radioGroup, i)
        if intervals and intervals[i] then
            ImGui.SameLine()
        end
    end
    return radioGroup
end

local function SaveData()
    local file = io.open('user/settings.lua', 'w')
    if file then
        file:write('local settings = {\n')
        file:write('\tdefaultAppsV = {\n')
        for k, v in pairs(user.settings.defaultAppsV) do
            file:write(string.format('\t\t[%d] = \'%s\',\n', k, v))
        end
        file:write('\t},\n')
        file:write('\tdefaultAppsJ = {\n')
        for k, v in pairs(user.settings.defaultAppsJ) do
            file:write(string.format('\t\t[%d] = \'%s\',\n', k, v))
        end
        file:write('\t},\n')
        file:write('\tcomboStateV = {\n')
        for k, v in pairs(user.settings.comboStateV) do
            file:write(string.format('\t\t[%d] = %d,\n', k, v))
        end
        file:write('\t},\n')
        file:write('\tcomboStateJ = {\n')
        for k, v in pairs(user.settings.comboStateJ) do
            file:write(string.format('\t\t[%d] = %d,\n', k, v))
        end
        file:write('\t},\n')
        file:write('}\n\nreturn settings')
        file:close()
    else
        spdlog.info('Error: Unable to open file for writing: ', 'user/settings.lua')
    end

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

                radioGroupV = CreateRadioButtons(radioGroupV, replacer.data.characterTypes, sameLineIntervals, true)

                if radioGroupV ~= prevRadioGroupV then
                    -- Save the current combo index at the index of the previous radio button
                    comboStateV[prevRadioGroupV] = comboIndexV
                
                    -- Update to the new radio button and restore the previous combo index (or use default)
                    prevRadioGroupV = radioGroupV
                    comboIndexV = comboStateV[radioGroupV] or (defaultComboValuesV[radioGroupV] or 0)
                end

                comboIndexV = ImGui.Combo('##Combo 10', comboIndexV, replacer.data.appearanceLists[radioGroupV], #replacer.data.appearanceLists[radioGroupV])

                comboStateV[radioGroupV] = comboIndexV

                if comboIndexV ~= prevComboIndexV then
                    prevComboIndexV = comboIndexV
                end

                if comboIndexV ~= user.settings.comboStateV[radioGroupV] then
                    user.settings.comboStateV[radioGroupV] = comboIndexV
                    user.settings.defaultAppsV[radioGroupV] = replacer.data.appearanceLists[radioGroupV][comboIndexV + 1]
                    SaveData()
                end
                
                ImGui.EndTabItem()
            end
            
            ImGui.EndTabBar()
        end
        
        if ImGui.BeginTabBar('##TabBar2') then
            if ImGui.BeginTabItem('Johnny Replacer') then

                radioGroupJ = CreateRadioButtons(radioGroupJ, replacer.data.characterTypes, sameLineIntervals, false)

                if radioGroupJ ~= prevRadioGroupJ then
                    -- Save the current combo index at the index of the previous radio button
                    comboStateJ[prevRadioGroupJ] = comboIndexV
                
                    -- Update to the new radio button and restore the previous combo index (or use default)
                    prevRadioGroupV = radioGroupV
                    comboIndexJ = comboStateJ[radioGroupV] or (defaultComboValuesJ[radioGroupJ] or 0)
                end

                comboIndexJ = ImGui.Combo('##Combo 11', comboIndexJ, replacer.data.appearanceLists[radioGroupJ], #replacer.data.appearanceLists[radioGroupJ])

                comboStateJ[radioGroupJ] = comboIndexJ

                if comboIndexJ ~= prevComboIndexJ then
                    prevComboIndexJ = comboIndexJ
                end

                if comboIndexJ ~= user.settings.comboStateJ[radioGroupJ] then
                    user.settings.comboStateJ[radioGroupJ] = comboIndexJ
                    user.settings.defaultAppsJ[radioGroupJ] = replacer.data.appearanceLists[radioGroupJ][comboIndexJ + 1]
                    SaveData()
                end

                ImGui.EndTabItem()
            end
            
            ImGui.EndTabBar()
        end
        ImGui.EndPopup()
    end

    -- Pre-load
    if not interface.ready or interface.errorOccurred or user.isLoadingSaveFile or user.isInPhotoMode then
        ImGui.TextColored(0.5, 0.5, 0.5, 1, interface.notificationArea)
        interface.notificationMessage = ImGui.InputTextMultiline('##InputTextMultiline', interface.notificationMessage, 330, -1, interface.statusFeedLines * ImGui.GetTextLineHeight())
    -- Post-load
    elseif interface.ready and not interface.errorOccurred then
        if ImGui.BeginTabBar('##TabBar') then
            if ImGui.BeginTabItem('V Replacer') then
                ImGui.TextDisabled('Choose a character model:')
                if ImGui.BeginCombo('##Combo1', vSelection) then
                    for index, option in ipairs(replacer.data.characterTypes) do
                        if ImGui.Selectable(option, (option == vSelection)) then
                            vSelection = option
                            replacer.vEntity = index
                            interface.SetPuppetTable(index, 'V')
                            ImGui.SetItemDefaultFocus()
                            replacer.isDefaultAppearance = true
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem('Johnny Replacer') then
                ImGui.TextDisabled('Choose a character model:')
                if ImGui.BeginCombo('##Combo2', jSelection) then
                    for index, option in ipairs(replacer.data.characterTypes) do
                        if ImGui.Selectable(option, (option == jSelection)) then
                            jSelection = option
                            replacer.jEntity = index
                            interface.SetPuppetTable(index, 'Johnny')
                            ImGui.SetItemDefaultFocus()
                            replacer.isDefaultAppearance = true
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