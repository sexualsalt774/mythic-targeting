local function exportHandler(exportName, func)
    AddEventHandler(('__cfx_export_ox_target_%s'):format(exportName), function(setCB)
        setCB(func)
    end)
end

-- Converts ox_target option fields to mythic-targeting menu item fields.
-- ox:  label, icon, distance, onSelect, event, serverEvent, command, groups, items, canInteract
-- mythic: text, icon, minDist, event, jobPerms, item/items, isEnabled
local function convertOptions(options, distance)
    if type(options) ~= 'table' then return {} end

    if options.label then
        options = { options }
    end

    local menu = {}

    for _, opt in ipairs(options) do
        local item = {
            text    = opt.label or opt.name or 'Interact',
            icon    = opt.icon,
            minDist = opt.distance or distance or 3.0,
        }

        -- item checks
        if type(opt.items) == 'string' then
            item.item = opt.items
        elseif type(opt.items) == 'table' then
            item.items = opt.items
        end

        -- job/gang group restrictions
        if opt.groups then
            local perms = {}
            if type(opt.groups) == 'string' then
                table.insert(perms, { job = opt.groups })
            elseif type(opt.groups) == 'table' then
                for k, v in pairs(opt.groups) do
                    if type(k) == 'number' then
                        -- array of job name strings
                        table.insert(perms, { job = v })
                    else
                        -- hash: job = minGrade
                        table.insert(perms, { job = k, gradeLevel = v })
                    end
                end
            end
            if #perms > 0 then item.jobPerms = perms end
        end

        -- canInteract -> isEnabled
        -- ox signature: canInteract(entity, distance, endCoords, name, bone)
        -- mythic signature: isEnabled(data, entityData)  where entityData has .entity and .endCoords
        if type(opt.canInteract) == 'function' then
            local fn = opt.canInteract
            item.isEnabled = function(data, entityData)
                local dist = entityData and entityData.endCoords and
                    #(entityData.endCoords - GetEntityCoords(LocalPlayer.state.ped)) or 999.0
                return fn(
                    entityData and entityData.entity,
                    dist,
                    entityData and entityData.endCoords,
                    opt.name
                )
            end
        end

        -- action callbacks - mythic fires TriggerEvent(item.event, hittingTargetData, data)
        if type(opt.onSelect) == 'function' then
            local evtName = ('ox_bridge:sel:%s_%d'):format(GetCurrentResourceName(), math.random(1, 2^30))
            local fn = opt.onSelect
            item.event = evtName
            AddEventHandler(evtName, function(entityData)
                local dist = entityData and entityData.endCoords and
                    #(entityData.endCoords - GetEntityCoords(LocalPlayer.state.ped)) or 0.0
                fn(entityData and entityData.entity, dist)
            end)
        elseif type(opt.serverEvent) == 'string' then
            local evtName = ('ox_bridge:srv:%s_%d'):format(GetCurrentResourceName(), math.random(1, 2^30))
            local srvEvt = opt.serverEvent
            local srvArgs = opt.serverEventArgs
            item.event = evtName
            AddEventHandler(evtName, function()
                TriggerServerEvent(srvEvt, srvArgs or {})
            end)
        elseif type(opt.event) == 'string' then
            item.event = opt.event
        elseif type(opt.command) == 'string' then
            local evtName = ('ox_bridge:cmd:%s_%d'):format(GetCurrentResourceName(), math.random(1, 2^30))
            local cmd = opt.command
            item.event = evtName
            AddEventHandler(evtName, function()
                ExecuteCommand(cmd)
            end)
        end

        table.insert(menu, item)
    end

    return menu
end

-- Zone id tracking: ox_target returns numeric ids from zone calls.
-- We store a mapping from that numeric id back to the zone name string mythic uses.
local zoneCounter = 0
local zoneIdMap   = {}

local function registerZone(name)
    zoneCounter = zoneCounter + 1
    zoneIdMap[zoneCounter] = name
    return zoneCounter
end

local function resolveZoneId(id)
    if type(id) == 'string' then return id end
    return zoneIdMap[id]
end

-- Zones -----------------------------------------------------------------------

exportHandler('addBoxZone', function(data)
    local size = data.size or vec3(1, 1, 1)
    local name = data.name or ('ox_box_%d'):format(zoneCounter + 1)
    TARGETING.Zones:AddBox(
        name,
        data.icon,
        data.coords,
        size.y,
        size.x,
        { heading = data.rotation or 0.0, debug = data.debug },
        convertOptions(data.options, data.distance),
        data.distance or 3.0,
        true
    )
    return registerZone(name)
end)

exportHandler('addSphereZone', function(data)
    local name = data.name or ('ox_sphere_%d'):format(zoneCounter + 1)
    TARGETING.Zones:AddCircle(
        name,
        data.icon,
        data.coords,
        data.radius or 1.0,
        { debug = data.debug },
        convertOptions(data.options, data.distance),
        data.distance or 3.0,
        true
    )
    return registerZone(name)
end)

