-- Minimal headless service model for server rule tests. Not a Roblox engine substitute.
local function signal()
    local event = {listeners = {}}
    function event:Connect(callback) self.listeners[#self.listeners + 1] = callback end
    function event:Fire(...) for _, callback in ipairs(self.listeners) do callback(...) end end
    return event
end
local vector = {}
vector.__index = function(v, key)
    if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
    if key == "Lerp" then return function(a,b,t) return a + (b-a)*t end end
end
Vector3 = {new = function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vector) end}
vector.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__mul = function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vector.__div = function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
-- Position-only CFrame model: tests validate lane simulation, not 3D rotation.
local frame = {}
frame.__index = frame
local function makeFrame(position) return setmetatable({Position=position},frame) end
frame.__mul = function(a,b) return makeFrame(a.Position+b.Position) end
CFrame = {
    lookAt = function(position) return makeFrame(position) end,
    new = function(x,y,z)
        return makeFrame(type(x)=="table" and x or Vector3.new(x or 0,y or 0,z or 0))
    end,
    Angles = function() return makeFrame(Vector3.new(0,0,0)) end,
}
Color3 = {new=function(...) return {...} end, fromRGB=function(...) return {...} end}
UDim2 = {fromOffset=function(...) return {...} end, fromScale=function(...) return {...} end}
local function enum() return setmetatable({}, {__index=function(self,key) local result=enum(); rawset(self,key,result); return result end}) end
Enum = enum()
Objects, Messages, Effects = {}, {}, {}
Instance = {new = function(class, parent)
    local obj = {ClassName=class, Parent=parent, attributes={}}
    function obj:SetAttribute(key,value) self.attributes[key]=value end
    function obj:GetAttribute(key) return self.attributes[key] end
    function obj:Destroy() self.destroyed=true end
    function obj:WaitForChild() return {} end
    if class == "RemoteEvent" then
        obj.OnServerEvent = signal()
        function obj:FireClient(player,state) Messages[player.UserId] = state end
        function obj:FireAllClients(origin,target,kind) Effects[#Effects+1]={origin=origin,target=target,kind=kind} end
    end
    setmetatable(obj, {
        __newindex=function(self,key,value)
            if key=="CFrame" then rawset(self,"Position",value.Position); rawset(self,"_CFrame",value)
            else rawset(self,key,value) end
        end,
        __index=function(self,key) if key=="CFrame" then return rawget(self,"_CFrame") end end,
    })
    Objects[#Objects+1]=obj
    return obj
end}
TestPlayers = {list={}, PlayerAdded=signal(), PlayerRemoving=signal()}
function TestPlayers:GetPlayers() return self.list end
Heartbeat = signal()
local services = {Players=TestPlayers, ReplicatedStorage=Instance.new("Folder"), RunService={Heartbeat=Heartbeat}, Lighting={}}
game = {GetService=function(_,name) return assert(services[name],name) end}
workspace = Instance.new("Workspace")
require = function() return TestConfig end
TestClock = 0
os.clock = function() return TestClock end
function Tick(seconds)
    for _=1,math.ceil(seconds/0.1) do TestClock=TestClock+0.1; Heartbeat:Fire(0.1) end
end
function Command(player,command,arg,kind)
    TestClock=TestClock+0.2
    Action.OnServerEvent:Fire(player,command,arg,kind)
end
function State(player)
    Command(player,"Sync")
    return Messages[player.UserId]
end
