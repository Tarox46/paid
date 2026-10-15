for _,obj in ipairs(Objects) do if obj.Name=="Action" then Action=obj end end
local player={UserId=301}
TestPlayers.list={player}
TestPlayers.PlayerAdded:Fire(player)
-- Force a lethal opponent for the death/revival scenario, not for shipped balance.
local defaultWave=TestConfig.wave
TestConfig.wave=function(index)
    local wave=defaultWave(index)
    wave.damage=1000
    return wave
end
Command(player,"Recruit",2)
local recruited=State(player).troops[1]
assert(recruited.status=="READY" and recruited.distance==State(player).routeLength)
Command(player,"Start")
Tick(2)
local marching=State(player).troops[1]
assert(marching.distance<recruited.distance and marching.distance>0 and marching.status=="MARCHING", "allies must walk from OUR base toward the enemy")
local seenFight,seenDamage,seenDeath=false,false,false
for _=1,1000 do
    Tick(0.1)
    local state=State(player)
    local t=state.troops[1]
    if t.status=="FIGHTING" then seenFight=true end
    if t.hp<t.maxHp then seenDamage=true end
    if t.status=="DOWN" then seenDeath=true; break end
end
assert(seenFight and seenDamage and seenDeath,"allies must engage, take damage, and fall")
local allyFX,enemyFX=false,false
for _,fx in ipairs(Effects) do if fx.kind==0 then enemyFX=true else allyFX=true end end
assert(allyFX and enemyFX,"both armies must attack")
local down=State(player).troops[1]
assert(down.hp==0 and down.status=="DOWN")
local model
for _,obj in ipairs(Objects) do if obj.Name=="Troop_"..down.id then model=obj end end
assert(model and model.Parent==nil,"fallen character leaves the battlefield")
Command(player,"Upgrade",down.id)
assert(State(player).troops[1].level==2 and State(player).troops[1].hp==0,"upgrading a fallen character must not revive it mid-wave")
local steps=0
repeat Tick(0.1); steps=steps+1 until State(player).phase~="WAVE" or steps>1000
assert(State(player).phase=="BREAK")
Command(player,"Start")
local revived=State(player).troops[1]
assert(revived.hp==revived.maxHp and revived.level==2 and revived.distance==State(player).routeLength,"new wave restores characters at our base without losing upgrades")
assert(model.Parent~=nil)
Tick(0.5)
Command(player,"Sell",revived.id)
Command(player,"Recruit",1)
local fresh=State(player).troops[1]
assert(fresh.distance==State(player).routeLength and fresh.status=="DEPLOYING","mid-wave recruits must start at our base")
Tick(1)
assert(State(player).troops[1].distance<fresh.distance)
-- Check no command lets the client choose damage or a frontline spawn location.
local count=#State(player).troops
Command(player,"Place",1,1)
assert(#State(player).troops==count,"legacy pad placement is disabled")
print('PASS: base-origin movement, opposing attacks, damage, death, model removal, no upgrade resurrection, upgraded revival next wave and mid-wave deployment')
