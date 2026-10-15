local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local api = ReplicatedStorage:WaitForChild("MysteriousAPI")
local action, stateEvent, fxEvent = api:WaitForChild("Action"), api:WaitForChild("State"), api:WaitForChild("FX")
local world = workspace:WaitForChild("MysteriousWorld")
local selectedKind, selectedTower = 1, nil
local latest, effects = nil, true
local noticeVersion = 0
local background = Color3.fromRGB(15, 22, 37)
local muted = Color3.fromRGB(160, 176, 198)
local accent = Color3.fromRGB(102, 238, 201)

local gui = Instance.new("ScreenGui")
gui.Name = "AnimeMysterious"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame", gui)
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)

local function rounded(obj, radius)
    local corner = Instance.new("UICorner", obj)
    corner.CornerRadius = UDim.new(0, radius or 12)
end
local function panel(parent, size, position)
    local frame = Instance.new("Frame", parent)
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = background
    frame.BackgroundTransparency = 0.06
    frame.BorderSizePixel = 0
    rounded(frame)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(66, 87, 110)
    stroke.Transparency = 0.35
    return frame
end
local function text(parent, value, size, pos, color, fontSize)
    local item = Instance.new("TextLabel", parent)
    item.Size = size
    item.Position = pos
    item.BackgroundTransparency = 1
    item.Text = value
    item.Font = Enum.Font.GothamMedium
    item.TextSize = fontSize or 15
    item.TextColor3 = color or Color3.new(1, 1, 1)
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextWrapped = true
    return item
end
local function button(parent, value, size, pos, callback, color)
    local item = Instance.new("TextButton", parent)
    item.Size = size
    item.Position = pos
    item.Text = value
    item.TextColor3 = background
    item.Font = Enum.Font.GothamBold
    item.TextSize = 15
    item.BackgroundColor3 = color or accent
    item.BorderSizePixel = 0
    rounded(item, 8)
    item.Activated:Connect(callback)
    return item
end
local header = panel(root, UDim2.fromOffset(670, 78), UDim2.new(0.5, 0, 0, 10))
header.AnchorPoint = Vector2.new(0.5, 0)
local headerScale = Instance.new("UIScale", header)
text(header, "ANIME / MYSTERIOUS", UDim2.fromOffset(220, 24), UDim2.fromOffset(18, 9), accent, 16)
local waveText = text(header, "LANTERN VALLEY  /  WAVE 0 OF 8", UDim2.fromOffset(370, 22), UDim2.fromOffset(18, 40), muted, 13)
local healthText = text(header, "SHRINE  100 / 100", UDim2.fromOffset(200, 24), UDim2.fromOffset(440, 9), nil, 15)
local healthTrack = panel(header, UDim2.fromOffset(200, 8), UDim2.fromOffset(440, 44))
local healthFill = Instance.new("Frame", healthTrack)
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.BackgroundColor3 = accent
healthFill.BorderSizePixel = 0
rounded(healthFill, 4)

local controls = panel(root, UDim2.fromOffset(220, 160), UDim2.new(1, -16, 0, 112))
controls.AnchorPoint = Vector2.new(1, 0)
local controlsScale = Instance.new("UIScale", controls)
local phaseText = text(controls, "BUILD YOUR DEFENSE", UDim2.fromOffset(196, 25), UDim2.fromOffset(12, 9), accent, 13)
local aliveText = text(controls, "0 enemies alive", UDim2.fromOffset(196, 24), UDim2.fromOffset(12, 34), muted, 13)
local startButton = button(controls, "START WAVE  [SPACE]", UDim2.fromOffset(196, 36), UDim2.fromOffset(12, 66), function()
    action:FireServer(latest and (latest.phase == "VICTORY" or latest.phase == "DEFEAT") and "Restart" or "Start")
end)
local speedButton = button(controls, "SPEED  x1", UDim2.fromOffset(94, 32), UDim2.fromOffset(12, 113), function() action:FireServer("Speed") end, Color3.fromRGB(188, 205, 229))
local fxButton = button(controls, "FX  ON", UDim2.fromOffset(94, 32), UDim2.fromOffset(114, 113), function()
    effects = not effects
end, Color3.fromRGB(188, 205, 229))