exportHandler('addPolyZone', function(data)
    local name = data.name or ('ox_poly_%d'):format(zoneCounter + 1)
    TARGETING.Zones:AddPoly(
        name,
        data.icon,
        data.points,
        { debug = data.debug, thickness = data.thickness },
        convertOptions(data.options, data.distance),
        data.distance or 3.0,
        true
    )
    return registerZone(name)
end)

exportHandler('zoneExists', function(id)
    local name = resolveZoneId(id)
    if not name then return false end
    return InteractionZones[name] ~= nil
end)

exportHandler('removeZone', function(id)
    local name = resolveZoneId(id)
    if not name then return end
    TARGETING.Zones:RemoveZone(name)
    if type(id) == 'number' then zoneIdMap[id] = nil end
end)

-- Models ----------------------------------------------------------------------

exportHandler('addModel', function(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local menu = convertOptions(options)
    for _, model in ipairs(arr) do
        local hash = type(model) == 'string' and GetHashKey(model) or model
        TARGETING:AddObject(hash, nil, menu)
    end
end)

exportHandler('removeModel', function(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    for _, model in ipairs(arr) do
        local hash = type(model) == 'string' and GetHashKey(model) or model
        TARGETING:RemoveObject(hash)
    end
end)

-- Networked entities (by network id) ------------------------------------------

exportHandler('addEntity', function(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local menu = convertOptions(options)
    for _, netId in ipairs(arr) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            TARGETING:AddEntity(entity, nil, menu)
        end
    end
end)

exportHandler('removeEntity', function(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    for _, netId in ipairs(arr) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            TARGETING:RemoveEntity(entity)
        end
    end
end)

-- Local entities (by entity handle) -------------------------------------------

exportHandler('addLocalEntity', function(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    local menu = convertOptions(options)
    for _, entity in ipairs(arr) do
        if DoesEntityExist(entity) then
            TARGETING:AddEntity(entity, nil, menu)
        end
    end
end)

exportHandler('removeLocalEntity', function(arr, options)
    if type(arr) ~= 'table' then arr = { arr } end
    for _, entity in ipairs(arr) do
        if DoesEntityExist(entity) then
            TARGETING:RemoveEntity(entity)
        end
    end
end)

-- Global ped ------------------------------------------------------------------

exportHandler('addGlobalPed', function(options)
    TARGETING:AddGlobalPed(convertOptions(options))
end)

exportHandler('removeGlobalPed', function(options)
    -- mythic RemoveGlobalPed takes the menu index returned by AddGlobalPed.
    -- Without tracking that return value here we cannot reliably remove by label.
    -- Resources that need precise removal should store the return value of addGlobalPed themselves.
end)

-- Global vehicle --------------------------------------------------------------
-- mythic has no separate global vehicle intercept; options go into Config.VehicleMenu
-- which is evaluated for every vehicle target interaction.

exportHandler('addGlobalVehicle', function(options)
    local menu = convertOptions(options)
    for _, item in ipairs(menu) do
        table.insert(Config.VehicleMenu, item)
    end
end)

exportHandler('removeGlobalVehicle', function(options)
    if type(options) ~= 'table' then return end
    local labels = (type(options[1]) == 'string') and options or { options.label }
    for _, label in ipairs(labels) do
        for i = #Config.VehicleMenu, 1, -1 do
            if Config.VehicleMenu[i].text == label then
                table.remove(Config.VehicleMenu, i)
            end
        end
    end
end)

-- Global player ---------------------------------------------------------------

exportHandler('addGlobalPlayer', function(options)
    local menu = convertOptions(options)
    for _, item in ipairs(menu) do
        table.insert(Config.PlayerMenu, item)
    end
end)

exportHandler('removeGlobalPlayer', function(options)
    if type(options) ~= 'table' then return end
    local labels = (type(options[1]) == 'string') and options or { options.label }
    for _, label in ipairs(labels) do
        for i = #Config.PlayerMenu, 1, -1 do
            if Config.PlayerMenu[i].text == label then
                table.remove(Config.PlayerMenu, i)
            end
        end
    end
end)

-- addGlobalObject has no equivalent in mythic-targeting.
-- Register specific model hashes with addModel instead.
exportHandler('addGlobalObject', function(options)
    print('[ox_target bridge] addGlobalObject is not supported by mythic-targeting. Use addModel with explicit model hashes.')
end)

exportHandler('removeGlobalObject', function(options) end)

-- Misc ------------------------------------------------------------------------

exportHandler('isActive', function()
    return InTargetingMenu or false
end)

-- IS_SPAWNED is local to client/main.lua and cannot be reached from this file.
exportHandler('disableTargeting', function(value)
    print('[ox_target bridge] disableTargeting is not supported. IS_SPAWNED is scoped to main.lua.')
end)

exportHandler('addGlobalOption', function(options)
    TARGETING:AddGlobalPed(convertOptions(options))
end)

exportHandler('removeGlobalOption', function(options) end)
