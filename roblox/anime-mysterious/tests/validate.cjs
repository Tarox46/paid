const fs = require('node:fs');
const path = require('node:path');
const lua = require('fengari');
const parse = require('luaparse');
const {lua: l, lauxlib: aux, lualib: lib, to_luastring: str, to_jsstring: js} = lua;
const root = path.resolve(__dirname, '..');
for (const file of ['Config.lua','Server.server.lua','Client.client.lua']) {
  parse.parse(fs.readFileSync(path.join(root,'src',file),'utf8'), {luaVersion:'5.3'});
  console.log('PASS syntax:', file);
}
const L = aux.luaL_newstate();
lib.luaL_openlibs(L);
function run(source, name) {
  if (aux.luaL_loadbuffer(L,str(source),null,str(name)) !== l.LUA_OK || l.lua_pcall(L,0,0,0) !== l.LUA_OK) {
    throw new Error(js(l.lua_tostring(L,-1)));
  }
}
const config = fs.readFileSync(path.join(root,'src/Config.lua'),'utf8');
run('TestConfig = (function()\n'+config+'\nend)()', 'Config');
run(`
for kind, unit in ipairs(TestConfig.Units) do
 for level=1,4 do
  local stats=TestConfig.stats(kind,level)
  assert(stats.damage>0 and stats.range>0 and stats.cooldown>0)
  assert(TestConfig.invested(kind,level)>=unit.cost)
  if level<4 then assert(stats.upgradeCost>0) else assert(stats.upgradeCost==nil) end
 end
end
for wave=1,TestConfig.MaxWaves do
 local w=TestConfig.wave(wave)
 assert(w.count>0 and w.health>0 and w.speed>0 and w.reward>0)
 assert(w.boss==(wave==TestConfig.MaxWaves))
end
print('PASS: unit progression, upgrade cap and wave configuration')
`, 'config assertions');
run(fs.readFileSync(path.join(__dirname,'engine_mock.lua'),'utf8'),'mock services');
run(fs.readFileSync(path.join(root,'src/Server.server.lua'),'utf8'),'server');
run(fs.readFileSync(path.join(__dirname,'server_rules.lua'),'utf8'),'server rules');
l.lua_close(L);
const balance = aux.luaL_newstate();
lib.luaL_openlibs(balance);
for (const [name, source] of [
  ['Config', 'TestConfig = (function()\n'+config+'\nend)()'],
  ['mock services', fs.readFileSync(path.join(__dirname,'engine_mock.lua'),'utf8')],
  ['server', fs.readFileSync(path.join(root,'src/Server.server.lua'),'utf8')],
  ['solo balance', fs.readFileSync(path.join(__dirname,'balance_simulation.lua'),'utf8')]
]) {
  if (aux.luaL_loadbuffer(balance,str(source),null,str(name)) !== l.LUA_OK || l.lua_pcall(balance,0,0,0) !== l.LUA_OK) {
    throw new Error(js(l.lua_tostring(balance,-1)));
  }
}
l.lua_close(balance);
