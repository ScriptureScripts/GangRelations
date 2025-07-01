local gangs = {} -- { [gangName] = { id, members = { [identifier] = {name, rank} }, logs = {} } }
local logs = {} -- global logs
local stashes = {} -- { { gang = gangName, coords = vector3, stashId = string } }
local bossmenus = {} -- { { gang = gangName, coords = vector3 } }
local invites = {} -- { [govId] = { gang = gangName, inviter = src, timestamp = os.time() } }
local gangRoles = {} -- { [gangName] = { 'Leader', 'Hierarchy', ... } }

RegisterCommand('gm', function(source)
    if IsPlayerAceAllowed(source, Config.AllowedAce) then
        TriggerClientEvent('gangmanager:openUI', source)
        TriggerClientEvent('gangmanager:syncData', source, gangs, logs)
        TriggerClientEvent('gangmanager:syncStashes', source, stashes)
        TriggerClientEvent('gangmanager:syncBossMenus', source, bossmenus)
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1You do not have permission to use this command.' } })
        logToDiscord('Permission Denied', 'Player '..GetPlayerName(source)..' ('..tostring(source)..') tried to use /gm without permission.')
    end
end)

-- Admin places boss menu for a gang/org
RegisterNetEvent('gangmanager:createBossMenu')
AddEventHandler('gangmanager:createBossMenu', function(gang, coords)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AllowedAce) then return end
    if not gangs[gang] then return end
    table.insert(bossmenus, { gang = gang, coords = coords })
    addLog(gang, GetPlayerName(src)..' placed a Boss Menu at '..coords.x..','..coords.y..','..coords.z)
    TriggerClientEvent('gangmanager:syncBossMenus', -1, bossmenus)
end)

RegisterNetEvent('gangmanager:requestBossMenus')
AddEventHandler('gangmanager:requestBossMenus', function()
    TriggerClientEvent('gangmanager:syncBossMenus', source, bossmenus)
end)

-- Utility: Get player identifier
local function getIdentifier(src)
    for _,v in ipairs(GetPlayerIdentifiers(src)) do
        if v:find('license:') then return v end
    end
    return nil
end

-- Log to Discord webhook and in-memory
function logToDiscord(title, message)
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = 'GangManager',
        embeds = {{
            title = title,
            description = message,
            color = 16711680
        }}
    }), { ['Content-Type'] = 'application/json' })
end

function addLog(gang, msg)
    table.insert(logs, os.date('%Y-%m-%d %H:%M:%S')..' | '..msg)
    if gang and gangs[gang] then
        table.insert(gangs[gang].logs, os.date('%Y-%m-%d %H:%M:%S')..' | '..msg)
    end
    logToDiscord(gang or 'GangManager', msg)
end

-- Utility: Generate unique org ID
local function generateOrgID()
    local id
    repeat
        id = tostring(math.random(100000, 999999))
        local taken = false
        for _, g in pairs(gangs) do
            if g.id == id then taken = true break end
        end
    until not taken
    return id
end

-- CRUD: Create gang
RegisterNetEvent('gangmanager:createGang')
AddEventHandler('gangmanager:createGang', function(gangName)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AllowedAce) then
        logToDiscord('Permission Denied', 'Player '..GetPlayerName(src)..' ('..tostring(src)..') tried to create gang '..tostring(gangName)..' without permission.')
        return
    end
    if gangs[gangName] then
        logToDiscord('Gang Creation Failed', 'Player '..GetPlayerName(src)..' ('..tostring(src)..') tried to create an already existing gang: '..tostring(gangName))
        return
    end
    local orgID = generateOrgID()
    gangs[gangName] = { id = orgID, members = {}, logs = {} }
    addLog(gangName, GetPlayerName(src)..' created gang '..gangName..' (ID: '..orgID..')')
    TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
end)

-- CRUD: Delete gang
RegisterNetEvent('gangmanager:deleteGang')
AddEventHandler('gangmanager:deleteGang', function(gangName)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AllowedAce) then return end
    if not gangs[gangName] then return end
    gangs[gangName] = nil
    addLog(gangName, GetPlayerName(src)..' deleted gang '..gangName)
    TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
end)

