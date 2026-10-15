-- A deterministic solo strategy with the shipped stats; headless, no engine physics.
for _,obj in ipairs(Objects) do if obj.Name=="Action" then Action=obj end end
local player={UserId=201}
TestPlayers.list={player}
TestPlayers.PlayerAdded:Fire(player)
local plan={{3,1},{6,1},{10,1},{9,3},{4,2},{12,3},{7,2},{2,1},{11,3},{5,1},{8,1},{13,1}}
local function build()
    for _,entry in ipairs(plan) do
        local occupied=false
        for _,tower in ipairs(State(player).towers) do if tower.pad==entry[1] then occupied=true end end
        if not occupied and State(player).cash>=TestConfig.Units[entry[2]].cost then Command(player,"Place",entry[1],entry[2]) end
    end
    for level=1,3 do
        for _,tower in ipairs(State(player).towers) do
            if tower.level==level and State(player).cash>=TestConfig.stats(tower.kind,tower.level).upgradeCost then Command(player,"Upgrade",tower.id) end
        end
    end
end
for wave=1,8 do
    build()
    Command(player,"Start")
    local steps=0
    repeat Tick(0.1); steps=steps+1 until State(player).phase~="WAVE" or steps>2000
    local s=State(player)
    print(string.format('Solo simulation wave %d: %s, health %d, cash %d, units %d',wave,s.phase,s.health,s.cash,#s.towers))
    assert(s.phase==(wave==8 and "VICTORY" or "BREAK"),"default-stat solo strategy must clear wave "..wave)
end
print('PASS: default-stat solo strategy completes all 8 waves without modifying combat stats')
