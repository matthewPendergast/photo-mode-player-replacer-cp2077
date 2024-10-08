config = require('config')

vReplacer = {
    ready = false
}

function setupReplacer()
    defaultLocNames = TweakDB:GetFlat(config.locNames)

    TweakDB:SetFlat(config.replacerEntity1, config.entityPath1)
    TweakDB:SetFlat(config.replacerEntity2, config.entityPath2)
    TweakDB:SetFlat(config.replacerEntity3, config.entityPath3)
    TweakDB:SetFlat(config.locNames, {config.newLocName, defaultLocNames[2], defaultLocNames[3]})
end

registerForEvent('onInit', function()
    vReplacer.ready = true
end)

registerForEvent('onTweak', setupReplacer)

return vReplacer