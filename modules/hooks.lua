local hooks = {}

local menuController = {
    initialized = false,
    menuPage = {
        pose = 2,
    },
    menuItem = {
        characterAttribute = 38,
        characterVisibleAttribute = 27,
        replacerAttribute = 9000,
        replacerAppearanceAttribute = 9001,
        replacerLabel = 'REPLACER CHARACTER',
        appearanceLabel = 'REPLACER APPEARANCE',
    },
    data = {
        currHeaderIndex = nil,
        currAppIndex = nil,
        currHeaderCount = nil,
        currAppCount = nil,
        currHeader = nil,
        currParsedApp = nil,
        currUnparsedApp = nil,
    },
    locName = {
        v = nil,
        johnny = nil,
        nibbles = nil,
    },
    list = {
        parsedApps = {},
        unparsedApps = {},
    },
}

local isPhotoModeActive = false
local parsedTable = {}
local appearanceTable = {}
local currEntity = {
    v = 1,
    j = 1,
}

function hooks.SetParsedTable(table)
    parsedTable = table
end

---@param newV string
---@param newJ string
---@param newN string
function hooks.SetLocNames(newV, newJ, newN)
    menuController.locName.v = newV
    menuController.locName.johnny = newJ
    menuController.locName.nibbles = newN
end

function SetCurrEntity(vIndex, jIndex)
    currEntity.v = vIndex
    currEntity.j = jIndex
end

---@param this gameuiPhotoModeMenuController
local function SetupMenuControllerItems(this)
    menuController.characterMenuItem = this:GetMenuItem(menuController.menuItem.characterAttribute)
    menuController.headerMenuItem = this:GetMenuItem(menuController.menuItem.replacerAttribute)
    menuController.appearanceMenuItem = this:GetMenuItem(menuController.menuItem.replacerAppearanceAttribute)
    menuController.visibleMenuItem = this:GetMenuItem(menuController.menuItem.characterVisibleAttribute)
end

---@param character string
---@param headerMenuItem PhotoModeMenuListItem
---@param appearanceMenuItem PhotoModeMenuListItem
local function RestrictAppearanceMenuItems(character, headerMenuItem, appearanceMenuItem)
    -- If Nibbles is selected, disable menu items
    if character == menuController.locName.nibbles then
        headerMenuItem.OptionLabelRef:SetText('-')
        headerMenuItem.OptionSelector.index = 0
        appearanceMenuItem.OptionLabelRef:SetText('-')
        appearanceMenuItem.OptionSelector.index = 0
    -- If default Johnny is selected
    elseif character == menuController.locName.johnny and currEntity.j == 1 then
        appearanceMenuItem.OptionLabelRef:SetText(menuController.data.currParsedApp)
        appearanceMenuItem.OptionSelector.index = menuController.data.currAppIndex + 1
    else
        headerMenuItem.OptionLabelRef:SetText(menuController.data.currHeader)
        headerMenuItem.OptionSelector.index = menuController.data.currHeaderIndex - 1
        appearanceMenuItem.OptionLabelRef:SetText(menuController.data.currParsedApp)
        appearanceMenuItem.OptionSelector.index = menuController.data.currAppIndex
    end
end

---@param headerIndex integer|nil
---@param appIndex integer|nil
---@param headerMenuItem PhotoModeMenuListItem|nil
---@param appearanceMenuItem PhotoModeMenuListItem|nil
local function UpdateMenuControllerData(headerIndex, appIndex, headerMenuItem, appearanceMenuItem)
    -- Will use current values if not being updated
    menuController.character = menuController.characterMenuItem.OptionLabelRef:GetText()
    menuController.visibleMenuIndex = menuController.visibleMenuItem.OptionSelector.index
    menuController.data.currHeaderIndex = headerIndex or menuController.data.currHeaderIndex
    menuController.data.currAppIndex = appIndex or menuController.data.currAppIndex
    menuController.data.currHeaderCount = headerMenuItem and headerMenuItem.OptionSelector:GetValuesCount() or menuController.data.currHeaderCount
    menuController.data.currAppCount = appearanceMenuItem and appearanceMenuItem.OptionSelector:GetValuesCount() or menuController.data.currAppCount
    menuController.data.currHeader = headerIndex and appearanceTable.headers[headerIndex] or menuController.data.currHeader
    menuController.data.currParsedApp = appIndex and menuController.list.parsedApps[appIndex] or menuController.data.currParsedApp
    menuController.data.currUnparsedApp = appIndex and menuController.list.unparsedApps[appIndex] or menuController.data.currUnparsedApp
