local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local api = Instance.new("Folder")
api.Name = "MysteriousAPI"
api.Parent = ReplicatedStorage
local action = Instance.new("RemoteEvent", api)
action.Name = "Action"
local stateEvent = Instance.new("RemoteEvent", api)
stateEvent.Name = "State"
local fxEvent = Instance.new("RemoteEvent", api)
fxEvent.Name = "FX"

local world = Instance.new("Folder", workspace)
world.Name = "MysteriousWorld"
local troopsFolder = Instance.new("Folder", world)
troopsFolder.Name = "Troops"
local enemiesFolder = Instance.new("Folder", world)
enemiesFolder.Name = "Enemies"
local path = {
    Vector3.new(-72, 1, -42), Vector3.new(-38, 1, -42), Vector3.new(-38, 1, 8),
    Vector3.new(0, 1, 8), Vector3.new(0, 1, -30), Vector3.new(38, 1, -30),
    Vector3.new(38, 1, 35), Vector3.new(72, 1, 35),
}
local troops = {}
local enemies = {}
local wallets = {}
local lastRequests = {}
local replayVotes = {}
local match = {wave = 0, health = Config.BaseHealth, phase = "BUILD", speed = 1, countdown = 0}
local nextTroopID, nextEnemyID = 0, 0
local spawnRemaining, spawnClock, intermission = 0, 0, 0
local syncClock = 0