-- CRUD: Add member
RegisterNetEvent('gangmanager:addMember')
AddEventHandler('gangmanager:addMember', function(gangName, identifier, name, rank)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AllowedAce) then return end
    if not gangs[gangName] then return end
    gangs[gangName].members[identifier] = { name = name, rank = rank }
    addLog(gangName, GetPlayerName(src)..' added '..name..' as '..rank..' to '..gangName)
    TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
end)

-- CRUD: Remove member
RegisterNetEvent('gangmanager:removeMember')
AddEventHandler('gangmanager:removeMember', function(gangName, identifier)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AllowedAce) then return end
    if not gangs[gangName] then return end
    local name = gangs[gangName].members[identifier] and gangs[gangName].members[identifier].name or identifier
    gangs[gangName].members[identifier] = nil
    addLog(gangName, GetPlayerName(src)..' removed '..name..' from '..gangName)
    TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
end)

-- CRUD: Change member rank
RegisterNetEvent('gangmanager:changeRank')
AddEventHandler('gangmanager:changeRank', function(gangName, identifier, newRank)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AllowedAce) then
        logToDiscord('Permission Denied', 'Player '..GetPlayerName(src)..' ('..tostring(src)..') tried to change rank in '..tostring(gangName)..' without permission.')
        return
    end
    if not gangs[gangName] or not gangs[gangName].members[identifier] then
        logToDiscord('Change Rank Failed', 'Player '..GetPlayerName(src)..' ('..tostring(src)..') tried to change rank for non-existent member or gang: '..tostring(gangName))
        return
    end
    local name = gangs[gangName].members[identifier].name
    gangs[gangName].members[identifier].rank = newRank
    addLog(gangName, GetPlayerName(src)..' changed '..name..' rank to '..newRank..' in '..gangName)
    TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
end)

-- Send full data to client
RegisterNetEvent('gangmanager:requestData')
AddEventHandler('gangmanager:requestData', function()
    local src = source
    if IsPlayerAceAllowed(src, Config.AllowedAce) then
        TriggerClientEvent('gangmanager:syncData', src, gangs, logs)
        TriggerClientEvent('gangmanager:syncStashes', src, stashes)
        TriggerClientEvent('gangmanager:syncBossMenus', src, bossmenus)
    end
end)

-- Admin creates new stash for gang/org
RegisterNetEvent('gangmanager:createStash')
AddEventHandler('gangmanager:createStash', function(gang, coords)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AllowedAce) then return end
    if not gangs[gang] then return end
    local stashId = gang..'_'..math.random(10000,99999)
    -- OX-inventory integration
    TriggerEvent('ox_inventory:registerStash', stashId, {
        label = gang..' Stash',
        slots = 50,
        weight = 100000,
        coords = coords,
        owner = gang
    })
    table.insert(stashes, { gang = gang, coords = coords, stashId = stashId })
    addLog(gang, GetPlayerName(src)..' created a new stash at '..coords.x..','..coords.y..','..coords.z)
    TriggerClientEvent('gangmanager:syncStashes', -1, stashes)
end)

-- Player tries to open a stash
RegisterNetEvent('gangmanager:openStash')
AddEventHandler('gangmanager:openStash', function(stashId)
    local src = source
    local identifier = getIdentifier(src)
    local found = nil
    for _, s in ipairs(stashes) do
        if s.stashId == stashId then found = s break end
    end
    if not found then return end
    if not gangs[found.gang] or not gangs[found.gang].members[identifier] then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1You are not a member of this gang.' } })
        return
    end
    -- OX-inventory open stash
    TriggerEvent('ox_inventory:openStash', src, stashId)
end)

-- Sync stashes to client
RegisterNetEvent('gangmanager:requestStashes')
AddEventHandler('gangmanager:requestStashes', function()
    local src = source
    TriggerClientEvent('gangmanager:syncStashes', src, stashes)
end)

-- Invite system
RegisterNetEvent('gangmanager:inviteMember')
AddEventHandler('gangmanager:inviteMember', function(gang, govId, inviter)
    local src = source
    if not gangs[gang] then return end
    -- Only leader/hierarchy/admin can invite
    local identifier = getIdentifier(src)
    local member = gangs[gang].members[identifier]
    if not (IsPlayerAceAllowed(src, Config.AllowedAce) or (member and (member.rank == 'Leader' or member.rank == 'Hierarchy'))) then return end
    invites[govId] = { gang = gang, inviter = src, timestamp = os.time() }
    -- Notify the invited player (if online)
    for _, pid in ipairs(GetPlayers()) do
        if govId == tostring(pid) then -- Replace with actual govId lookup in your framework
            TriggerClientEvent('gangmanager:receiveInvite', pid, gang, inviter)
        end
    end
    addLog(gang, GetPlayerName(src)..' invited '..govId..' to '..gang)
end)

