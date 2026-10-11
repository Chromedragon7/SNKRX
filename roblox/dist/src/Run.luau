--!strict
-- Shop state adapted from buy_screen.lua. Pure data; shared by Studio and CLI tests.
local Data: any = require(script.Parent:WaitForChild("SourceData"))
local Rules = require(script.Parent:WaitForChild("Rules"))
local Run = {}
Run.__index = Run
function Run.new(randomInt: (number, number) -> number): any
 local self: any = setmetatable({gold = 3, party = {}, cards = {}, arena = 1, phase = "shop", locked = false,
  randomInt = randomInt, message = "Buy heroes, then enter the arena.", revision = 0}, Run)
 self:roll()
 return self
end
function Run.roll(self: any)
 -- Original three-card draw, rejecting support-only rolls. Tier-one-only preview.
 for _ = 1, 100 do
  self.cards = {}
  local attacker = false
  for i = 1, 3 do
   local character = Rules.Playable[self.randomInt(1, #Rules.Playable)]
   self.cards[i] = character
   if character ~= "cleric" and character ~= "merchant" then attacker = true end
  end
  if attacker then self.revision += 1; return end
 end
 self.cards[1] = "vagrant" -- bounded fallback for a pathological injected RNG
 self.revision += 1
end
function Run.buy(self: any, slot: number): boolean
 if self.phase ~= "shop" or slot % 1 ~= 0 or slot < 1 or slot > 3 then return false end
 local character = self.cards[slot]
 if not character then return false end
 local price = Data.Tiers[character]
 if self.gold < price then self.message = "Not enough gold."; self.revision += 1; return false end
 local found
 for _, u in ipairs(self.party :: {any}) do if u.character == character then found = u; break end end
 if found and found.copies >= 9 then self.message = "This hero is already level 3."; self.revision += 1; return false end
 if not found and #self.party >= Rules.MaxParty then self.message = "Party is full. Sell a hero first."; self.revision += 1; return false end
 self.gold -= price
 if found then found.copies += 1; found.level = if found.copies >= 9 then 3 elseif found.copies >= 3 then 2 else 1
 else table.insert(self.party, {character = character, level = 1, copies = 1}) end
 self.cards[slot] = false
 self.message = Data.Names[character] .. " joined your party."
 self.revision += 1
 return true
end
function Run.salePrice(self: any, index: number): number
 local u = self.party[index]
 if not u then return 0 end
 local base = if u.level == 3 then 6 elseif u.level == 2 then 2 else 1
 local reserve = u.copies - (if u.level == 3 then 9 elseif u.level == 2 then 3 else 1)
 return Data.Tiers[u.character]*(base + math.floor(reserve/3)*2 + reserve%3)
end
function Run.sell(self: any, index: number): boolean
 if self.phase ~= "shop" or not self.party[index] then return false end
 self.gold += self:salePrice(index)
 table.remove(self.party, index)
 self.message = "Hero sold."
 self.revision += 1
 return true
end
function Run.move(self: any, index: number, offset: number): boolean
 if self.phase ~= "shop" or math.abs(offset) ~= 1 or not self.party[index] or not self.party[index+offset] then return false end
 self.party[index], self.party[index+offset] = self.party[index+offset], self.party[index]
 self.revision += 1
 return true
end
function Run.reroll(self: any): boolean
 if self.phase ~= "shop" or self.gold < 2 then return false end
 self.gold -= 2; self:roll(); self.message = "Shop refreshed."
 return true
end
function Run.toggleLock(self: any)
 if self.phase == "shop" then self.locked = not self.locked; self.revision += 1 end
end
function Run.start(self: any): boolean
 if self.phase ~= "shop" or #self.party == 0 then self.message = "Buy a hero first."; self.revision += 1; return false end
 local attacker = false
 for _, u in ipairs(self.party :: {any}) do if u.character ~= "cleric" and u.character ~= "merchant" then attacker = true end end
 if not attacker then self.message = "Add an attacking hero before entering."; self.revision += 1; return false end
 self.phase = "arena"; self.revision += 1
 return true
end
function Run.complete(self: any)
 if self.phase ~= "arena" then return end
 local range = Data.GoldRewards[self.arena]
 local reward: number = self.randomInt(range[1], range[2])
 local interest = Rules.interest(self.gold, self.party)
 self.gold += reward + interest
 self.message = string.format("Arena cleared! +%d gold, +%d interest.", reward, interest)
 if self.arena >= Rules.LastArena then self.phase = "complete"
 else self.arena += 1; self.phase = "shop"; if not self.locked then self:roll() end end
 self.revision += 1
end
function Run.lose(self: any)
 if self.phase == "arena" then self.phase = "lost"; self.message = "Your party has fallen."; self.revision += 1 end
end
return Run