local function part(name, size, position, color, parent, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = position
    p.Color = color
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = material or Enum.Material.SmoothPlastic
    p.Parent = parent or world
    return p
end
local function label(adornee, text, color, height)
    local gui = Instance.new("BillboardGui", adornee)
    gui.Size = UDim2.fromOffset(170, 42)
    gui.StudsOffset = Vector3.new(0, height or 4, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 180
    local textLabel = Instance.new("TextLabel", gui)
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 13
    textLabel.TextColor3 = color or Color3.new(1, 1, 1)
    textLabel.TextStrokeTransparency = 0.4
    textLabel.Text = text
    return textLabel
end

Lighting.ClockTime = 17.5
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(120, 130, 160)
part("Valley", Vector3.new(174, 2, 116), Vector3.new(0, -1, 0), Color3.fromRGB(40, 66, 64), world, Enum.Material.Grass)
for i = 1, #path - 1 do
    local a, b = path[i], path[i + 1]
    local lane = part("EnemyPath", Vector3.new(10, 0.3, (b - a).Magnitude + 9), (a + b) / 2, Color3.fromRGB(122, 112, 99), world, Enum.Material.Cobblestone)
    lane.CFrame = CFrame.lookAt((a + b) / 2, b)
end
local portal = part("RiftPortal", Vector3.new(2, 15, 14), path[1] + Vector3.new(-3, 6, 0), Color3.fromRGB(177, 90, 255), world, Enum.Material.Neon)
portal.CanCollide = false
label(portal, "THE RIFT / ENEMY SPAWN", Color3.fromRGB(221, 193, 255), 9)
local core = part("ShrineCore", Vector3.new(7, 12, 7), path[#path] + Vector3.new(0, 5, 0), Color3.fromRGB(91, 239, 208), world, Enum.Material.Neon)
core:SetAttribute("PlayerBase", true)
label(core, "YOUR BASE / TROOPS DEPLOY HERE", Color3.fromRGB(159, 255, 229), 9)
local spawn = Instance.new("SpawnLocation", world)
spawn.Name = "PlayerSpawn"
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 2, 43)
spawn.Anchored = true
spawn.Neutral = true
spawn.Transparency = 1
spawn.Duration = 0
-- Original, asset-free lantern village: the entire map works offline.
for _, x in ipairs({-72, -20, 20, 70}) do
    for _, z in ipairs({-53, 53}) do
        local building = part("VillageHouse", Vector3.new(16, 11, 10), Vector3.new(x, 5, z), Color3.fromRGB(205, 186, 151))
        part("Roof", Vector3.new(20, 2, 14), building.Position + Vector3.new(0, 6, 0), Color3.fromRGB(44, 52, 76))
        part("Door", Vector3.new(4, 7, 0.3), building.Position + Vector3.new(0, -1, z > 0 and -5.2 or 5.2), Color3.fromRGB(77, 54, 48))
    end
end
for _, xy in ipairs({{-62,18}, {-20,38}, {18,40}, {62,-18}}) do
    part("LanternPost", Vector3.new(1, 7, 1), Vector3.new(xy[1], 3, xy[2]), Color3.fromRGB(73, 58, 51))
    local lantern = part("Lantern", Vector3.new(2.5, 3, 2.5), Vector3.new(xy[1], 7, xy[2]), Color3.fromRGB(255, 199, 112), world, Enum.Material.Neon)
    local light = Instance.new("PointLight", lantern)
    light.Color = lantern.Color
    light.Range = 18
    light.Brightness = 1
end

-- Both armies use the same scalar route in opposite directions. This prevents
-- units from cutting across bends or walking through an opposing melee line.
local lengths, routeLength = {}, 0
for i = 1, #path - 1 do
    lengths[i] = (path[i + 1] - path[i]).Magnitude
    routeLength = routeLength + lengths[i]
end
local function pointAt(distance)
    local remaining = math.max(0, math.min(routeLength, distance))
    for i, length in ipairs(lengths) do
        if remaining <= length then return path[i]:Lerp(path[i + 1], remaining / length) end
        remaining = remaining - length
    end
    return path[#path]
end
local function tell(player, message) stateEvent:FireClient(player, {notice = message}) end
local function troopCount(owner)
    local n = 0
    for _, t in pairs(troops) do if t.owner == owner then n = n + 1 end end
    return n
end
local function snapshot(player)
    local list, alive, allies, votes = {}, 0, 0, 0
    for id, t in pairs(troops) do
        list[#list + 1] = {id = id, kind = t.kind, level = t.level, owner = t.owner,
            hp = t.hp, maxHp = Config.stats(t.kind, t.level).health, status = t.status, distance = t.distance}
        if t.hp > 0 then allies = allies + 1 end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    for _ in pairs(enemies) do alive = alive + 1 end
    for _ in pairs(replayVotes) do votes = votes + 1 end
    return {wave = match.wave, health = match.health, phase = match.phase, speed = match.speed,
        cash = wallets[player.UserId] or Config.StartingCash, troops = list, alive = alive, allies = allies,
        countdown = math.ceil(match.countdown), votes = votes, players = #Players:GetPlayers(), routeLength = routeLength}
end
local function broadcast()
    for _, player in ipairs(Players:GetPlayers()) do stateEvent:FireClient(player, snapshot(player)) end
end
local function payout(amount)
    for id, cash in pairs(wallets) do wallets[id] = cash + amount end
end
local function removeEnemy(id)
    local e = enemies[id]
    if e then e.model:Destroy(); enemies[id] = nil end
end
-- Original block characters have heads, arms, legs and spirit weapons.
-- Anchored parts are posed by the server; no external rigs/assets are required.
local function character(name, color, parent, scale)
    local model = Instance.new("Model", parent)
    model.Name = name
    local parts = {}
    local function limb(key, size, offset, tint, material)
        local p = part(key, size * scale, Vector3.new(0, -100, 0), tint, model, material)
        p.CanCollide = false
        parts[key] = {part = p, offset = offset * scale}
        return p
    end
    local skin = Color3.fromRGB(242, 216, 189)
    local body = limb("Body", Vector3.new(2.4, 2.8, 1.3), Vector3.new(0, 3.4, 0), color)
    local head = limb("Head", Vector3.new(1.7, 1.7, 1.7), Vector3.new(0, 5.65, 0), skin)
    limb("Hair", Vector3.new(1.9, 0.65, 1.9), Vector3.new(0, 6.5, 0), color, Enum.Material.Neon)
    limb("LeftArm", Vector3.new(0.8, 2.6, 0.9), Vector3.new(-1.7, 3.4, 0), color)
    limb("RightArm", Vector3.new(0.8, 2.6, 0.9), Vector3.new(1.7, 3.4, 0), color)
    limb("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.65, 1, 0), Color3.fromRGB(36, 42, 65))
    limb("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.65, 1, 0), Color3.fromRGB(36, 42, 65))
    limb("SpiritBlade", Vector3.new(0.25, 3.8, 0.5), Vector3.new(2.2, 3.8, -0.8), color, Enum.Material.Neon)
    model.PrimaryPart = body
    return {model = model, body = body, parts = parts, text = label(head, name, color, 2.6 * scale), scale = scale, gait = 0}
end
local function pose(actor, position, direction, walking, attacking, dt)
    actor.gait = actor.gait + (walking and dt * 9 or 0)
    local swing = walking and math.sin(actor.gait) * 0.65 or 0
    local frame = CFrame.lookAt(position, position + direction)
    for key, limb in pairs(actor.parts) do
        local angle = 0
        if key == "LeftLeg" or key == "RightArm" then angle = swing end
        if key == "RightLeg" or key == "LeftArm" then angle = -swing end
        if attacking and (key == "RightArm" or key == "SpiritBlade") then angle = -1.1 end
        limb.part.CFrame = frame * CFrame.new(limb.offset) * CFrame.Angles(angle, 0, 0)
    end
end
local function updateTroopLabel(t)
    t.text.Text = Config.Units[t.kind].name .. " / Lv." .. t.level .. "\n" .. math.ceil(t.hp) .. " HP / " .. t.status
end
local function resetTroop(t, delay)
    t.hp = Config.stats(t.kind, t.level).health
    t.distance, t.cooldown, t.releaseDelay = routeLength, 0, delay or 0
    t.status = match.phase == "WAVE" and "DEPLOYING" or "READY"
    t.model.Parent = troopsFolder
    pose(t, pointAt(routeLength) + Vector3.new((t.id % 3 - 1) * 2.5, 0, 5 + (t.id % 4) * 2), Vector3.new(-1, 0, 0), false, false, 0)
    updateTroopLabel(t)
end
local function clearBattle()
    for id in pairs(enemies) do removeEnemy(id) end
    for id, t in pairs(troops) do t.model:Destroy(); troops[id] = nil end
    for id in pairs(wallets) do wallets[id] = Config.StartingCash end
    match = {wave = 0, health = Config.BaseHealth, phase = "BUILD", speed = 1, countdown = 0}
    spawnRemaining, intermission = 0, 0
    replayVotes = {}
end
local function startWave()
    match.wave = match.wave + 1
    match.phase, match.countdown = "WAVE", 0
    spawnRemaining, spawnClock = Config.wave(match.wave).count, 0
    local ids = {}
    for id in pairs(troops) do ids[#ids + 1] = id end
    table.sort(ids)
    for index, id in ipairs(ids) do resetTroop(troops[id], (index - 1) * Config.DeployInterval) end
    broadcast()
end
local function spawnEnemy()
    local settings = Config.wave(match.wave)
    local boss = settings.boss and spawnRemaining == 1
    local runner = not boss and spawnRemaining % 4 == 0
    nextEnemyID = nextEnemyID + 1
    local name = boss and "Rift Sovereign" or runner and "Rift Runner" or "Rift Shade"
    local c = boss and Color3.fromRGB(248, 73, 136) or runner and Color3.fromRGB(255, 176, 91) or Color3.fromRGB(141, 103, 182)
    local e = character(name, c, enemiesFolder, boss and 1.7 or 0.85)
    e.hp = math.floor(settings.health * (boss and 10 or runner and 0.65 or 1))
    e.maxHp, e.distance, e.cooldown = e.hp, 0, 0
    e.speed = settings.speed * (boss and 0.65 or runner and 1.7 or 1)
    e.damage = settings.damage * (boss and 2.5 or 1)
    e.interval, e.range = settings.cooldown, boss and 8 or 5
    e.reward, e.leak, e.slowUntil = settings.reward * (boss and 8 or 1), boss and 30 or 8, 0
    e.name, e.boss = name, boss
    e.text.Text = name .. "\n" .. e.hp .. " HP"
    pose(e, pointAt(0), Vector3.new(1, 0, 0), false, false, 0)
    enemies[nextEnemyID] = e
end
local function damageEnemy(id, damage, slow)
    local e = enemies[id]
    if not e then return end
    e.hp = math.max(0, e.hp - damage)
    if slow then e.slowUntil = 1.8 end
    if e.hp <= 0 then payout(e.reward); removeEnemy(id)
    else e.text.Text = e.name .. "\n" .. math.ceil(e.hp) .. " / " .. e.maxHp end
end
local function damageTroop(t, damage)
    t.hp = math.max(0, t.hp - damage)
    if t.hp == 0 then
        t.status = "DOWN"
        -- Keep the recruited squad slot and investment. Revive at the next wave.
        t.model.Parent = nil
    end
    updateTroopLabel(t)
end
local function recruit(player, kind)
    nextTroopID = nextTroopID + 1
    local unit = Config.Units[kind]
    local t = character(unit.name, Color3.fromRGB(unit.color[1], unit.color[2], unit.color[3]), troopsFolder, 1)
    t.id, t.kind, t.owner, t.level = nextTroopID, kind, player.UserId, 1
    t.model.Name = "Troop_" .. t.id
    t.model:SetAttribute("TroopID", t.id)
    troops[t.id] = t
    resetTroop(t, 0)
end
local function firstOpponent(distance, opponents, isTroop)
    local targetID, gap = nil, math.huge
    for id, other in pairs(opponents) do
        if other.hp > 0 and (not isTroop or (other.status ~= "DEPLOYING" and other.status ~= "READY")) then
            local separation = math.abs(distance - other.distance)
            if separation < gap or (separation == gap and (not targetID or id < targetID)) then targetID, gap = id, separation end
        end
    end
    return targetID, gap
end
local function updateTroops(dt)
    -- Use stable order so a front line can take pressure before support troops.
    local ids = {}
    for id in pairs(troops) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local t = troops[id]
        if t.hp > 0 then
            t.releaseDelay = math.max(0, t.releaseDelay - dt)
            if t.releaseDelay <= 0 then
                local stats = Config.stats(t.kind, t.level)
                local targetID, gap = firstOpponent(t.distance, enemies, false)
                t.cooldown = math.max(0, t.cooldown - dt)
                local walking = not targetID or gap > stats.range
                if walking then
                    local travel = stats.speed * dt
                    if targetID then travel = math.min(travel, math.max(0, gap - stats.range)) end
                    t.distance = math.max(0, t.distance - travel)
                    t.status = t.distance == 0 and "AT_RIFT" or "MARCHING"
                else
                    t.status = "FIGHTING"
                    if t.cooldown <= 0 then
                        local enemy = enemies[targetID]
                        local unit = Config.Units[t.kind]
                        fxEvent:FireAllClients(t.body.Position, enemy.body.Position, t.kind)
                        if unit.splash then
                            local hits = {}
                            for enemyID, e in pairs(enemies) do
                                if math.abs(e.distance - enemy.distance) <= unit.splash then hits[#hits + 1] = enemyID end
                            end
                            for _, enemyID in ipairs(hits) do damageEnemy(enemyID, stats.damage) end
                        else damageEnemy(targetID, stats.damage, unit.slow) end
                        t.cooldown = stats.cooldown
                    end
                end
                local position = pointAt(t.distance)
                local destination = pointAt(math.max(0, t.distance - 1))
                if targetID and enemies[targetID] then destination = pointAt(enemies[targetID].distance) end
                local direction = destination - position
                if direction.Magnitude < 0.01 then direction = Vector3.new(-1, 0, 0) end
                pose(t, position + Vector3.new((t.id % 3 - 1) * 1.5, 0, 0), direction, walking and t.distance > 0, not walking, dt)
                updateTroopLabel(t)
            end
        end
    end
end
local function updateEnemies(dt)
    for id, e in pairs(enemies) do
        e.slowUntil = math.max(0, e.slowUntil - dt)
        e.cooldown = math.max(0, e.cooldown - dt)
        local targetID, gap = firstOpponent(e.distance, troops, true)
        local walking = not targetID or gap > e.range
        if walking then
            local travel = e.speed * (e.slowUntil > 0 and 0.5 or 1) * dt
            if targetID then travel = math.min(travel, math.max(0, gap - e.range)) end
            e.distance = math.min(routeLength, e.distance + travel)
        elseif e.cooldown <= 0 then
            local t = troops[targetID]
            fxEvent:FireAllClients(e.body.Position, t.body.Position, 0)
            damageTroop(t, e.damage)
            e.cooldown = e.interval
        end
        local position = pointAt(e.distance)
        local destination = pointAt(math.min(routeLength, e.distance + 1))
        if targetID and troops[targetID] and troops[targetID].hp > 0 then destination = pointAt(troops[targetID].distance) end
        local direction = destination - position
        if direction.Magnitude < 0.01 then direction = Vector3.new(1, 0, 0) end
        pose(e, position, direction, walking, not walking, dt)
        if e.distance >= routeLength then match.health = math.max(0, match.health - e.leak); removeEnemy(id) end
    end
end
local function checkReplay(excludedUserID)
    if match.phase ~= "VICTORY" and match.phase ~= "DEFEAT" then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.UserId ~= excludedUserID and not replayVotes[p.UserId] then return end
    end
    clearBattle()
end
Players.PlayerAdded:Connect(function(player) wallets[player.UserId] = Config.StartingCash end)
Players.PlayerRemoving:Connect(function(player)
    wallets[player.UserId], lastRequests[player.UserId], replayVotes[player.UserId] = nil, nil, nil
    for id, t in pairs(troops) do
        if t.owner == player.UserId then t.model:Destroy(); troops[id] = nil end
    end
    local remaining = 0
    for _, p in ipairs(Players:GetPlayers()) do if p ~= player then remaining = remaining + 1 end end
    if remaining == 0 then clearBattle() else checkReplay(player.UserId) end
    broadcast()
end)
for _, player in ipairs(Players:GetPlayers()) do wallets[player.UserId] = Config.StartingCash end

action.OnServerEvent:Connect(function(player, command, arg)
    local now = os.clock()
    if now - (lastRequests[player.UserId] or -1) < 0.12 then return end
    lastRequests[player.UserId] = now
    if command == "Sync" then stateEvent:FireClient(player, snapshot(player)); return end
    if command == "Restart" then
        if match.phase ~= "VICTORY" and match.phase ~= "DEFEAT" then return end
        replayVotes[player.UserId] = true
        checkReplay(); broadcast(); return
    end
    if match.phase == "VICTORY" or match.phase == "DEFEAT" then return end
    if command == "Start" then
        if match.phase == "BUILD" or match.phase == "BREAK" then startWave() end
    elseif command == "Speed" then
        if Players:GetPlayers()[1] ~= player then tell(player, "Only the host controls match speed."); return end
        match.speed = match.speed == 1 and 2 or 1
    elseif command == "Recruit" then
        if not Config.validInteger(arg, 1, #Config.Units) then return end
        if troopCount(player.UserId) >= Config.MaxTroops then tell(player, "Squad limit reached (12)."); return end
        if wallets[player.UserId] < Config.Units[arg].cost then tell(player, "Not enough credits."); return end
        wallets[player.UserId] = wallets[player.UserId] - Config.Units[arg].cost
        recruit(player, arg)
    elseif command == "Upgrade" or command == "Sell" then
        if not Config.validInteger(arg, 1, nextTroopID) then return end
        local t = troops[arg]
        if not t or t.owner ~= player.UserId then tell(player, "Select one of your own characters."); return end
        if command == "Upgrade" then
            local before = Config.stats(t.kind, t.level)
            local cost = before.upgradeCost
            if not cost then tell(player, "Maximum level reached."); return end
            if wallets[player.UserId] < cost then tell(player, "Not enough credits."); return end
            wallets[player.UserId], t.level = wallets[player.UserId] - cost, t.level + 1
            if t.hp > 0 then t.hp = t.hp + Config.stats(t.kind, t.level).health - before.health end
            updateTroopLabel(t)
        else
            wallets[player.UserId] = wallets[player.UserId] + math.floor(Config.invested(t.kind, t.level) * Config.SellRatio)
            t.model:Destroy(); troops[arg] = nil
        end
    else return end
    broadcast()
end)

RunService.Heartbeat:Connect(function(delta)
    local dt = math.min(delta, 0.15) * match.speed
    if match.phase == "BREAK" then
        intermission = intermission - dt
        match.countdown = math.max(0, intermission)
        if intermission <= 0 then startWave() end
    elseif match.phase == "WAVE" then
        spawnClock = spawnClock - dt
        if spawnRemaining > 0 and spawnClock <= 0 then
            spawnEnemy(); spawnRemaining = spawnRemaining - 1; spawnClock = 0.9
        end
        updateTroops(dt)
        updateEnemies(dt)
        if match.health <= 0 then
            match.phase = "DEFEAT"
            for id in pairs(enemies) do removeEnemy(id) end
            spawnRemaining = 0
            broadcast(); return
        end
        if spawnRemaining == 0 and next(enemies) == nil then
            payout(Config.wave(match.wave).clearReward)
            if match.wave == Config.MaxWaves then match.phase = "VICTORY"
            else match.phase = "BREAK"; intermission = 12; match.countdown = 12 end
            broadcast()
        end
    end
    syncClock = syncClock + delta
    if syncClock >= 0.4 then syncClock = 0; broadcast() end
end)
