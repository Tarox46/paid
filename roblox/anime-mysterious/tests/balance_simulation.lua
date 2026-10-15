-- A deterministic solo strategy with the shipped stats; headless, no engine physics.
for _,obj in ipairs(Objects) do if obj.Name=="Action" then Action=obj end end
local player={UserId=201}
TestPlayers.list={player}
TestPlayers.PlayerAdded:Fire(player)
local plan={1,1,1,2,3,1,2,3,1,3,1,2}
local function build()
    local total=#State(player).troops
    for index=total+1,#plan do
        local kind=plan[index]
        if State(player).cash<TestConfig.Units[kind].cost then break end
        Command(player,"Recruit",kind)
    end
    for level=1,3 do
        for _,troop in ipairs(State(player).troops) do
            if troop.level==level and State(player).cash>=TestConfig.stats(troop.kind,troop.level).upgradeCost then Command(player,"Upgrade",troop.id) end
        end
    end
end
for wave=1,8 do
    build()
    Command(player,"Start")
    local steps=0
    repeat Tick(0.1); steps=steps+1 until State(player).phase~="WAVE" or steps>2000
    local s=State(player)
    print(string.format('Solo simulation wave %d: %s, health %d, cash %d, units %d',wave,s.phase,s.health,s.cash,#s.troops))
    assert(s.phase==(wave==8 and "VICTORY" or "BREAK"),"default-stat solo strategy must clear wave "..wave)
end
print('PASS: default-stat solo strategy completes all 8 waves without modifying combat stats')
