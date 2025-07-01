local gangs = {}
local logs = {}
local stashes = {}
local bossmenus = {}

RegisterNetEvent('gangmanager:openUI')
AddEventHandler('gangmanager:openUI', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'show' })
    TriggerServerEvent('gangmanager:requestData')
end)

RegisterNetEvent('gangmanager:syncData')
AddEventHandler('gangmanager:syncData', function(srvGangs, srvLogs)
    gangs = srvGangs
    logs = srvLogs
    SendNUIMessage({ action = 'updateData', gangs = gangs, logs = logs })
end)

RegisterNetEvent('gangmanager:syncStashes')
AddEventHandler('gangmanager:syncStashes', function(srvStashes)
    stashes = srvStashes
    SendNUIMessage({ action = 'updateStashes', stashes = stashes })
end)

RegisterNetEvent('gangmanager:syncBossMenus')
AddEventHandler('gangmanager:syncBossMenus', function(srvBossMenus)
    bossmenus = srvBossMenus
    SendNUIMessage({ action = 'updateBossMenus', bossmenus = bossmenus })
end)

-- UI -> Server events
RegisterNUICallback('createGang', function(data, cb)
    TriggerServerEvent('gangmanager:createGang', data.gangName)
    cb(true)
end)
RegisterNUICallback('deleteGang', function(data, cb)
    TriggerServerEvent('gangmanager:deleteGang', data.gangName)
    cb(true)
end)
RegisterNUICallback('addMember', function(data, cb)
    TriggerServerEvent('gangmanager:addMember', data.gangName, data.identifier, data.name, data.rank)
    cb(true)
end)
RegisterNUICallback('removeMember', function(data, cb)
    TriggerServerEvent('gangmanager:removeMember', data.gangName, data.identifier)
    cb(true)
end)
RegisterNUICallback('changeRank', function(data, cb)
    TriggerServerEvent('gangmanager:changeRank', data.gangName, data.identifier, data.rank)
    cb(true)
end)
RegisterNUICallback('createStash', function(data, cb)
    -- Get player coords from client
    TriggerEvent('gangmanager:getCoords', function(coords)
        TriggerServerEvent('gangmanager:createStash', data.gang, coords)
        cb(true)
    end)
end)
RegisterNUICallback('openStash', function(data, cb)
    TriggerServerEvent('gangmanager:openStash', data.stashId)
    cb(true)
end)
RegisterNUICallback('createBossMenu', function(data, cb)
    TriggerEvent('gangmanager:getCoords', function(coords)
        TriggerServerEvent('gangmanager:createBossMenu', data.gang, coords)
        cb(true)
    end)
end)
RegisterNUICallback('inviteMember', function(data, cb)
    TriggerServerEvent('gangmanager:inviteMember', data.gang, data.govId, data.inviter)
    cb(true)
end)
RegisterNUICallback('acceptInvite', function(data, cb)
    TriggerServerEvent('gangmanager:acceptInvite', data.gang)
    cb(true)
end)
RegisterNUICallback('declineInvite', function(data, cb)
    TriggerServerEvent('gangmanager:declineInvite', data.gang)
    cb(true)
end)
RegisterNUICallback('addRole', function(data, cb)
    TriggerServerEvent('gangmanager:addRole', data.gang, data.role)
    cb(true)
end)
RegisterNUICallback('removeRole', function(data, cb)
    TriggerServerEvent('gangmanager:removeRole', data.gang, data.role)
    cb(true)
end)
RegisterNUICallback('setMemberRole', function(data, cb)
    TriggerServerEvent('gangmanager:setMemberRole', data.gang, data.identifier, data.role)
    cb(true)
end)
RegisterNUICallback('removeMemberBossMenu', function(data, cb)
    TriggerServerEvent('gangmanager:removeMemberBossMenu', data.gang, data.identifier)
    cb(true)
end)

RegisterNUICallback('bossAnnounce', function(data, cb)
    TriggerServerEvent('gangmanager:bossAnnounce', data.gang, data.message)
    cb(true)
end)

RegisterNetEvent('gangmanager:showAnnouncement')
AddEventHandler('gangmanager:showAnnouncement', function(gang, message, sender)
    SendNUIMessage({
        action = 'showAnnouncement',
        gang = gang,
        message = message,
        sender = sender
    })
end)

RegisterCommand('org', function(source, args, raw)
    local msg = table.concat(args, ' ')
    TriggerServerEvent('gangmanager:orgChat', msg)
end, false)

-- Get player coords for stash/bossmenu placement
RegisterNetEvent('gangmanager:getCoords')
AddEventHandler('gangmanager:getCoords', function(cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({ x = coords.x, y = coords.y, z = coords.z })
end)

-- Listen for 3rd eye/target at boss menu locations (stub)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1500)
        local ped = PlayerPedId()
        local myCoords = GetEntityCoords(ped)
        for _, bm in ipairs(bossmenus) do
            local dist = #(vector3(bm.coords.x, bm.coords.y, bm.coords.z) - myCoords)
            if dist < 2.0 then
                -- Show prompt to open boss menu (replace with 3rd eye integration)
                SetTextComponentFormat('STRING')
                AddTextComponentString('Press ~INPUT_CONTEXT~ to open Boss Menu')
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                if IsControlJustReleased(0, 38) then -- E
                    SendNUIMessage({ action = 'showBossMenu', gang = bm.gang })
                    SetNuiFocus(true, true)
                end
            end
        end
    end
end)

-- Receive invite notification
RegisterNetEvent('gangmanager:receiveInvite')
AddEventHandler('gangmanager:receiveInvite', function(gang, inviter)
    SendNUIMessage({ action = 'showInvite', gang = gang, inviter = inviter })
end)

-- Receive invite result (toast)
RegisterNetEvent('gangmanager:inviteResult')
AddEventHandler('gangmanager:inviteResult', function(govId, gang, accepted)
    SendNUIMessage({ action = 'inviteResult', govId = govId, gang = gang, accepted = accepted })
end)

-- Admin Org UI
RegisterNetEvent('gangmanager:openAdminOrg')
AddEventHandler('gangmanager:openAdminOrg', function(gangs)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showAdminOrg', gangs = gangs })
end)

-- Receive all org/admin chat
RegisterNetEvent('gangmanager:adminOrgChat')
AddEventHandler('gangmanager:adminOrgChat', function(data)
    SendNUIMessage({ action = 'adminOrgChat', data = data })
end)

-- NUI callback to close admin org UI
RegisterNUICallback('closeAdminOrg', function(_, cb)
    SetNuiFocus(false, false)
    cb(true)
end)