local detail = panel(root, UDim2.fromOffset(258, 216), UDim2.new(0, 16, 0, 112))
local detailScale = Instance.new("UIScale", detail)
local detailTitle = text(detail, "YOUR FIRST DEFENSE", UDim2.fromOffset(230, 26), UDim2.fromOffset(14, 10), accent, 15)
local detailBody = text(detail, "1  Choose a unit below\n2  Click a glowing numbered pad\n3  Start the wave\n\nClick a placed unit to upgrade.\nFrost slows. Astral hits groups.", UDim2.fromOffset(230, 126), UDim2.fromOffset(14, 39), muted, 14)
local upgradeButton = button(detail, "UPGRADE", UDim2.fromOffset(144, 34), UDim2.fromOffset(12, 168), function()
    if selectedTower then action:FireServer("Upgrade", selectedTower) end
end)
local sellButton = button(detail, "SELL", UDim2.fromOffset(80, 34), UDim2.fromOffset(166, 168), function()
    if selectedTower then action:FireServer("Sell", selectedTower) end
end, Color3.fromRGB(255, 155, 144))
upgradeButton.Visible, sellButton.Visible = false, false

local dock = panel(root, UDim2.fromOffset(690, 132), UDim2.new(0.5, 0, 1, -14))
dock.AnchorPoint = Vector2.new(0.5, 1)
local dockScale = Instance.new("UIScale", dock)
local cashText = text(dock, "900 CREDITS", UDim2.fromOffset(330, 28), UDim2.fromOffset(14, 5), accent, 18)
local capText = text(dock, "0 / 12 UNITS", UDim2.fromOffset(170, 28), UDim2.fromOffset(513, 5), muted, 13)
local cards = {}
for kind, unit in ipairs(Config.Units) do
    local color = Color3.fromRGB(unit.color[1], unit.color[2], unit.color[3])
    local b = button(dock, "", UDim2.fromOffset(214, 80), UDim2.fromOffset(14 + (kind - 1) * 224, 39), function()
        selectedKind, selectedTower = kind, nil
    end, Color3.fromRGB(35, 46, 65))
    text(b, kind .. "  " .. unit.name, UDim2.fromOffset(194, 24), UDim2.fromOffset(10, 5), color, 15)
    text(b, unit.role, UDim2.fromOffset(194, 18), UDim2.fromOffset(10, 30), muted, 10)
    local price = text(b, unit.cost .. " CREDITS", UDim2.fromOffset(194, 22), UDim2.fromOffset(10, 51), nil, 14)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = color
    stroke.Thickness = 2
    cards[kind] = {button = b, stroke = stroke, price = price}
end
local notice = text(root, "Choose a unit, then click a numbered pad.  [Q] Cancel", UDim2.fromOffset(680, 42), UDim2.new(0.5, 0, 1, -159), Color3.new(1, 1, 1), 15)
notice.AnchorPoint = Vector2.new(0.5, 1)
notice.TextXAlignment = Enum.TextXAlignment.Center
notice.TextStrokeTransparency = 0.3
local noticeScale = Instance.new("UIScale", notice)
local function notify(message)
    noticeVersion = noticeVersion + 1
    local version = noticeVersion
    notice.Text = message
    task.delay(4, function()
        if version == noticeVersion then notice.Text = "Choose a unit, then click a numbered pad.  [Q] Cancel" end
    end)
end

local rangePart = Instance.new("Part")
rangePart.Name = "LocalRangeIndicator"
rangePart.Shape = Enum.PartType.Cylinder
rangePart.Anchored = true
rangePart.CanCollide, rangePart.CanTouch, rangePart.CanQuery = false, false, false
rangePart.Material = Enum.Material.Neon
rangePart.Transparency = 0.9
rangePart.Color = accent
local function towerInfo(id)
    if latest then for _, t in ipairs(latest.towers) do if t.id == id then return t end end end
    return nil
