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
local padsFolder = Instance.new("Folder", world)
padsFolder.Name = "Pads"
local towersFolder = Instance.new("Folder", world)
towersFolder.Name = "Towers"
local enemiesFolder = Instance.new("Folder", world)
enemiesFolder.Name = "Enemies"
local path = {
    Vector3.new(-72, 1, -42), Vector3.new(-38, 1, -42), Vector3.new(-38, 1, 8),
    Vector3.new(0, 1, 8), Vector3.new(0, 1, -30), Vector3.new(38, 1, -30),
    Vector3.new(38, 1, 35), Vector3.new(72, 1, 35),
}
local pads = {}
local towers = {}
local enemies = {}
local wallets = {}
local lastRequests = {}
local replayVotes = {}
local match = {wave = 0, health = Config.BaseHealth, phase = "BUILD", speed = 1, countdown = 0}
local nextTowerID, nextEnemyID = 0, 0
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
local positions = {
    {-58,-30}, {-50,-52}, {-26,-23}, {-50,0}, {-23,20}, {-12,-6},
    {12,-18}, {-12,-36}, {20,-42}, {26,-10}, {50,0}, {26,21}, {50,33}, {62,47},
}
for id, xy in ipairs(positions) do
    local p = part("Pad_" .. id, Vector3.new(9, 0.6, 9), Vector3.new(xy[1], 1.1, xy[2]), Color3.fromRGB(66, 113, 115), padsFolder, Enum.Material.Slate)
    p:SetAttribute("PadID", id)
    label(p, string.format("%02d  +", id), Color3.fromRGB(147, 240, 218), 1)
    pads[id] = {part = p, towerID = nil}
