local Config = {}
Config.StartingCash = 900
Config.BaseHealth = 100
Config.MaxTowers = 12
Config.MaxWaves = 8
Config.SellRatio = 0.7
Config.Units = {
    { name = "Ember Ronin", role = "FAST / SINGLE TARGET", cost = 300, damage = 18, range = 24, cooldown = 0.7, color = {255, 123, 79} },
    { name = "Frost Oracle", role = "SLOW / CROWD CONTROL", cost = 400, damage = 12, range = 28, cooldown = 1.2, slow = 0.5, color = {92, 217, 255} },
    { name = "Astral Warden", role = "SPLASH / AREA DAMAGE", cost = 550, damage = 40, range = 32, cooldown = 2.2, splash = 10, color = {186, 140, 255} },
}
function Config.stats(kind, level)
    local unit = Config.Units[kind]
    if not unit or level < 1 or level > 4 then return nil end
    return {
        damage = math.floor(unit.damage * (1 + (level - 1) * 0.65)),
        range = unit.range + (level - 1) * 3,
        cooldown = unit.cooldown,
        upgradeCost = level < 4 and math.floor(unit.cost * (0.7 + level * 0.45)) or nil,
    }
end
function Config.invested(kind, level)
    local total = Config.Units[kind].cost
    for previous = 1, level - 1 do total = total + Config.stats(kind, previous).upgradeCost end
    return total
end
function Config.wave(index)
    return {
        count = 6 + index * 2,
        health = math.floor(45 * 1.32 ^ (index - 1)),
        speed = 9 + index * 0.6,
        reward = 22 + index * 3,
        clearReward = 100 + index * 35,
        boss = index == Config.MaxWaves,
    }
end
function Config.validInteger(value, minimum, maximum)
    return type(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum
end
return Config
