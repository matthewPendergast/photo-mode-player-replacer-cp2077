local util = {}

---@param searchID string
function util.LocatePlayerPuppet(searchID)
    local player = Game.GetPlayer()
    local tsq = TSQ_ALL()
    local validTarget, parts = Game.GetTargetingSystem():GetTargetParts(player, tsq)
    if validTarget then
        for _, part in ipairs(parts) do
            local entity = part:GetComponent(part):GetEntity()
            if entity then
                local validID, ID = pcall(function()
                    return entity:GetRecordID()
                end)
                if validID then
                    if tostring(ID) == searchID then
                        return entity
                    end
                end
            end
        end
    end
end

---@param entity userData
---@param appearance string (valid appearanceName)
function util.ChangeAppearance(entity, appearance)
    if appearance ~= nil and appearance ~= '-' then
        entity:PrefetchAppearanceChange(appearance)
        entity:ScheduleAppearanceChange(appearance)
    end
end

return util