end
local portal = part("RiftPortal", Vector3.new(2, 15, 14), path[1] + Vector3.new(-3, 6, 0), Color3.fromRGB(177, 90, 255), world, Enum.Material.Neon)
portal.CanCollide = false
label(portal, "THE RIFT / ENEMY SPAWN", Color3.fromRGB(221, 193, 255), 9)
local core = part("ShrineCore", Vector3.new(7, 12, 7), path[#path] + Vector3.new(0, 5, 0), Color3.fromRGB(91, 239, 208), world, Enum.Material.Neon)
label(core, "PROTECT THE SHRINE", Color3.fromRGB(159, 255, 229), 9)
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

local function tell(player, message)
    stateEvent:FireClient(player, {notice = message})
end
local function towerCount(owner)
    local n = 0
    for _, t in pairs(towers) do if t.owner == owner then n = n + 1 end end
    return n
end
local function snapshot(player)
    local list = {}
    for id, t in pairs(towers) do
        list[#list + 1] = {id = id, kind = t.kind, level = t.level, pad = t.pad, owner = t.owner}
    end
    local alive = 0
    for _ in pairs(enemies) do alive = alive + 1 end
    local votes = 0
    for _ in pairs(replayVotes) do votes = votes + 1 end
    return {wave = match.wave, health = match.health, phase = match.phase, speed = match.speed,
        cash = wallets[player.UserId] or Config.StartingCash, towers = list, alive = alive,
        countdown = math.ceil(match.countdown), votes = votes, players = #Players:GetPlayers()}
end
local function broadcast()
    for _, player in ipairs(Players:GetPlayers()) do stateEvent:FireClient(player, snapshot(player)) end
end
local function payout(amount)
    for id, cash in pairs(wallets) do wallets[id] = cash + amount end
end
local function removeEnemy(id)
    local e = enemies[id]
    if e then e.part:Destroy(); enemies[id] = nil end
end
local function clearBattle()
    for id in pairs(enemies) do removeEnemy(id) end
    for id, t in pairs(towers) do
        t.model:Destroy()
        pads[t.pad].towerID = nil
        towers[id] = nil
    end
    for _, pad in ipairs(pads) do pad.part.Color = Color3.fromRGB(66, 113, 115) end
    for id in pairs(wallets) do wallets[id] = Config.StartingCash end
    match = {wave = 0, health = Config.BaseHealth, phase = "BUILD", speed = 1, countdown = 0}
    spawnRemaining, intermission = 0, 0
    replayVotes = {}
end
local function startWave()
    match.wave = match.wave + 1
    match.phase = "WAVE"
    match.countdown = 0
    spawnRemaining = Config.wave(match.wave).count
    spawnClock = 0
    broadcast()
end
local function spawnEnemy()
    local settings = Config.wave(match.wave)
    local boss = settings.boss and spawnRemaining == 1
    local runner = not boss and spawnRemaining % 4 == 0
    nextEnemyID = nextEnemyID + 1
    local size = boss and 7 or 3
    local p = part(boss and "Rift Sovereign" or runner and "Rift Runner" or "Rift Shade", Vector3.new(size, size, size), path[1] + Vector3.new(0, size / 2, 0), boss and Color3.fromRGB(248, 73, 136) or runner and Color3.fromRGB(255, 176, 91) or Color3.fromRGB(141, 103, 182), enemiesFolder, Enum.Material.Neon)
    p.CanCollide = false
    local hp = math.floor(settings.health * (boss and 10 or runner and 0.65 or 1))
    local text = label(p, p.Name .. "\n" .. hp .. " HP", nil, size / 2 + 2)
    enemies[nextEnemyID] = {part = p, hp = hp, maxHp = hp, segment = 1, progress = 0,
        speed = settings.speed * (boss and 0.65 or runner and 1.7 or 1), reward = settings.reward * (boss and 8 or 1),
        slowUntil = 0, leak = boss and 30 or 8, text = text, boss = boss}
end
local function damageEnemy(id, damage, slow)
    local e = enemies[id]
    if not e then return end
    e.hp = e.hp - damage
    if slow then e.slowUntil = 1.8 end
    if e.hp <= 0 then
        payout(e.reward)
        removeEnemy(id)
    else
        e.text.Text = e.part.Name .. "\n" .. e.hp .. " / " .. e.maxHp
    end
end
local function makeTower(player, kind, padID)
    nextTowerID = nextTowerID + 1
    local id = nextTowerID
    local model = Instance.new("Model", towersFolder)
    model.Name = "Tower_" .. id
    model:SetAttribute("TowerID", id)
    local unit = Config.Units[kind]
    local c = Color3.fromRGB(unit.color[1], unit.color[2], unit.color[3])
    local position = pads[padID].part.Position
    local body = part("Body", Vector3.new(3, 4, 2), position + Vector3.new(0, 2.6, 0), c, model)
    local head = part("Head", Vector3.new(2.2, 2.2, 2.2), position + Vector3.new(0, 5.6, 0), Color3.fromRGB(242, 216, 189), model)
    part("Hair", Vector3.new(2.5, 1, 2.5), head.Position + Vector3.new(0, 1, 0), c, model, Enum.Material.Neon)
    local weapon = part("SpiritBlade", Vector3.new(0.5, 6, 0.6), position + Vector3.new(2, 4, 0), c, model, Enum.Material.Neon)
    weapon.CanCollide = false
    model.PrimaryPart = body
    local text = label(head, unit.name .. " / Lv.1", c, 3)
    towers[id] = {model = model, body = body, kind = kind, level = 1, owner = player.UserId, pad = padID, cooldown = 0, text = text}
    pads[padID].towerID = id
    pads[padID].part.Color = c
end

Players.PlayerAdded:Connect(function(player)
    wallets[player.UserId] = Config.StartingCash
end)
Players.PlayerRemoving:Connect(function(player)
    wallets[player.UserId] = nil
    lastRequests[player.UserId] = nil
    replayVotes[player.UserId] = nil
    for id, t in pairs(towers) do
        if t.owner == player.UserId then
            t.model:Destroy()
            pads[t.pad].towerID = nil
            pads[t.pad].part.Color = Color3.fromRGB(66, 113, 115)
            towers[id] = nil
        end
    end
    if #Players:GetPlayers() == 0 then clearBattle() end
end)
for _, player in ipairs(Players:GetPlayers()) do wallets[player.UserId] = Config.StartingCash end

action.OnServerEvent:Connect(function(player, command, arg, kind)
    local now = os.clock()
    if now - (lastRequests[player.UserId] or -1) < 0.12 then return end
    lastRequests[player.UserId] = now
    if command == "Sync" then stateEvent:FireClient(player, snapshot(player)); return end
    if command == "Restart" then
        if match.phase ~= "VICTORY" and match.phase ~= "DEFEAT" then return end
        replayVotes[player.UserId] = true
        for _, p in ipairs(Players:GetPlayers()) do
            if not replayVotes[p.UserId] then broadcast(); return end
        end
        clearBattle(); broadcast(); return
    end
    if match.phase == "VICTORY" or match.phase == "DEFEAT" then return end
    if command == "Start" then
        if match.phase == "BUILD" or match.phase == "BREAK" then startWave() end
    elseif command == "Speed" then
        -- Shared speed changes require the first active player (the session host).
        if Players:GetPlayers()[1] ~= player then tell(player, "Only the host controls match speed."); return end
        match.speed = match.speed == 1 and 2 or 1
    elseif command == "Place" then
        if not Config.validInteger(arg, 1, #pads) or not Config.validInteger(kind, 1, #Config.Units) then return end
        if pads[arg].towerID then tell(player, "This pad is occupied."); return end
        if towerCount(player.UserId) >= Config.MaxTowers then tell(player, "Unit limit reached (12)."); return end
        if wallets[player.UserId] < Config.Units[kind].cost then tell(player, "Not enough credits."); return end
        wallets[player.UserId] = wallets[player.UserId] - Config.Units[kind].cost
        makeTower(player, kind, arg)
    elseif command == "Upgrade" or command == "Sell" then
        if not Config.validInteger(arg, 1, nextTowerID) then return end
        local t = towers[arg]
        if not t or t.owner ~= player.UserId then tell(player, "Select one of your own units."); return end
        if command == "Upgrade" then
            local cost = Config.stats(t.kind, t.level).upgradeCost
            if not cost then tell(player, "Maximum level reached."); return end
            if wallets[player.UserId] < cost then tell(player, "Not enough credits."); return end
            wallets[player.UserId] = wallets[player.UserId] - cost
            t.level = t.level + 1
            t.text.Text = Config.Units[t.kind].name .. " / Lv." .. t.level
        else
            wallets[player.UserId] = wallets[player.UserId] + math.floor(Config.invested(t.kind, t.level) * Config.SellRatio)
            pads[t.pad].towerID = nil
            pads[t.pad].part.Color = Color3.fromRGB(66, 113, 115)
            t.model:Destroy()
            towers[arg] = nil
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
            spawnEnemy()
            spawnRemaining = spawnRemaining - 1
            spawnClock = 0.9
        end
        for id, e in pairs(enemies) do
            e.slowUntil = math.max(0, e.slowUntil - dt)
            local travel = e.speed * (e.slowUntil > 0 and 0.5 or 1) * dt
            local leaked = false
            while travel > 0 do
                local a, b = path[e.segment], path[e.segment + 1]
                if not b then leaked = true; break end
                local length = (b - a).Magnitude
                local step = math.min(travel, length - e.progress)
                e.progress = e.progress + step
                travel = travel - step
                local pos = a:Lerp(b, e.progress / length) + Vector3.new(0, e.part.Size.Y / 2, 0)
                e.part.CFrame = CFrame.lookAt(pos, pos + (b - a))
                if e.progress >= length then e.segment = e.segment + 1; e.progress = 0 end
                if e.segment >= #path then leaked = true; break end
            end
            if leaked then
                match.health = math.max(0, match.health - e.leak)
                removeEnemy(id)
            end
        end
        if match.health <= 0 then
            match.phase = "DEFEAT"
            for id in pairs(enemies) do removeEnemy(id) end
            spawnRemaining = 0
            broadcast()
            return
        end
        for _, t in pairs(towers) do
            t.cooldown = math.max(0, t.cooldown - dt)
            if t.cooldown <= 0 then
                local stats = Config.stats(t.kind, t.level)
                local targetID, furthest = nil, -1
                for id, e in pairs(enemies) do
                    local progress = e.segment * 1000 + e.progress
                    if (e.part.Position - t.body.Position).Magnitude <= stats.range and progress > furthest then
                        targetID, furthest = id, progress
                    end
                end
                if targetID then
                    local targetPosition = enemies[targetID].part.Position
                    local unit = Config.Units[t.kind]
                    fxEvent:FireAllClients(t.body.Position + Vector3.new(0, 2, 0), targetPosition, t.kind)
                    if unit.splash then
                        local hits = {}
                        for id, e in pairs(enemies) do
                            if (e.part.Position - targetPosition).Magnitude <= unit.splash then hits[#hits + 1] = id end
                        end
                        for _, id in ipairs(hits) do damageEnemy(id, stats.damage) end
                    else damageEnemy(targetID, stats.damage, unit.slow) end
                    t.cooldown = stats.cooldown
                end
            end
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
