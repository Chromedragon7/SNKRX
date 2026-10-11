-- Behavioral tests against source-derived expected values; no Roblox services needed.
local Data = require("../src/SourceData")
local Rules = require("../src/Rules")
local Run = require("../src/Run")
local Simulation = require("../src/Simulation")
local count = 0
local function test(name, fn)
 local ok, message = pcall(fn)
 if not ok then error(name .. ": " .. tostring(message)) end
 count += 1; print("PASS " .. name)
end
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a).." ~= "..tostring(b)) end
local function rng(seed)
 return function(a,b) seed=(seed*16807)%2147483647; return a+seed%(b-a+1) end
end
local function arena(character,level)
 local r=Run.new(rng(20));r.party={{character=character or "vagrant",level=level or 1,copies=1}}
 assert(r:start());return Simulation.new(r,rng(32)),r
end
test("original roster and tier pools remain intact",function()
 local n=0
 for tier, pool in ipairs(Data.TierPools) do for _,c in ipairs(pool) do
  assert(Data.Names[c] and Data.Colors[c] and Data.Classes[c]);equal(Data.Tiers[c],tier);n+=1
  assert(Rules.Palette[Data.Colors[c]], "Missing hero color: "..c)
 end end
 equal(n,52);equal(#Rules.Playable,8);equal(Data.ShopOdds[1][1],70)
end)
test("source-derived level-one stats",function()
 local s=Rules.stats("swordsman",1,{{character="swordsman"}})
 near(s.hp,140);near(s.dmg,11);near(s.defense,31.25);near(s.speed,67.5);near(s.cooldown,1/0.9)
 local v=Rules.stats("vagrant",1,{{character="vagrant"}})
 near(v.hp,150);near(v.dmg,11.5);near(v.speed,93.75);near(v.cooldown,1/1.15)
end)
test("class thresholds, including explorer and sorcerer",function()
 local levels=Rules.classLevels({{character="vagrant"},{character="swordsman"},{character="barbarian"},{character="squire"},{character="arcanist"},{character="witch"}})
 equal(levels.explorer,1);equal(levels.warrior,1);equal(levels.sorcerer,1);equal(levels.psyker,0)
end)
test("damage and NG+0 seeker curve",function()
 near(Rules.damage(10,25),8);near(Rules.damage(10,-15),10*(2-100/85))
 local s=Rules.enemyStats(1);near(s.hp,12.5);near(s.dmg,4.5);near(s.speed,21)
 s=Rules.enemyStats(2);near(s.hp,20.75);near(s.dmg,7);near(s.speed,21.9)
end)
test("shop rejects a support-only draw",function()
 local r=Run.new(function() return 8 end)
 equal(r.cards[1],"vagrant");equal(r.gold,3)
end)
test("3/9-copy upgrades and reserve sale prices",function()
 local r=Run.new(rng(1));r.gold=20
 for i=1,9 do
  r.cards[1]="swordsman";assert(r:buy(1));equal(r.party[1].copies,i)
  equal(r.party[1].level,if i<3 then 1 elseif i<9 then 2 else 3)
  equal(r:salePrice(1),({1,2,2,3,4,4,5,6,6})[i])
 end
 r.cards[1]="swordsman";assert(not r:buy(1));equal(r.gold,11)
 assert(r:sell(1));equal(r.gold,17);equal(#r.party,0)
end)
test("seven unique heroes and upgrades at capacity",function()
 local r=Run.new(rng(3));r.gold=100
 for i=1,7 do r.cards[1]=Rules.Playable[i];assert(r:buy(1)) end
 r.cards[1]="merchant";assert(not r:buy(1))
 r.cards[1]="vagrant";assert(r:buy(1));equal(#r.party,7)
 local first=r.party[1];assert(r:move(1,1));equal(r.party[2],first)
end)
test("shop lock and pre-reward interest",function()
 local r=Run.new(rng(4));r.party={{character="vagrant",level=1,copies=1},{character="merchant",level=1,copies=1}};r.gold=20
 equal(Rules.interest(r.gold,r.party),6)
 r:toggleLock();local cards=r.cards;assert(r:start());r:complete()
 equal(r.gold,29);equal(r.arena,2);equal(r.cards,cards);equal(r.phase,"shop")
 r:complete();equal(r.gold,29)
end)
test("shop rejects mutations during battle and empty entry",function()
 local r=Run.new(rng(5));assert(not r:start())
 r.party={{character="cleric",level=1,copies=1}};assert(not r:start())
 r.party={{character="vagrant",level=1,copies=1}};assert(r:start())
 assert(not r:buy(1));assert(not r:reroll());assert(not r:sell(1));assert(not r:move(1,1))
end)
test("steering matches original angular velocity",function()
 local s=arena();s.events={};s:update(0.1,1)
 near(s.units[1].r,Rules.TurnRate*0.1)
end)
test("walls reflect the snake instead of killing it",function()
 local s=arena();s.events={};local u=s.units[1];u.x=427.49;u.r=0;s:update(0.1,0)
 assert(math.cos(u.r)<0);assert(u.x<427.5);near(u.hp,u.stats.hp)
end)
test("followers use path distance and stay finite",function()
 local s,r=arena();r.phase="shop";r.party[2]={character="archer",level=1,copies=1};assert(r:start());s=Simulation.new(r,rng(3));s.events={}
 for _=1,60 do s:update(1/60,0.4) end
 local a,b=s.units[1],s.units[2];local d=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2)
 assert(d>9 and d<10.5);assert(b.r==b.r)
end)
test("fixed simulation is independent of render rate",function()
 local a=arena();local b=arena();a.events={};b.events={}
 for _=1,60 do a:update(1/60,0.25) end
 for _=1,30 do b:update(1/30,0.25) end
 near(a.units[1].x,b.units[1].x);near(a.units[1].y,b.units[1].y)
end)
test("pause freezes combat and scheduled spawns",function()
 local s=arena();s.paused=true;s:update(0.25,1);equal(s.time,0);equal(s.wave,0)
end)
test("vagrant auto-targets with original cooldown",function()
 local s=arena();s.events={};s:spawnEnemy(270,135)
 local u=s.units[1];s:updateUnits(2/1.15,0)
 -- Test cast dispatch separately from movement (the snake moved out of range).
 u.x=240;u.y=135;u.timer=2;s:updateUnits(0,0)
 assert(#s.projectiles>0);near(s.projectiles[1].damage,11.5)
end)
test("swordsman damage grows with area target count",function()
 local s=arena("swordsman");s.events={};s:spawnEnemy(245,135);s:spawnEnemy(250,135)
 for _,e in ipairs(s.enemies) do e.hp=100 end
 s:area(s.units[1],240,135,96)
 near(s.enemies[1].hp,100-Rules.damage(11*1.3,25))
end)
test("scout level-three chain increases damage",function()
 local s=arena("scout",3);s.events={};s:spawnEnemy(250,135);s:spawnEnemy(270,135)
 s:projectile(s.units[1],250,135,0);local p=s.projectiles[1];local base=p.damage
 s:updateProjectiles(0);equal(p.chain,5);near(p.damage,base*1.25)
end)
test("archer level-three wall ricochets",function()
 local s=arena("archer",3);s.events={};s:projectile(s.units[1],431,100,0);local p=s.projectiles[1]
 s:updateProjectiles(0.01);equal(p.ricochet,2);assert(math.cos(p.r)<0);assert(not p.dead)
end)
test("arcanist orb emits piercing bolts",function()
 local s=arena("arcanist",3);s.events={};s:spawnEnemy(270,135);s:spawnEnemy(275,145)
 s:projectile(s.units[1],240,135,0);local orb=s.projectiles[1];orb.timer=0.54
 s:updateProjectiles(0);equal(#s.projectiles,3);equal(s.projectiles[2].pierce,2);near(orb.damage,s.units[1].stats.dmg*0.2)
end)
test("healing orb heals lowest percentage hero",function()
 local s,r=arena();r.phase="shop";r.party[2]={character="cleric",level=1,copies=1};assert(r:start());s=Simulation.new(r,rng(3));s.events={}
 local a,b=s.units[1],s.units[2];a.hp=a.stats.hp*0.9;b.hp=b.stats.hp*0.25
 s.heals={{id=500,x=a.x,y=a.y,age=1}};s:updateHeals(0)
 near(b.hp,b.stats.hp*0.45);near(a.hp,a.stats.hp*0.9);equal(#s.heals,0)
end)
test("dead leader is replaced and final death ends run",function()
 local s,r=arena();r.phase="shop";r.party[2]={character="archer",level=1,copies=1};assert(r:start());s=Simulation.new(r,rng(3));s.events={}
 s.units[1].dead=true;s:updateEnemies(0);equal(s.units[1].character,"archer")
 s.units[1].dead=true;s:updateEnemies(0);equal(r.phase,"lost");assert(s.finished)
end)
test("first arena has two waves, reward and shop transition",function()
 local s,r=arena();local spawned=0;local original=s.spawnEnemy
 function s:spawnEnemy(x,y) spawned+=1;original(self,x,y) end
 for _=1,2400 do for _,e in ipairs(s.enemies) do e.dead=true end;s:update(1/60,0.5);if s.finished then break end end
 equal(spawned,18);equal(r.phase,"shop");equal(r.arena,2);equal(r.gold,6)
end)
test("second arena completion is explicitly bounded",function()
 local s,r=arena();r.arena=2;s=Simulation.new(r,rng(12))
 for _=1,3000 do for _,e in ipairs(s.enemies) do e.dead=true end;s:update(1/60,0.5);if s.finished then break end end
 equal(r.phase,"complete")
end)
test("all eight heroes survive simulation smoke tests",function()
 for _,c in ipairs(Rules.Playable) do
  local r=Run.new(rng(17));r.party={{character=c,level=3,copies=9},{character="swordsman",level=3,copies=9}};assert(r:start())
  local s=Simulation.new(r,rng(39))
  for _=1,3600 do s:update(1/60,0.4);if s.finished then break end end
  assert(s.time>4);assert(#s.projectiles<500)
  for _,u in ipairs(s.units) do assert(u.x==u.x and u.y==u.y) end
 end
end)
print(string.format("%d behavioral tests passed.",count))