RegisterNetEvent('gangmanager:acceptInvite')
AddEventHandler('gangmanager:acceptInvite', function(gang)
    local src = source
    local govId = tostring(src) -- Replace with actual govId lookup
    if invites[govId] and invites[govId].gang == gang then
        local name = GetPlayerName(src)
        local identifier = getIdentifier(src)
        gangs[gang].members[identifier] = { name = name, rank = 'PROBIE' }
        -- Notify inviter
        local inviter = invites[govId].inviter
        if inviter then
            TriggerClientEvent('gangmanager:inviteResult', inviter, govId, gang, true)
        end
        invites[govId] = nil
        addLog(gang, name..' accepted invite to '..gang)
    end
end)

RegisterNetEvent('gangmanager:declineInvite')
AddEventHandler('gangmanager:declineInvite', function(gang)
    local src = source
    local govId = tostring(src) -- Replace with actual govId lookup
    if invites[govId] and invites[govId].gang == gang then
        -- Notify inviter
        local inviter = invites[govId].inviter
        if inviter then
            TriggerClientEvent('gangmanager:inviteResult', inviter, govId, gang, false)
        end
        invites[govId] = nil
        addLog(gang, GetPlayerName(src)..' declined invite to '..gang)
    end
end)

-- Role management
RegisterNetEvent('gangmanager:addRole')
AddEventHandler('gangmanager:addRole', function(gang, role)
    local src = source
    if not gangs[gang] then return end
    if not gangRoles[gang] then gangRoles[gang] = { 'Leader', 'Hierarchy' } end
    if not table.contains(gangRoles[gang], role) then
        table.insert(gangRoles[gang], role)
        addLog(gang, GetPlayerName(src)..' added role '..role)
        gangs[gang].roles = gangRoles[gang]
        TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
    end
end)

RegisterNetEvent('gangmanager:removeRole')
AddEventHandler('gangmanager:removeRole', function(gang, role)
    local src = source
    if not gangs[gang] then return end
    if not gangRoles[gang] then return end
    for i, r in ipairs(gangRoles[gang]) do
        if r == role and r ~= 'Leader' and r ~= 'Hierarchy' then
            table.remove(gangRoles[gang], i)
            addLog(gang, GetPlayerName(src)..' removed role '..role)
            TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
            break
        end
    end
end)

-- Promote/Demote/Assign Role
RegisterNetEvent('gangmanager:setMemberRole')
AddEventHandler('gangmanager:setMemberRole', function(gang, identifier, role)
    local src = source
    if not gangs[gang] or not gangs[gang].members[identifier] then return end
    gangs[gang].members[identifier].rank = role
    addLog(gang, GetPlayerName(src)..' set '..gangs[gang].members[identifier].name..' to '..role)
    TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
end)

-- Remove member
RegisterNetEvent('gangmanager:removeMemberBossMenu')
AddEventHandler('gangmanager:removeMemberBossMenu', function(gang, identifier)
    local src = source
    if not gangs[gang] or not gangs[gang].members[identifier] then return end
    local name = gangs[gang].members[identifier].name
    gangs[gang].members[identifier] = nil
    addLog(gang, GetPlayerName(src)..' removed '..name..' from '..gang)
    TriggerClientEvent('gangmanager:syncData', -1, gangs, logs)
end)

-- Boss Announcement (from UI)
RegisterNetEvent('gangmanager:bossAnnounce')
AddEventHandler('gangmanager:bossAnnounce', function(gang, message)
    local src = source
    if not gangs[gang] then return end
    local identifier = getIdentifier(src)
    local member = gangs[gang].members[identifier]
    if not member or (member.rank ~= 'Leader' and member.rank ~= 'Hierarchy') then return end
    for _, pid in ipairs(GetPlayers()) do
        local id = getIdentifier(pid)
        if gangs[gang].members[id] then
            TriggerClientEvent('gangmanager:showAnnouncement', pid, gang, message, GetPlayerName(src))
        end
    end
    addLog(gang, GetPlayerName(src)..' sent announcement: '..message)
end)

