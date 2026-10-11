--!strict
-- Port of the formulas in main.lua, objects.lua and buy_screen.lua.
-- Original code: MIT, Copyright (c) 2021 a327ex. See ../../LICENSE.
local Data: any = require("./SourceData")
local Rules = {}
Rules.Width, Rules.Height = 480, 270
Rules.Bounds = {left = 48, top = 27, right = 432, bottom = 243}
Rules.TurnRate, Rules.Spacing, Rules.MaxParty = 1.66*math.pi, 10.4, 7
-- An explicitly bounded first port milestone. No unimplemented heroes in the shop.
Rules.LastArena = 2
Rules.Playable = Data.TierPools[1]
Rules.Palette = {bg = "303030", fg = "dadada", yellow = "facf00", orange = "f07021",
 blue = "019bd6", blue2 = "4778ba", green = "8bbf40", red = "e91d39", purple = "8e559e", yellow2 = "f59f10",
 white = "ffffff", black = "000000", fg_alt = "b0a89f"}
Rules.Abilities = {
 vagrant = {range = 96, cooldown = 2, kind = "projectile"},
 swordsman = {range = 48, cooldown = 3, kind = "area", area = 96},
 magician = {range = 96, cooldown = 2, kind = "area", area = 32},
 archer = {range = 160, cooldown = 2, kind = "projectile"},
 scout = {range = 64, cooldown = 2, kind = "projectile"},
 cleric = {range = 0, cooldown = 8, kind = "heal"},
 arcanist = {range = 128, cooldown = 4, kind = "orb"},
 merchant = {range = 0, cooldown = 0, kind = "support"},
}
Rules.Descriptions = {
 vagrant = "Shoots at nearby enemies. Explorer: +15% damage and attack speed per active class.",
 swordsman = "Strikes an area. +15% damage per enemy hit. Level 3: double damage.",
 magician = "Blasts an area around a random enemy. Level 3: periodic +50% attack speed.",
 archer = "Fires piercing arrows. Level 3: arrows bounce off walls three times.",
 scout = "Throws knives that chain three times. Level 3: six chains, +25% damage per chain.",
 cleric = "Creates a healing orb every 8 seconds. Pick it up to heal the most injured hero.",
 arcanist = "Fires slow orbs that shoot piercing bolts. Level 3: faster, double bolt volleys.",
 merchant = "Earns extra interest: +1 per 10 gold, up to +10. Level 3 item reroll awaits the item port.",
}
function Rules.hasClass(character: string, class: string): boolean
 return table.find(Data.Classes[character], class) ~= nil
end
function Rules.classLevels(party: {any}): ({[string]: number}, {[string]: number})
 local counts: {[string]: number} = {}
 for _, unit in ipairs(party) do
  for _, class in ipairs(Data.Classes[unit.character]) do counts[class] = (counts[class] or 0) + 1 end
 end
 local levels: {[string]: number} = {}
 for class, n in pairs(counts) do
  if class == "explorer" then levels[class] = 1
  elseif class == "sorcerer" then levels[class] = math.min(3, math.floor(n/2))
  elseif table.find({"ranger", "warrior", "mage", "nuker", "rogue"}, class) then levels[class] = math.min(2, math.floor(n/3))
  else levels[class] = math.min(2, math.floor(n/2)) end
 end
 return levels, counts
end
function Rules.stats(character: string, level: number, party: {any}): any
 local m: {[string]: number} = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1}
 for _, class in ipairs(Data.Classes[character]) do
  for key, value in pairs(Data.ClassStats[class]) do m[key] *= value end
 end
 local sets = Rules.classLevels(party)
 local active = 0
 for _, value in pairs(sets) do if value > 0 then active += 1 end end
 local explorer = if Rules.hasClass(character, "explorer") then 1 + 0.15*active else 1
 -- Preserve executable upstream values even where its tooltip disagrees.
 local vagrant = if character == "vagrant" and level == 3 then 1 + 0.1*active else 1
 local enchanter = if sets.enchanter == 2 then 1.25 elseif sets.enchanter == 1 then 1.15 else 1
 local warrior = if Rules.hasClass(character, "warrior") then 25*(sets.warrior or 0) else 0
 return {hp = 100*2^(level-1)*m.hp, dmg = 10*2^(level-1)*m.dmg*explorer*vagrant*enchanter*(if character == "swordsman" and level == 3 then 2 else 1),
  cooldown = 1/(m.aspd*explorer*vagrant), speed = 75*m.mvspd, defense = (25+warrior)*m.def,
  areaDamage = m.area_dmg, areaSize = m.area_size}
end
function Rules.damage(amount: number, defense: number): number
 return math.max(0, amount*(if defense >= 0 then 100/(100+defense) else 2-100/(100+defense)))
end
function Rules.enemyStats(arena: number): any
 local y = ({0,1,3,3,4,6,5,6,9,7,8,12,10,11,15,12,13,18,16,17,21,17,20,24,25})[arena]
 assert(y, "Arena outside imported NG+0 curve")
 return {hp = (25+16.5*y)*Data.ClassStats.seeker.hp, dmg = 4.5+2.5*y, speed = (70+3*y)*Data.ClassStats.seeker.mvspd, defense = 25}
end
function Rules.interest(gold: number, party: {any}): number
 local merchant = false
 for _, u in ipairs(party) do if u.character == "merchant" then merchant = true end end
 return math.min(math.floor(gold/5), 5) + (if merchant then math.min(math.floor(gold/10),10) else 0)
end
return Rules
