for _,obj in ipairs(Objects) do if obj.Name=="Action" then Action=obj end end
assert(Action, "Action remote must exist")
local a,b={UserId=101},{UserId=102}
TestPlayers.list={a,b}
TestPlayers.PlayerAdded:Fire(a); TestPlayers.PlayerAdded:Fire(b)
assert(State(a).cash==900)
-- Hostile input must neither spend funds nor create towers.
for _,bad in ipairs({0,-1,1.5,999,"1",{},math.huge,0/0}) do Command(a,"Place",bad,1) end
assert(#State(a).towers==0 and State(a).cash==900)
Command(a,"Place",1,1)
local state=State(a)
assert(state.cash==600 and #state.towers==1)
local tower=state.towers[1].id
Command(b,"Sell",tower)
assert(#State(a).towers==1 and State(b).cash==900, "ownership guard")
Command(b,"Place",1,1)
assert(#State(b).towers==1 and State(b).cash==900, "occupied pad guard")
Command(a,"Upgrade",tower)
assert(State(a).cash==255 and State(a).towers[1].level==2)
Command(a,"Upgrade",tower)
assert(State(a).cash==255 and State(a).towers[1].level==2, "insufficient cash guard")
Command(a,"Sell",tower)
assert(State(a).cash==706 and #State(a).towers==0, "refund includes upgrades")
Command(a,"Speed")
assert(State(a).speed==2)
Command(b,"Speed")
assert(State(b).speed==2, "non-host cannot change shared speed")
Command(a,"Speed")
Command(a,"Start"); Command(b,"Start")
assert(State(a).wave==1, "duplicate start must not skip waves")
local elapsed=0
repeat Tick(0.1); elapsed=elapsed+0.1 until State(a).phase~="WAVE" or elapsed>60
assert(State(a).phase=="BREAK" and State(a).health==36, "leaks and wave completion")
Command(a,"Start")
Tick(50)
assert(State(a).phase=="DEFEAT" and State(a).health==0)
Command(a,"Restart")
assert(State(a).phase=="DEFEAT" and State(a).votes==1, "replay requires every player")
Command(b,"Restart")
assert(State(a).phase=="BUILD" and State(a).cash==900 and State(a).health==100)
-- Accelerate combat only for the lifecycle regression: not a balance/playability claim.
TestConfig.Units[1].damage=1000000
TestConfig.Units[1].range=300
TestConfig.Units[1].cooldown=0.01
Command(a,"Place",1,1)
for wave=1,8 do
    Command(a,"Start")
    local s=State(a)
    assert(s.wave==wave and s.phase=="WAVE")
    local steps=0
    repeat Tick(0.1); steps=steps+1; s=State(a) until s.phase~="WAVE" or steps>500
    assert(s.phase==(wave==8 and "VICTORY" or "BREAK"), "wave "..wave.." completes")
end
assert(State(a).health==100 and State(a).cash>900 and State(b).cash>900)
Command(a,"Place",2,1)
assert(#State(a).towers==1, "terminal phase rejects placement")
Command(a,"Restart"); Command(b,"Restart")
assert(State(a).phase=="BUILD" and #State(a).towers==0)
Command(a,"Place",1,1)
TestPlayers.list={b}
TestPlayers.PlayerRemoving:Fire(a)
assert(#State(b).towers==0, "departing player's towers are removed")
print("PASS: server placement, invalid inputs, ownership, upgrades, insufficient funds, refund, speed authority, duplicate start, leaks, defeat, replay votes, all 8 wave transitions, boss-wave lifecycle, victory, shared rewards, terminal actions and departure cleanup")