end

local function ResetMenuControllerData()
    for key in pairs(menuController.data) do
        menuController.data[key] = nil
    end
    menuController.character = nil
    menuController.headerMenuItem = nil
    menuController.appearanceMenuItem = nil
    menuController.visibleMenuItem = nil
    menuController.visibleMenuIndex = nil
    menuController.list.parsedApps = {}
    menuController.list.unparsedApps = {}
    menuController.initialized = false
end

---@param PMPR table
function hooks.SetupObservers(PMPR)
    Override("PhotoModeSystem", "IsPhotoModeActive", function(this, wrappedMethod)
        -- Prevent multiple callbacks on Override
        if isPhotoModeActive ~= wrappedMethod() then
            isPhotoModeActive = wrappedMethod()
            PMPR.modules.interface.ToggleInPhotoMode(wrappedMethod())
            if isPhotoModeActive then
                PMPR.modules.interface.SetNotificationMessage('Unavailable within Photo Mode \n')
            end
            -- Resets the condition for updating default appearance if user doesn't change replacers before reopening photo mode
            if not isPhotoModeActive and not PMPR.IsDefaultAppearance() then
                PMPR.ToggleDefaultAppearance(true)
            end
        end
        -- Presently needs the extra callbacks to work as intended
        if isPhotoModeActive and PMPR.IsDefaultAppearance() then
            local character, entity = PMPR.LocatePlayerPuppet()
            if character and entity then
                PMPR.SetDefaultAppearance(character, entity)
            end
        end
        if not isPhotoModeActive and menuController.initialized then
            ResetMenuControllerData()
        end
    end)

    Override("gameuiPhotoModeMenuController", "AddMenuItem", function(this, label, attributeKey, page, isAdditional, wrappedMethod)
        wrappedMethod(label, attributeKey, page, isAdditional)
        if page == menuController.menuPage.pose and attributeKey == menuController.menuItem.characterVisibleAttribute then
            this:AddMenuItem(menuController.menuItem.replacerLabel, menuController.menuItem.replacerAttribute, page, false)
            this:AddMenuItem(menuController.menuItem.appearanceLabel, menuController.menuItem.replacerAppearanceAttribute, page, false)
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnShow", function(this, reversedUI)
        local headerMenuItem = this:GetMenuItem(menuController.menuItem.replacerAttribute)
        local appearanceMenuItem = this:GetMenuItem(menuController.menuItem.replacerAppearanceAttribute)
        local charactermenuItem = this:GetMenuItem(menuController.menuItem.characterAttribute)
        local character = charactermenuItem.OptionLabelRef:GetText()
        local headerIndex = 0
        local appIndex = 0
        local defaultAppearance, entIndex

        -- Update user settings
        SetCurrEntity(PMPR.GetVEntity(), PMPR.GetJEntity())

        -- Initialize menu item values
        headerMenuItem.GridRoot:SetVisible(false)
        headerMenuItem.ScrollBarRef:SetVisible(false)
        headerMenuItem.OptionSelector:Clear()
        headerMenuItem.photoModeController = this
        appearanceMenuItem.GridRoot:SetVisible(false)
        appearanceMenuItem.ScrollBarRef:SetVisible(false)
        appearanceMenuItem.OptionSelector:Clear()
        appearanceMenuItem.photoModeController = this

        -- Get base character (V or Johnny) based on the 'Character' menu name and get parsed table
        if character == menuController.locName.v then
            entIndex = currEntity.v
            if entIndex == 1 then
                appearanceTable = {headers = {'-'}, data = {['-'] = {{parsed = '-', unparsed = '-'}}}}
                headerIndex = 1
                appIndex = 1
            else
                defaultAppearance = PMPR.modules.properties.defAppsV[currEntity.v].appearanceName
            end
        elseif character == menuController.locName.johnny then
            entIndex = currEntity.j
            -- Set to Johnny's appearances list if Default option selected
            if entIndex == 1 then
                entIndex = 11
                headerIndex = 11
            end
            defaultAppearance = PMPR.modules.properties.defAppsJ[currEntity.j].appearanceName
        end
        
        -- Populate appearance table for selected entity if not default photo mode V
        if entIndex ~= 1 then
            appearanceTable = parsedTable[entIndex]
        end

        -- Update UI for default appearance settings if not default photo mode V
        if defaultAppearance then
            local found = false
            -- Search for replacer being set
            for h, replacer in ipairs(appearanceTable.headers) do
                if found then break end
                -- Search for matching appearance
                for a, appearanceData in ipairs(appearanceTable.data[replacer]) do
                    if appearanceData.unparsed == defaultAppearance then
                        -- Return indexes of replacer and appearance
                        headerIndex = h
                        appIndex = a
                        found = true
                        break
                    end
                end
            end
        end

        -- Populate appearance data
        for _, appearanceData in ipairs(appearanceTable.data[appearanceTable.headers[headerIndex]]) do
            table.insert(menuController.list.parsedApps, appearanceData.parsed)
            table.insert(menuController.list.unparsedApps, appearanceData.unparsed)
        end

        -- Setup header menu item
        headerMenuItem.OptionSelector.index = headerIndex - 1
        headerMenuItem.OptionLabelRef:SetText(appearanceTable.headers[headerIndex])
        headerMenuItem.OptionSelector.values = appearanceTable.headers

        -- Setup appearance menu item
        appearanceMenuItem.OptionSelector.index = appIndex - 1
        appearanceMenuItem.OptionLabelRef:SetText(menuController.list.parsedApps[appIndex])
        appearanceMenuItem.OptionSelector.values = menuController.list.parsedApps

        SetupMenuControllerItems(this)
        UpdateMenuControllerData(headerIndex, appIndex, headerMenuItem, appearanceMenuItem)
        menuController.initialized = true
    end)

    Observe("gameuiPhotoModeMenuController", "OnAttributeUpdated", function(this, attributeKey, attributeValue, doApply)
        if  menuController.initialized then

            -- If character attribute is updated
            if attributeKey == menuController.menuItem.characterAttribute then
                UpdateMenuControllerData()
                RestrictAppearanceMenuItems(menuController.character, menuController.headerMenuItem, menuController.appearanceMenuItem)
            end

            -- If header attribute is updated
            if attributeKey == menuController.menuItem.replacerAttribute then
                UpdateMenuControllerData()

                -- Prevent header options from changing in Nibbles options, when 'Character Visible' is set to 'Off' for V/Johnny, or when there is only one header value
                if menuController.character == menuController.locName.nibbles or menuController.visibleMenuIndex == 0 or menuController.data.currHeaderCount == 1 then
                    RestrictAppearanceMenuItems(menuController.character, menuController.headerMenuItem, menuController.appearanceMenuItem)
                else
                    local headerIndex = menuController.headerMenuItem.OptionSelector.index + 1
                    local unused, entity = PMPR.LocatePlayerPuppet()
                    -- Clear appearance data
                    menuController.list.parsedApps = {}
                    menuController.list.unparsedApps = {}

                    -- Repopulate appearance data
                    for _, appearanceData in ipairs(appearanceTable.data[appearanceTable.headers[headerIndex]]) do
                        table.insert(menuController.list.parsedApps, appearanceData.parsed)
                        table.insert(menuController.list.unparsedApps, appearanceData.unparsed)
                    end

                    -- Update appearance menu item
                    menuController.appearanceMenuItem.OptionSelector.values = menuController.list.parsedApps
                    menuController.appearanceMenuItem.OptionSelector.index = 0
                    menuController.appearanceMenuItem.OptionLabelRef:SetText(menuController.list.parsedApps[1])

                    UpdateMenuControllerData((headerIndex), 1, menuController.headerMenuItem, menuController.appearanceMenuItem)
                    PMPR.ChangeAppearance(entity, menuController.data.currUnparsedApp)
                end
            end

            -- If appearance attribute is updated
            if attributeKey == menuController.menuItem.replacerAppearanceAttribute then
                UpdateMenuControllerData()

                -- Prevent appearance options from changing in Nibbles options, when 'Character Visible' is set to 'Off' for V/Johnny, or when there is only one header value
                if menuController.character == menuController.locName.nibbles or menuController.visibleMenuIndex == 0 or menuController.data.currAppCount == 1 then
                    RestrictAppearanceMenuItems(menuController.character, menuController.headerMenuItem, menuController.appearanceMenuItem)
                else
                    local unused, entity = PMPR.LocatePlayerPuppet()
                    UpdateMenuControllerData(nil, menuController.appearanceMenuItem.OptionSelector.index + 1, nil, menuController.appearanceMenuItem)
                    PMPR.ChangeAppearance(entity, menuController.data.currUnparsedApp)
                end
            end
        end
    end)
end

return hooks