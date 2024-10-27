local config = require('config')

vReplacer = {
    ready = false,
    playerGender = nil
}

function setupReplacer()
    local defaultLocalizedNames = TweakDB:GetFlat(localizedNames)
    local AMM = GetMod('AppearanceMenuMod')

    if AMM ~= nil then
        --[[ To Do:
            * access and modify AMM.Util.possibleIDs to exclude "0x9EDC71E0, 33" when this mod is installed
                - Access to AMM seems to be limited to init.lua; doesn't seem to be a way to access AMM Modules (Util needed)
            * AMM also populates appearances list for V entity_id = "0x9EDC71E0, 33" using photomode_npc_npv_fem1|2.ent
                - Not sure if this is intended
                - Complicates generating different appearances lists for male V or NPC replacer entities
                - Might not be able to fix outside of AMM
        ]]
    end

    for i, entry in ipairs(config.puppetTable) do
        TweakDB:SetFlat(entry.characterRecord, entry.path)
    end

    TweakDB:SetFlat(localizedNames, {newLocalizedName, defaultLocalizedNames[2], defaultLocalizedNames[3]})

    --[[ To Do:
        * ImGui options for entity swapping / AMM patch and pull request
        * Call updatePlayerGender() on save load
    ]] 

end

function updatePlayerGender()
    vReplacer.playerGender = string.gmatch(tostring(Game.GetPlayer():GetResolvedGenderName()), '%-%-%[%[%s*(%a+)%s*%-%-%]%]')()
end

registerForEvent('onTweak', setupReplacer)

registerForEvent('onInit', function()
    vReplacer.ready = true
end)

return vReplacer