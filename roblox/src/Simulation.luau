--!nonstrict
-- 2D Roblox-independent simulation. Formula/ability provenance: player.lua, objects.lua,
-- enemies.lua and arena.lua at the commit recorded in ../upstream.json.
local Data = require("./SourceData")
local Rules = require("./Rules")
local Simulation = {}
Simulation.__index = Simulation
local B, STEP = Rules.Bounds, 1/120
local function distance(a, b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function angle(a, b) return math.atan2(b.y-a.y, b.x-a.x) end
local function alive(list)
 for i = #list, 1, -1 do if list[i].dead then table.remove(list, i) end end
end
function Simulation.new(run, randomInt)
 assert(run.phase == "arena", "Start the run before creating an arena")
 local self = setmetatable({run = run, randomInt = randomInt, time = 0, accumulator = 0, units = {}, enemies = {},
  projectiles = {}, heals = {}, effects = {}, history = {}, events = {}, nextId = 0, wave = 0,
  maxWaves = Data.Waves[run.arena], spawning = false, paused = false, finished = false, kills = 0}, Simulation)
 for i, u in ipairs(run.party) do
  local stats = Rules.stats(u.character, u.level, run.party)
  table.insert(self.units, {id = self:id(), character = u.character, level = u.level, x = 240-(i-1)*Rules.Spacing,
   y = 135, r = 0, hp = stats.hp, stats = stats, timer = 0, flash = 0})
 end
 self:resetTrail()
 self:after(4, function() self:nextWave() end)
 return self
end
function Simulation:id() self.nextId += 1; return self.nextId end
function Simulation:after(delay, fn) table.insert(self.events, {at = self.time+delay, fn = fn}) end
function Simulation:effect(x, y, size, color, r)
 table.insert(self.effects, {id = self:id(), x = x, y = y, size = size, color = color, r = r or 0, life = 0.22})
end
function Simulation:resetTrail()
 self.history = {}
 for i = 1, #self.units do
  local u = self.units[i]
  table.insert(self.history, {x = u.x, y = u.y, r = u.r})
 end
end
function Simulation:targets(x, y, radius, excluded)
 local out = {}
 for _, e in ipairs(self.enemies) do
  if not e.dead and (not excluded or not excluded[e.id]) and (e.x-x)^2+(e.y-y)^2 <= radius^2 then table.insert(out, e) end
 end
 return out
end
function Simulation:nearest(x, y, radius)
 local best, bestDistance = nil, radius*radius
 for _, e in ipairs(self.enemies) do
  local d = (e.x-x)^2+(e.y-y)^2
  if not e.dead and d <= bestDistance then best, bestDistance = e, d end
 end
 return best
end
function Simulation:hit(enemy, damage)
 if enemy.dead then return end
 enemy.hp -= Rules.damage(damage, enemy.stats.defense)
 enemy.flash = 0.08
 if enemy.hp <= 0 then
  enemy.dead = true; self.kills += 1
  self:effect(enemy.x, enemy.y, 12, "red")
 end
end
function Simulation:spawnEnemy(x, y)
 local stats = Rules.enemyStats(self.run.arena)
 table.insert(self.enemies, {id = self:id(), x = x, y = y, r = 0, hp = stats.hp, stats = stats,
  vx = 0, vy = 0, flash = 0, contacts = {}})
end
function Simulation:spawnPack(x, y, count, delay)
 self:after(delay, function()
  self:effect(x, y, 20, "fg")
  table.insert(self.effects, {id = self:id(), x = x, y = y, size = 14, color = "red", r = math.pi/4, life = 1.125, marker = true})
 end)
 local offsets = {{12,-12},{12,12},{-12,12},{0,0},{-12,-12}}
 for i = 1, count do
  local o = offsets[(i-1)%5+1]
  self:after(delay + 1.125 + i*0.1, function()
   local occupied = false
   for _, u in ipairs(self.units) do if distance(u, {x=x+o[1],y=y+o[2]}) < 8 then occupied = true end end
   if not occupied then self:spawnEnemy(x+o[1], y+o[2]) end
  end)
 end
end
function Simulation:nextWave()
 if self.finished or self.spawning then return end
 self.wave += 1
 if self.wave > self.maxWaves then self.finished = true; self.run:complete(); return end
 self.spawning = true
 local count = 8+(self.wave-1)*2
 -- Standard opening-wave pattern. Rare distributed spawns remain a documented gap.
 local x = ({B.left+32,240,B.right-32})[self.randomInt(1,3)]
 self:spawnPack(x, 135, count, 0.5)
 self:after(0.5+1.125+count*0.1+0.25, function() self.spawning = false end)
end
function Simulation:projectile(unit, x, y, r, overrides)
 local c = unit.character
 local p = {id = self:id(), x = x, y = y, r = r, speed = 250, damage = unit.stats.dmg, color = Data.Colors[c],
  pierce = 0, chain = 0, ricochet = 0, owner = unit, hit = {}, age = 0, kind = "bolt", timer = 0}
 if c == "archer" then p.pierce = 1000; p.ricochet = if unit.level == 3 then 3 else 0 end
 if c == "scout" then p.chain = if unit.level == 3 then 6 else 3 end
 if c == "arcanist" then p.kind = "orb"; p.speed = 40; p.pierce = 10000; p.damage *= 0.2 end
 for k, value in pairs(overrides or {}) do p[k] = value end
 table.insert(self.projectiles, p)
end
function Simulation:area(unit, x, y, width)
 -- Upstream Area tests a rotated square of side 1.5 * visual width.
 local size = width*unit.stats.areaSize
 local targets = {}
 local c, s = math.cos(unit.r), math.sin(unit.r)
 for _, e in ipairs(self.enemies) do
  local dx, dy = e.x-x, e.y-y
  if not e.dead and math.abs(dx*c+dy*s) <= size*0.75+3.5 and math.abs(-dx*s+dy*c) <= size*0.75+3.5 then table.insert(targets, e) end
 end
 local damage = unit.stats.dmg*unit.stats.areaDamage
 if unit.character == "swordsman" then damage *= 1+0.15*#targets end
 for _, e in ipairs(targets) do self:hit(e, damage) end
 self:effect(x, y, size, Data.Colors[unit.character], unit.r)
end
function Simulation:cast(unit, target)
 unit.flash = 0.08
 if unit.character == "swordsman" then self:area(unit, unit.x, unit.y, 96)
 elseif unit.character == "magician" then self:area(unit, target.x, target.y, 32)
 else
  local r = angle(unit, target)
  self:projectile(unit, unit.x+14.4*math.cos(r), unit.y+14.4*math.sin(r), r)
 end
end
function Simulation:healOrb()
 if #self.heals >= 30 then return end
 for _ = 1, 40 do
  local x, y = self.randomInt(B.left+16,B.right-16), self.randomInt(B.top+16,B.bottom-16)
  if not self:nearest(x,y,9) then
   table.insert(self.heals, {id = self:id(), x = x, y = y, age = 0})
   return
  end
 end
end
function Simulation:updateUnits(dt, turn)
 local leader = self.units[1]
 if not leader then return end
 local speed = 0
 for _, u in ipairs(self.units) do speed += u.stats.speed end
 speed = math.floor(speed/#self.units)
 leader.r += math.clamp(turn or 0,-1,1)*Rules.TurnRate*dt
 leader.x += math.cos(leader.r)*speed*dt; leader.y += math.sin(leader.r)*speed*dt
 if leader.x < B.left+4.5 or leader.x > B.right-4.5 then leader.r = math.pi-leader.r; leader.x = math.clamp(leader.x,B.left+4.5,B.right-4.5); leader.flash = 0.08 end
 if leader.y < B.top+4.5 or leader.y > B.bottom-4.5 then leader.r = -leader.r; leader.y = math.clamp(leader.y,B.top+4.5,B.bottom-4.5); leader.flash = 0.08 end
 table.insert(self.history, 1, {x = leader.x, y = leader.y, r = leader.r})
 if #self.history > 512 then self.history[513] = nil end
 for index = 2, #self.units do
  local needed, traveled = (index-1)*Rules.Spacing, 0
  for i = 2, #self.history do
   local a, b = self.history[i-1], self.history[i]
   local length = distance(a,b)
   if length > 0 and traveled+length >= needed then
    local t = (needed-traveled)/length
    local u = self.units[index]
    u.x, u.y, u.r = a.x+(b.x-a.x)*t, a.y+(b.y-a.y)*t, a.r
    break
   end
   traveled += length
  end
 end
 for _, u in ipairs(self.units) do
  u.flash = math.max(0,u.flash-dt)
  local a = Rules.Abilities[u.character]
  if a.kind == "support" then continue end
  local multiplier = if a.kind == "heal" then 1 else u.stats.cooldown
  if u.character == "magician" and u.level == 3 and self.time >= 12 and self.time%12 < 6 then multiplier /= 1.5 end
  local cooldown = a.cooldown*multiplier
  u.timer = math.min(cooldown,u.timer+dt)
  if u.timer >= cooldown then
   if a.kind == "heal" then
    for _ = 1, (if u.level == 3 then 4 else 1) do self:healOrb() end
    u.timer = 0
   else
    local target = self:nearest(u.x,u.y,a.range)
    if u.character == "magician" then
     local targets = self:targets(u.x,u.y,a.range)
     target = if #targets > 0 then targets[self.randomInt(1,#targets)] else nil
    end
    if target then self:cast(u,target); u.timer = 0 end
   end
  end
 end
end
function Simulation:updateProjectiles(dt)
 -- Do not visit bolts appended by an orb until the next fixed step.
 local count = #self.projectiles
 for i = 1, count do
  local p = self.projectiles[i]
  p.age += dt
  p.x += math.cos(p.r)*p.speed*dt; p.y += math.sin(p.r)*p.speed*dt
  if p.x < B.left or p.x > B.right or p.y < B.top or p.y > B.bottom then
   if p.ricochet > 0 then
    if p.x < B.left or p.x > B.right then p.r = math.pi-p.r end
    if p.y < B.top or p.y > B.bottom then p.r = -p.r end
    p.x, p.y = math.clamp(p.x,B.left,B.right), math.clamp(p.y,B.top,B.bottom)
    p.ricochet -= 1
   else p.dead = true end
  end
  if p.age > 15 then p.dead = true end
  if not p.dead and p.kind == "orb" then
   p.timer += dt
   local cooldown = if p.owner.level == 3 then 0.54 else 0.8
   if p.timer >= cooldown then
    p.timer -= cooldown
    local targets = self:targets(p.x,p.y,128)
    for j = 1, math.min(#targets, if p.owner.level == 3 then 2 else 1) do
     local r = angle(p,targets[j])
     self:projectile(p.owner,p.x+8*math.cos(r),p.y+8*math.sin(r),r,{kind="bolt",speed=250,pierce=2,damage=p.owner.stats.dmg})
    end
   end
  end
  if p.dead then continue end
  for _, e in ipairs(self.enemies) do
   if not e.dead and not p.hit[e.id] and distance(p,e) < 7 then
    p.hit[e.id] = true
    self:hit(e,p.damage)
    if p.chain > 0 then
     p.chain -= 1
     local targets = self:targets(p.x,p.y,48,p.hit)
     if #targets > 0 then
      p.r = angle(p,targets[self.randomInt(1,#targets)]); p.speed *= 1.25
      if p.owner.character == "scout" and p.owner.level == 3 then p.damage *= 1.25 end
     end
     break
    elseif p.pierce > 0 then p.pierce -= 1
    else p.dead = true; break end
   end
  end
 end
 alive(self.projectiles)
end
function Simulation:updateEnemies(dt)
 local leader = self.units[1]
 if not leader then return end
 for _, e in ipairs(self.enemies) do
  if e.dead then continue end
  e.flash = math.max(0,e.flash-dt)
  e.r = angle(e,leader)
  e.x += (math.cos(e.r)*e.stats.speed+e.vx)*dt
  e.y += (math.sin(e.r)*e.stats.speed+e.vy)*dt
  e.vx *= math.exp(-8*dt); e.vy *= math.exp(-8*dt)
  e.x = math.clamp(e.x,B.left+3.5,B.right-3.5); e.y = math.clamp(e.y,B.top+3.5,B.bottom-3.5)
  for _, u in ipairs(self.units) do
   local touching = distance(u,e) < 8
   if touching and not e.contacts[u.id] and not u.dead then
    self:hit(e,u.stats.dmg*(if u.character == "vagrant" then 2 else 1))
    u.hp -= Rules.damage(e.stats.dmg,u.stats.defense); u.flash = 0.12
    local r = angle(u,e)
    e.vx, e.vy = math.cos(r)*150, math.sin(r)*150
    if u.hp <= 0 then u.dead = true end
   end
   e.contacts[u.id] = touching or nil
  end
 end
 -- Light separation replaces Box2D contact response in this first port.
 for i = 1, #self.enemies do
  local a = self.enemies[i]
  for j = i+1, #self.enemies do
   local b = self.enemies[j]
   local d = distance(a,b)
   if d > 0 and d < 7 then
    local push = (7-d)*0.5
    local dx,dy = (a.x-b.x)/d*push,(a.y-b.y)/d*push
    a.x += dx; a.y += dy; b.x -= dx; b.y -= dy
   end
  end
 end
 alive(self.enemies)
 local previousCount = #self.units
 alive(self.units)
 if #self.units ~= previousCount then
  self:resetTrail()
  for _, u in ipairs(self.units) do u.stats = Rules.stats(u.character,u.level,self.units) end
 end
 if #self.units == 0 then self.finished = true; self.run:lose() end
end
function Simulation:updateHeals(dt)
 for _, orb in ipairs(self.heals) do
  orb.age += dt
  for _, u in ipairs(self.units) do
   if orb.age > 0.5 and distance(u,orb) < 8 then
    local lowest = self.units[1]
    for _, candidate in ipairs(self.units) do if candidate.hp/candidate.stats.hp < lowest.hp/lowest.stats.hp then lowest = candidate end end
    lowest.hp = math.min(lowest.stats.hp,lowest.hp+0.2*lowest.stats.hp)
    self:effect(lowest.x,lowest.y,12,"green")
    orb.dead = true; break
   end
  end
 end
 alive(self.heals)
end
function Simulation:step(dt,turn)
 self.time += dt
 local pending = self.events; self.events = {}
 for _, event in ipairs(pending) do
  if event.at <= self.time then event.fn() else table.insert(self.events,event) end
 end
 if self.finished then return end
 self:updateUnits(dt,turn)
 self:updateProjectiles(dt)
 self:updateEnemies(dt)
 self:updateHeals(dt)
 for _, effect in ipairs(self.effects) do effect.life -= dt; if effect.life <= 0 then effect.dead = true end end
 alive(self.effects)
 if not self.finished and self.wave > 0 and not self.spawning and #self.enemies == 0 then self:nextWave() end
end
function Simulation:update(dt,turn)
 if self.paused or self.finished then return end
 -- Fixed steps prevent large frames from tunnelling bullets through enemies.
 self.accumulator += math.clamp(dt,0,0.25)
 while self.accumulator >= STEP and not self.finished do self:step(STEP,turn); self.accumulator -= STEP end
end
return Simulation
