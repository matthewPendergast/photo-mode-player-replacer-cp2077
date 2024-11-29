local util = {
    vDefaultAppearances = {},
    jDefaultAppearances = {}
}

---@param entity userData
---@param appearance string (valid appearanceName)
function util.ChangeAppearance(entity, appearance)
    if appearance ~= nil and appearance ~= '-' then
        entity:PrefetchAppearanceChange(appearance)
        entity:ScheduleAppearanceChange(appearance)
    end
end

---@param entity userData
function util.GetID(entity)
    if type(entity) ~= 'userdata' then
        return nil
    else
        local success, ID = pcall(function()
            return entity:GetRecordID()
        end)
        if not success then
            return nil
        else
            local hash = tostring(ID):match('hash%s*=%s*(%g+),') or ''
            local length = tostring(ID):match('length%s*=%s*(%d+)') or 0
            return hash .. ', ' .. length
        end
    end
end

---@param searchID string
function util.LocatePlayerPuppet(searchID)
    local player = Game.GetPlayer()
    local tsq = TSQ_ALL()
    local success, parts = Game.GetTargetingSystem():GetTargetParts(player, tsq)
    if success then
        for _, part in ipairs(parts) do
            local entity = part:GetComponent(part):GetEntity()
            if entity then
                local ID = util.GetID(entity)
                if ID == searchID then
                    return entity
                end
            end
        end
    end
end

return util