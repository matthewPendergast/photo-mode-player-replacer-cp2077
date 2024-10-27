local config = require('config')

vReplacer = {
    ready = false,
    playerGender = nil
}

function setupReplacer()
    defaultLocalizedNames = TweakDB:GetFlat(localizedNames)
    AMM = GetMod('AppearanceMenuMod')
    --idList = AMM.Util.possibleIDs --not correct

    if AMM ~= nil then
        -- To Do: access and modify AMM.Util possibleIDs variable
    end

    TweakDB:SetFlat(localizedNames, {newLocalizedName, defaultLocalizedNames[2], defaultLocalizedNames[3]})

    for i, entry in ipairs(config.entityPaths) do
        TweakDB:SetFlat(entry.replacerEntity, entry.entityPath)
    end

    -- To Do: ImGui options for entity swapping / AMM patch and pull request

end

registerForEvent('onInit', function()
    vReplacer.ready = true
end)

registerForEvent('onTweak', setupReplacer)

registerForEvent('onUpdate', function()
    -- To Do: implement better than onUpdate, implement check for reload of saves
    if vReplacer.playerGender == nil then
        vReplacer.playerGender = Game.GetPlayer():GetResolvedGenderName()
        -- To Do: parse return value for "Male" or "Female" ^^
        if vReplacer.playerGender ~= nil then
            print(vReplacer.playerGender)
        end
    end
end)

return vReplacer