end
local function padPart(padID)
    return world.Pads:FindFirstChild("Pad_" .. padID)
end
local function showRange(position, radius, color)
    rangePart.Size = Vector3.new(0.1, radius * 2, radius * 2)
    rangePart.CFrame = CFrame.new(position.X, 1.55, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
    rangePart.Color = color
    rangePart.Parent = workspace
end
local function hitAt(position)
    local camera = workspace.CurrentCamera
    local ray = camera:ScreenPointToRay(position.X, position.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {world.Pads, world.Towers}
    return workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
end
local function clicked(position)
    local result = hitAt(position)
    if not result then selectedTower = nil; return end
    local hit = result.Instance
    local model = hit:FindFirstAncestorOfClass("Model")
    if model and model:GetAttribute("TowerID") then
        selectedTower, selectedKind = model:GetAttribute("TowerID"), nil
        return
    end
    local padID = hit:GetAttribute("PadID")
    if padID then
        if latest then
            for _, t in ipairs(latest.towers) do
                if t.pad == padID then selectedTower, selectedKind = t.id, nil; return end
            end
        end
        if selectedKind then action:FireServer("Place", padID, selectedKind)
        else notify("Choose a unit card first.") end
    end
end
local touchStart = nil
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Touch then touchStart = input.Position end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then clicked(input.Position) end
    if input.KeyCode == Enum.KeyCode.One then selectedKind, selectedTower = 1, nil
    elseif input.KeyCode == Enum.KeyCode.Two then selectedKind, selectedTower = 2, nil
    elseif input.KeyCode == Enum.KeyCode.Three then selectedKind, selectedTower = 3, nil
    elseif input.KeyCode == Enum.KeyCode.Q then selectedKind, selectedTower = nil, nil
    elseif input.KeyCode == Enum.KeyCode.E and selectedTower then action:FireServer("Upgrade", selectedTower)
    elseif input.KeyCode == Enum.KeyCode.X and selectedTower then action:FireServer("Sell", selectedTower)
    elseif input.KeyCode == Enum.KeyCode.Space then action:FireServer("Start") end
end)
UserInputService.InputEnded:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.Touch then
        if not processed and touchStart and (input.Position - touchStart).Magnitude < 20 then clicked(input.Position) end
        touchStart = nil
    end
end)
stateEvent.OnClientEvent:Connect(function(state)
    if state.notice then notify(state.notice); return end
    latest = state
    if selectedTower and not towerInfo(selectedTower) then selectedTower = nil end
end)
fxEvent.OnClientEvent:Connect(function(origin, target, kind)
    if not effects then return end
    local unit = Config.Units[kind]
    local beam = Instance.new("Part")
    beam.Name = "LocalShot"
    beam.Anchored = true
    beam.CanCollide, beam.CanTouch, beam.CanQuery = false, false, false
    beam.Material = Enum.Material.Neon
    beam.Color = Color3.fromRGB(unit.color[1], unit.color[2], unit.color[3])
    beam.Size = Vector3.new(0.18, 0.18, (target - origin).Magnitude)
    beam.CFrame = CFrame.lookAt((origin + target) / 2, target)
    beam.Parent = workspace
    TweenService:Create(beam, TweenInfo.new(0.16), {Transparency = 1}):Play()
    Debris:AddItem(beam, 0.2)
end)

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local view = camera.ViewportSize
    if view.Y <= 0 then return end
    local scale = math.min(1, view.X / 740, view.Y / 630)
    headerScale.Scale, dockScale.Scale, noticeScale.Scale = scale, scale, scale
    controlsScale.Scale, detailScale.Scale = scale, scale
    controls.Position = UDim2.new(1, -12, 0, 20 + 82 * scale)
    detail.Position = UDim2.new(0, 12, 0, 20 + 82 * scale)
    notice.Position = UDim2.new(0.5, 0, 1, -20 - 132 * scale)
    -- A full-board tactical camera keeps the route visible on portrait screens too.
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = 55
    local distance = math.max(135, 105 / (view.X / view.Y))
    local focus = Vector3.new(0, 0, 0)
    camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, distance, distance * 0.72), focus)
    rangePart.Parent = nil
    local chosen = towerInfo(selectedTower)
    if chosen then
        local p = padPart(chosen.pad)
        local unit = Config.Units[chosen.kind]
        local stats = Config.stats(chosen.kind, chosen.level)
        if p then showRange(p.Position, stats.range, Color3.fromRGB(unit.color[1], unit.color[2], unit.color[3])) end
        detailTitle.Text = unit.name .. " / Lv." .. chosen.level
        detailBody.Text = string.format("DAMAGE  %d      RANGE  %d\nINTERVAL  %.1fs\n%s\n\n%s", stats.damage, stats.range, stats.cooldown, unit.role, chosen.owner == player.UserId and "[E] Upgrade     [X] Sell (70%)" or "Owned by another player")
        local owns = chosen.owner == player.UserId
        upgradeButton.Visible, sellButton.Visible = owns, owns
        upgradeButton.Text = stats.upgradeCost and ("UPGRADE  " .. stats.upgradeCost) or "MAX LEVEL"
        sellButton.Text = "SELL " .. math.floor(Config.invested(chosen.kind, chosen.level) * Config.SellRatio)
    else
        upgradeButton.Visible, sellButton.Visible = false, false
        detailTitle.Text = selectedKind and Config.Units[selectedKind].name or "YOUR DEFENSE"
        detailBody.Text = "1  Choose a unit below\n2  Click a glowing numbered pad\n3  Start the wave\n\nFrost slows. Astral hits groups.\nUpgrade units for more damage."
        if selectedKind and UserInputService.MouseEnabled then
            local result = hitAt(UserInputService:GetMouseLocation())
            if result and result.Instance:GetAttribute("PadID") then
                local u = Config.Units[selectedKind]
                showRange(result.Instance.Position, u.range, Color3.fromRGB(u.color[1], u.color[2], u.color[3]))
            end
        end
    end
    for kind, card in ipairs(cards) do
        card.stroke.Transparency = selectedKind == kind and 0 or 0.85
        card.price.TextColor3 = latest and latest.cash < Config.Units[kind].cost and Color3.fromRGB(255, 145, 138) or Color3.new(1, 1, 1)
    end
    fxButton.Text = effects and "FX  ON" or "FX  OFF"
    if not latest then return end
    cashText.Text = latest.cash .. " CREDITS"
    waveText.Text = string.format("LANTERN VALLEY  /  WAVE %d OF %d", latest.wave, Config.MaxWaves)
    healthText.Text = string.format("SHRINE  %d / %d", latest.health, Config.BaseHealth)
    healthFill.Size = UDim2.fromScale(latest.health / Config.BaseHealth, 1)
    healthFill.BackgroundColor3 = latest.health > 30 and accent or Color3.fromRGB(255, 110, 123)
    local count = 0
    for _, t in ipairs(latest.towers) do if t.owner == player.UserId then count = count + 1 end end
    capText.Text = count .. " / " .. Config.MaxTowers .. " UNITS"
    aliveText.Text = latest.alive .. " enemies alive"
    speedButton.Text = "SPEED  x" .. latest.speed
    local phase = latest.phase
    phaseText.Text = phase == "BUILD" and "BUILD YOUR DEFENSE" or phase == "BREAK" and ("NEXT WAVE IN " .. latest.countdown .. "s") or phase == "VICTORY" and "VICTORY / SHRINE SAVED" or phase == "DEFEAT" and "DEFEAT / TRY A NEW PLAN" or "DEFEND THE SHRINE"
    startButton.Text = (phase == "VICTORY" or phase == "DEFEAT") and string.format("REPLAY VOTE  %d / %d", latest.votes, latest.players) or phase == "WAVE" and "WAVE IN PROGRESS" or phase == "BREAK" and "NEXT WAVE NOW" or "START WAVE  [SPACE]"
    startButton.BackgroundColor3 = phase == "WAVE" and muted or accent
end)
-- Connect listeners before requesting state so a fast server reply is not lost.
action:FireServer("Sync")