-- /bossm command
RegisterCommand('bossm', function(src, args, raw)
    local identifier = getIdentifier(src)
    local playerGang, member = nil, nil
    for gangName, gangData in pairs(gangs) do
        if gangData.members[identifier] then
            playerGang = gangName
            member = gangData.members[identifier]
            break
        end
    end
    if not playerGang or not member or (member.rank ~= 'Leader' and member.rank ~= 'Hierarchy') then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1You are not a boss of any gang/org.' } })
        return
    end
    local msg = table.concat(args, ' ')
    if msg == '' then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1Usage: /bossm [message]' } })
        return
    end
    for _, pid in ipairs(GetPlayers()) do
        local id = getIdentifier(pid)
        if gangs[playerGang].members[id] then
            TriggerClientEvent('gangmanager:showAnnouncement', pid, playerGang, msg, GetPlayerName(src))
        end
    end
    addLog(playerGang, GetPlayerName(src)..' sent announcement: '..msg)
end)

function table.contains(t, val)
    for _,v in ipairs(t) do if v == val then return true end end
    return false
end

-- TODO: Save/load gangs from disk if persistence is needed.

-- ORG CHAT: /org <message>
RegisterNetEvent('gangmanager:orgChat')
AddEventHandler('gangmanager:orgChat', function(msg)
    local src = source
    local senderName = GetPlayerName(src)
    local identifier = getIdentifier(src)
    local playerGang = nil
    local orgID = nil
    for gangName, gangData in pairs(gangs) do
        if gangData.members[identifier] then
            playerGang = gangName
            orgID = gangData.id
            break
        end
    end
    if not playerGang then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1You are not in any gang/org.' } })
        return
    end
    -- Send message to all online members in same gang
    for _, pid in ipairs(GetPlayers()) do
        local id = getIdentifier(pid)
        if gangs[playerGang].members[id] then
            TriggerClientEvent('chat:addMessage', pid, { args = { '^6[ORG] ^7'..senderName..': '..msg } })
        end
    end
    -- Relay to all admins in /adminorg
    for _, pid in ipairs(GetPlayers()) do
        if IsPlayerAceAllowed(pid, Config.AllowedAce) then
            TriggerClientEvent('gangmanager:adminOrgChat', pid, {
                orgID = orgID,
                gang = playerGang,
                sender = senderName,
                message = msg,
                from = 'member'
            })
        end
    end
    addLog(playerGang, senderName..' (ORG Chat): '..msg)
end)

-- ADMINORG UI: /adminorg
RegisterCommand('adminorg', function(source)
    if not IsPlayerAceAllowed(source, Config.AllowedAce) then return end
    TriggerClientEvent('gangmanager:openAdminOrg', source, gangs)
end)

-- ADMIN SEND TO ORG: /chat<ID> <message>
AddEventHandler('chatMessage', function(source, name, msg)
    if not IsPlayerAceAllowed(source, Config.AllowedAce) then return end
    local chatID, text = msg:match('^/chat(%d+)%s+(.+)')
    if chatID and text then
        -- Find gang by ID
        local gangName = nil
        for gname, gdata in pairs(gangs) do
            if tostring(gdata.id) == chatID then
                gangName = gname
                break
            end
        end
        if not gangName then
            TriggerClientEvent('chat:addMessage', source, { args = { '^1No org with that ID.' } })
            CancelEvent()
            return
        end
        -- Send to all online members
        for _, pid in ipairs(GetPlayers()) do
            local id = getIdentifier(pid)
            if gangs[gangName].members[id] then
                TriggerClientEvent('chat:addMessage', pid, { args = { '^6[ADMIN->ORG] ^7'..name..': '..text } })
            end
        end
        -- Log and relay to all admins in /adminorg
        for _, pid in ipairs(GetPlayers()) do
            if IsPlayerAceAllowed(pid, Config.AllowedAce) then
                TriggerClientEvent('gangmanager:adminOrgChat', pid, {
                    orgID = chatID,
                    gang = gangName,
                    sender = name,
                    message = text,
                    from = 'admin'
                })
            end
        end
        addLog(gangName, name..' (ADMIN->ORG '..chatID..'): '..text)
        CancelEvent()
    end
end)
