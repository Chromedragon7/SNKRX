-- Install into a confirmed test place from the Studio Command Bar.
local target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = target:FindFirstChild("SNKRXPort")
if old and not old:GetAttribute("SNKRXManaged") then error("An unmanaged SNKRXPort already exists; refusing to overwrite it.") end
local folder = Instance.new("Folder")
folder.Name = "SNKRXPort"
folder:SetAttribute("SNKRXManaged", true)
do local s = Instance.new("LocalScript"); s.Name = "Client"; s.Source = [====[--!nonstrict
-- Roblox presentation for the preserved 480x270 arena. No imported audio/font assets.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TitleGlyphs = require(script.Parent:WaitForChild("TitleGlyphs"))
local Data = require(script.Parent:WaitForChild("SourceData"))
local Rules = require(script.Parent:WaitForChild("Rules"))
local Run = require(script.Parent:WaitForChild("Run"))
local Simulation = require(script.Parent:WaitForChild("Simulation"))
local random = Random.new()
local function randomInt(a,b) return random:NextInteger(a,b) end
local run = Run.new(randomInt)
local sim
local screenMode = "title"
local infoMode = false
local gui = Instance.new("ScreenGui")
gui.Name = "SNKRX"
gui.ResetOnSpawn = false
-- Paint behind Roblox's top bar as well as the playable content area.
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.ClipToDeviceSafeArea = false
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, kind in ipairs({Enum.CoreGuiType.Backpack,Enum.CoreGuiType.PlayerList,Enum.CoreGuiType.Health}) do
 pcall(function() StarterGui:SetCoreGuiEnabled(kind,false) end)
end
local palette = {}
for key, value in pairs(Rules.Palette) do palette[key] = Color3.fromHex(value) end
local function make(class, properties, parent)
 local item = Instance.new(class)
 for key,value in pairs(properties) do item[key] = value end
 item.Parent = parent
 return item
end
local bg = make("Frame",{Name="Background",Size=UDim2.fromScale(1,1),BackgroundColor3=palette.bg,BorderSizePixel=0},gui)
local stage = make("Frame",{Name="Stage",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(480,270),BackgroundTransparency=1},bg)
local scale = make("UIScale",{Scale=1},stage)
local function resize()
 local topLeft = GuiService:GetGuiInset()
 local top = topLeft.Y
 scale.Scale = math.min(bg.AbsoluteSize.X/480,(bg.AbsoluteSize.Y-top)/270)
 stage.Position = UDim2.new(0.5,0,0.5,top/2)
end
bg:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize); resize()
local function frame(parent,name,x,y,w,h,color)
 return make("Frame",{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=palette[color] or palette.bg,BorderSizePixel=0},parent)
end
local function text(parent,name,label,x,y,w,h,size,color)
 return make("TextLabel",{Name=name,Text=label,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
  TextColor3=palette[color] or palette.fg,Font=Enum.Font.Code,TextSize=size,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},parent)
end
local function button(parent,name,label,x,y,w,h,callback,color)
 local b = make("TextButton",{Name=name,Text=label,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=Color3.fromHex("414141"),
  BorderSizePixel=0,TextColor3=palette[color] or palette.fg,Font=Enum.Font.Code,TextSize=10,TextWrapped=true,AutoButtonColor=false},parent)
 make("UICorner",{CornerRadius=UDim.new(0,3)},b)
 local bounce=make("UIScale",{Scale=1},b)
 local normal, normalBackground=b.TextColor3,b.BackgroundColor3
 b.MouseEnter:Connect(function()
  normal,normalBackground=b.TextColor3,b.BackgroundColor3
  b.BackgroundColor3=palette.fg;b.TextColor3=palette.bg
  TweenService:Create(bounce,TweenInfo.new(0.18,Enum.EasingStyle.Back),{Scale=1.05}):Play()
 end)
 b.MouseLeave:Connect(function()
  b.BackgroundColor3=normalBackground;b.TextColor3=normal
  TweenService:Create(bounce,TweenInfo.new(0.14),{Scale=1}):Play()
 end)
 b.Activated:Connect(callback)
 return b
end
local screen = frame(stage,"Menus",0,0,480,270,"bg")
local arena = frame(stage,"Arena",48,27,384,216,"bg")
arena.BackgroundColor3 = Color3.fromHex("383838")
arena.Visible = false
local actors = frame(stage,"Actors",0,0,480,270,"bg"); actors.BackgroundTransparency=1; actors.Visible=false
local hud = text(stage,"HUD","",48,5,310,18,10,"fg")
local waveText = text(stage,"Wave","",355,5,78,18,9,"yellow")
local help = text(stage,"Help","",48,248,384,16,8,"fg")
local pauseButton = button(stage,"Pause","pause",434,4,40,18,function() if sim and run.phase=="arena" then sim.paused=not sim.paused end end)
pauseButton.Visible=false
local pauseOverlay = frame(stage,"PauseOverlay",125,90,230,85,"bg"); pauseOverlay.Visible=false
text(pauseOverlay,"Title","paused",16,10,200,24,20,"yellow")
button(pauseOverlay,"Resume","resume",16,46,92,24,function() if sim then sim.paused=false end end)
button(pauseOverlay,"Restart","new run",122,46,92,24,function() sim=nil; run=Run.new(randomInt) end)
local cache = {}
local function actor(id,x,y,w,h,r,color,alpha)
 local item = cache[id]
 if not item then
  item=frame(actors,"Entity"..id,0,0,w,h,color)
  item.AnchorPoint=Vector2.new(0.5,0.5)
  make("UICorner",{CornerRadius=UDim.new(0,1.5)},item)
  cache[id]=item
 end
 item:SetAttribute("Seen",true)
 item.Position=UDim2.fromOffset(x,y); item.Size=UDim2.fromOffset(w,h); item.Rotation=math.deg(r or 0)
 item.BackgroundColor3=palette[color] or palette.fg; item.BackgroundTransparency=alpha or 0
 return item
end
local lastRevision, lastRun, lastScreenMode = -1, nil, nil
local function restart() sim=nil; run=Run.new(randomInt);screenMode="shop" end
local function enterArena()
 if run:start() then sim=Simulation.new(run,randomInt) end
end
local classColors={warrior="yellow",mage="blue",ranger="green",rogue="red",healer="green",psyker="purple",explorer="fg",sorcerer="blue",mercenary="yellow"}
local function centerLabel(parent,name,label,x,y,w,h,size,color)
 local t=text(parent,name,label,x,y,w,h,size,color);t.TextXAlignment=Enum.TextXAlignment.Center;return t
end
local function classBadge(parent,class,x,y,count,active)
 local color=classColors[class] or "fg"
 local tile=frame(parent,class,x,y,18,23,"bg");tile.BackgroundColor3=if active then palette[color] else Color3.fromHex("494949")
 make("UICorner",{CornerRadius=UDim.new(0,3)},tile)
 local ink=if active then "bg" else color
 local function line(px,py,w,h,r)
  local p=frame(tile,"Mark",px,py,w,h,ink);p.Rotation=r or 0;return p
 end
 -- Code-drawn class symbols; no third-party icon uploads required.
 if class=="warrior" or class=="rogue" then line(8,4,2,14);line(4,13,10,2);line(7,18,4,2)
 elseif class=="ranger" then line(5,4,2,15);line(6,3,7,2,30);line(6,18,7,2,-30);line(4,11,11,1);line(12,9,2,4)
 elseif class=="healer" then line(7,5,4,13);line(3,9,12,4)
 elseif class=="mercenary" then centerLabel(tile,"Symbol","$",0,1,18,20,16,ink)
 elseif class=="explorer" then line(8,3,2,17);line(3,10,12,2);line(6,8,6,6,45)
 elseif class=="psyker" then local p=line(4,6,10,10,45);p.BackgroundTransparency=1;make("UIStroke",{Color=palette[ink],Thickness=1.5},p);line(7,9,4,4)
 else line(8,5,2,14,-25);line(6,3,5,5,45);line(13,6,2,2) end
 if count~=nil then
  local threshold=if class=="explorer" then 1 elseif class=="warrior" or class=="mage" or class=="ranger" or class=="rogue" then 3 else 2
  local total=if class=="explorer" then 1 elseif class=="sorcerer" then 6 else threshold*2
  for i=1,total do
   local p=frame(parent,"Pip",x+((i-1)%3)*6,y+27+math.floor((i-1)/3)*5,4,3,if i<=count then color else "bg")
   if i>count then p.BackgroundColor3=Color3.fromHex("5b5b5b") end
  end
 end
 return tile
end
local function renderMenu()
 screen:ClearAllChildren()
 if screenMode=="title" then
  local title=frame(screen,"Title",24,82,79,24,"bg");title.BackgroundTransparency=1
  for _,r in ipairs(TitleGlyphs) do frame(title,"Glyph",r[1],r[2],r[3],r[4],"fg") end
  button(screen,"ArenaRun","arena run",24,123,96,22,function() screenMode="shop" end)
  button(screen,"HowTo","how to play",24,153,96,22,function() infoMode=not infoMode;lastRevision=-1 end)
  if infoMode then
   text(screen,"Instructions","Steer with A / D or the arrow keys.\nYour heroes attack automatically.\nBuy matching heroes to level up.\nP pauses the arena.",154,164,280,65,11,"fg")
  end
  local demo=frame(screen,"Demo",190,42,240,160,"bg");demo.BackgroundTransparency=1
  for i,color in ipairs({"purple","blue","purple","red","green","yellow","green"}) do
   local p=frame(demo,"Segment"..i,0,0,9,9,color);p.AnchorPoint=Vector2.new(0.5,0.5);make("UICorner",{CornerRadius=UDim.new(0,2)},p)
  end
  text(screen,"Credit","original game by a327ex",24,238,244,15,9,"fg")
  text(screen,"Preview","Roblox preview / 8 heroes / 2 arenas",24,255,340,10,7,"fg")
 elseif run.phase=="shop" then
  -- Layout follows buy_screen.lua: shop left, classes center, party right, GO bottom.
  text(screen,"ShopTitle","shop - gold:",18,12,102,18,12,"fg")
  text(screen,"Gold",tostring(run.gold),113,12,30,18,12,"yellow")
  button(screen,"Reroll","reroll: 2",150,11,65,18,function() if not run:reroll() then run.message="Reroll costs 2 gold.";run.revision+=1 end end)
  button(screen,"Lock",if run.locked then "locked" else "lock",223,11,40,18,function() run:toggleLock() end,if run.locked then "yellow" else "fg")
  text(screen,"ClassesTitle","classes",295,12,74,18,12,"fg")
  text(screen,"PartyTitle","party "..#run.party.."/7",392,12,78,18,12,"fg")
  local details=frame(screen,"Details",18,156,270,67,"bg");details.BackgroundColor3=Color3.fromHex("292929");details.Visible=false;details.ZIndex=5
  local detailTitle=text(details,"Title","",9,6,252,16,11,"yellow")
  local detailBody=text(details,"Body","",9,25,252,36,10,"fg")
  local function describe(character,level)
   details.Visible=true;detailTitle.Text=string.lower(Data.Names[character]).." - Lv."..level;detailTitle.TextColor3=palette[Data.Colors[character]]
   detailBody.Text=Rules.Descriptions[character]
  end
  for i=1,3 do
   local character=run.cards[i]
   local x=18+(i-1)*86
   if character then
    local card=button(screen,"Card"..i,"",x,39,80,99,function() run:buy(i) end)
    card.BackgroundTransparency=1
    local hero=frame(card,"Hero",31,6,18,18,Data.Colors[character]);make("UICorner",{CornerRadius=UDim.new(0,3)},hero)
    centerLabel(hero,"Cost",tostring(Data.Tiers[character]),0,0,18,18,11,"bg")
    centerLabel(card,"Name",string.lower(Data.Names[character]),0,29,80,16,11,Data.Colors[character])
    local classes=Data.Classes[character]
    for j,class in ipairs(classes) do classBadge(card,class,40-#classes*11+(j-1)*22,51,0,false) end
    card.MouseEnter:Connect(function() card.BackgroundColor3=Color3.fromHex("292929");card.BackgroundTransparency=0;describe(character,1) end)
    card.MouseLeave:Connect(function() card.BackgroundTransparency=1;details.Visible=false end)
    local owned
    for _,u in ipairs(run.party) do if u.character==character then owned=u.copies end end
    if owned then centerLabel(card,"Owned",owned.." owned",0,87,80,11,7,"fg") end
   else
    centerLabel(screen,"Purchased"..i,"-",x,65,80,18,12,"fg")
   end
  end
  local levels,counts=Rules.classLevels(run.party)
  local classes={};for class in pairs(counts) do table.insert(classes,class) end;table.sort(classes)
  for i,class in ipairs(classes) do
   local x,y=301+((i-1)%2)*35,47+math.floor((i-1)/2)*48
   local badge=classBadge(screen,class,x,y,counts[class],(levels[class] or 0)>0)
   badge.MouseEnter:Connect(function() run.message=class..": "..counts[class].." heroes" end)
  end
  for i,u in ipairs(run.party) do
   local y=40+(i-1)*23
   local b=button(screen,"Party"..i,tostring(u.level),425,y,18,18,function() describe(u.character,u.level) end,Data.Colors[u.character])
   b.BackgroundColor3=palette[Data.Colors[u.character]];b.TextColor3=palette.bg
   for j=1,u.copies-(if u.level==3 then 9 elseif u.level==2 then 3 else 1) do frame(screen,"Reserve",447+((j-1)%3)*5,y+3+math.floor((j-1)/3)*6,3,3,Data.Colors[u.character]) end
   b.MouseEnter:Connect(function() describe(u.character,u.level) end)
   b.MouseLeave:Connect(function() details.Visible=false end)
   b.MouseButton2Click:Connect(function() run:sell(i) end)
   button(screen,"Up"..i,"<",392,y,12,18,function() run:move(i,-1) end)
   button(screen,"Down"..i,">",406,y,12,18,function() run:move(i,1) end)
  end
  if #run.party==0 then text(screen,"Empty","click a hero\nto recruit",390,45,80,35,9,"fg") end
  text(screen,"ItemsTitle","items",18,142,65,14,12,"fg")
  if #run.party==0 then text(screen,"Hint","Build your party.\n3 copies = Lv.2   9 copies = Lv.3",18,174,265,32,10,"fg") end
  text(screen,"Message",run.message,18,224,445,15,9,"yellow")
  text(screen,"Level","Lv."..run.arena,287,246,48,19,12,"fg")
  local go=button(screen,"Go","GO!",367,244,57,22,enterArena,"green");go.BackgroundColor3=palette.green;go.TextColor3=palette.bg;go.TextSize=14
  button(screen,"Back","menu",432,244,37,22,function() screenMode="title" end)
  text(screen,"Controls","1/2/3 buy  |  right-click party hero to sell",18,252,259,12,7,"fg")
 else
  local won=run.phase=="complete"
  text(screen,"Title",if won then "arenas cleared" else "run ended",75,48,330,36,26,if won then "yellow" else "red")
  text(screen,"Message",if won then "You finished the first two arenas of the Roblox port. More heroes and arenas are being converted." else "Your party has fallen. Try a different formation or save gold for upgrades.",75,96,330,50,12,"fg")
  text(screen,"Summary","gold: "..run.gold.."   ·   arena: "..run.arena,75,156,330,18,10,"yellow")
  button(screen,"NewRun","new run",75,190,150,28,restart)
  text(screen,"Credits","Original game: a327ex · SNKRX · MIT code",75,239,340,18,8,"fg")
 end
end
local held = {}
local function steer(_,state,input)
 if state==Enum.UserInputState.Begin then held[input.KeyCode]=true
 elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then held[input.KeyCode]=nil end
 return Enum.ContextActionResult.Sink
end
ContextActionService:BindActionAtPriority("SNKRXSteer",steer,false,3000,Enum.KeyCode.A,Enum.KeyCode.D,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight)
UserInputService.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.KeyCode==Enum.KeyCode.P and sim and run.phase=="arena" then sim.paused=not sim.paused end
 if input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.Return then
  if screenMode=="title" then screenMode="shop" elseif run.phase=="shop" then enterArena() end
 end
 if screenMode=="shop" and run.phase=="shop" then
  local slot=({[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3})[input.KeyCode]
  if slot then run:buy(slot) end
 end
end)
UserInputService.WindowFocusReleased:Connect(function() table.clear(held); if sim and run.phase=="arena" then sim.paused=true end end)
local touchDirection=0
local touchLeft=button(stage,"TurnLeft","◀",2,230,39,35,function() end)
local touchRight=button(stage,"TurnRight","▶",439,230,39,35,function() end)
for _,pair in ipairs({{touchLeft,-1},{touchRight,1}}) do
 pair[1].InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch then touchDirection=pair[2] end end)
 pair[1].InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.Touch then touchDirection=0 end end)
end
RunService.RenderStepped:Connect(function(dt)
 local playing=screenMode~="title" and run.phase=="arena" and sim~=nil
 if playing then
  local left=held[Enum.KeyCode.A] or held[Enum.KeyCode.Left] or held[Enum.KeyCode.DPadLeft]
  local right=held[Enum.KeyCode.D] or held[Enum.KeyCode.Right] or held[Enum.KeyCode.DPadRight]
  sim:update(dt,(if right then 1 else 0)-(if left then 1 else 0)+touchDirection)
 end
 playing=screenMode~="title" and run.phase=="arena" and sim~=nil
 arena.Visible=playing;actors.Visible=playing;screen.Visible=not playing
 hud.Visible=playing;waveText.Visible=playing;help.Visible=playing;pauseButton.Visible=playing
 touchLeft.Visible=playing and UserInputService.TouchEnabled;touchRight.Visible=touchLeft.Visible
 pauseOverlay.Visible=playing and sim.paused
 if not playing then
  if lastRevision~=run.revision or lastRun~=run or lastScreenMode~=screenMode then lastRevision=run.revision;lastRun=run;lastScreenMode=screenMode;renderMenu() end
  local demo=screen:FindFirstChild("Demo")
  if demo then
   for i=1,7 do
    local p=demo:FindFirstChild("Segment"..i)
    local t=os.clock()*0.6-(i-1)*0.1
    p.Position=UDim2.fromOffset(120+70*math.cos(t),70+35*math.sin(t))
    p.Rotation=math.deg(math.atan2(35*math.cos(t),-70*math.sin(t)))
   end
  end
 else
  hud.Text="arena "..run.arena.."   ·   "..#sim.units.." heroes   ·   "..sim.kills.." defeated"
  waveText.Text="wave "..math.min(sim.wave,sim.maxWaves).."/"..sim.maxWaves
  help.Text=if sim.time<4 then "get ready · "..math.max(1,math.ceil(4-sim.time)) else "A / D or ← / → to steer    ·    P to pause"
  for _,item in pairs(cache) do item:SetAttribute("Seen",false) end
  for i,u in ipairs(sim.units) do
   actor("u"..u.id,u.x,u.y,9,9,u.r,if u.flash>0 then "fg" else Data.Colors[u.character])
   if u.hp<u.stats.hp then actor("hp"..u.id,u.x,u.y-8,10*u.hp/u.stats.hp,1,0,"green") end
   if i==1 then actor("head",u.x+7*math.cos(u.r),u.y+7*math.sin(u.r),2,2,u.r,"fg") end
  end
  for _,e in ipairs(sim.enemies) do actor("e"..e.id,e.x,e.y,7,7,e.r,if e.flash>0 then "fg" else "red") end
  for _,p in ipairs(sim.projectiles) do actor("p"..p.id,p.x,p.y,if p.kind=="orb" then 9 else 10,if p.kind=="orb" then 9 else 4,p.r,p.color) end
  for _,o in ipairs(sim.heals) do actor("h"..o.id,o.x,o.y,5,5,math.pi/4,"green") end
  for _,e in ipairs(sim.effects) do actor("fx"..e.id,e.x,e.y,e.size,e.size,e.r,e.color,if e.marker then 0.5+0.3*math.sin(sim.time*20) else math.clamp(1-e.life/0.22,0.2,1)) end
  for id,item in pairs(cache) do if not item:GetAttribute("Seen") then item:Destroy();cache[id]=nil end end
 end
 gui:SetAttribute("Phase",if screenMode=="title" then "title" else run.phase)
 gui:SetAttribute("Arena",run.arena)
 gui:SetAttribute("Gold",run.gold)
 gui:SetAttribute("Heroes",#run.party)
 gui:SetAttribute("Kills",if sim then sim.kills else 0)
end)
gui.Destroying:Connect(function() ContextActionService:UnbindAction("SNKRXSteer") end)
print("SNKRX Roblox preview ready: 8 tier-one heroes, 2 arenas.")
]====]; s.Parent = folder end
do local s = Instance.new("ModuleScript"); s.Name = "Rules"; s.Source = [====[--!strict
-- Port of the formulas in main.lua, objects.lua and buy_screen.lua.
-- Original code: MIT, Copyright (c) 2021 a327ex. See ../../LICENSE.
local Data: any = require(script.Parent:WaitForChild("SourceData"))
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
]====]; s.Parent = folder end
do local s = Instance.new("ModuleScript"); s.Name = "Run"; s.Source = [====[--!strict
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
]====]; s.Parent = folder end
do local s = Instance.new("ModuleScript"); s.Name = "Simulation"; s.Source = [====[--!nonstrict
-- 2D Roblox-independent simulation. Formula/ability provenance: player.lua, objects.lua,
-- enemies.lua and arena.lua at the commit recorded in ../upstream.json.
local Data = require(script.Parent:WaitForChild("SourceData"))
local Rules = require(script.Parent:WaitForChild("Rules"))
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
]====]; s.Parent = folder end
do local s = Instance.new("ModuleScript"); s.Name = "SourceData"; s.Source = [====[-- Generated from upstream main.lua by tools/import-source.mjs.
-- Original code: MIT, Copyright (c) 2021 a327ex. See ../../LICENSE.
local Data = {}

Data.Names = {
    ['vagrant'] = 'Vagrant',
    ['swordsman'] = 'Swordsman',
    ['wizard'] = 'Wizard',
    ['magician'] = 'Magician',
    ['archer'] = 'Archer',
    ['scout'] = 'Scout',
    ['cleric'] = 'Cleric',
    ['outlaw'] = 'Outlaw',
    ['blade'] = 'Blade',
    ['elementor'] = 'Elementor',
    ['saboteur'] = 'Saboteur',
    ['bomber'] = 'Bomber',
    ['stormweaver'] = 'Stormweaver',
    ['sage'] = 'Sage',
    ['squire'] = 'Squire',
    ['cannoneer'] = 'Cannoneer',
    ['dual_gunner'] = 'Dual Gunner',
    ['hunter'] = 'Hunter',
    ['sentry'] = 'Sentry',
    ['chronomancer'] = 'Chronomancer',
    ['spellblade'] = 'Spellblade',
    ['psykeeper'] = 'Psykeeper',
    ['engineer'] = 'Engineer',
    ['plague_doctor'] = 'Plague Doctor',
    ['barbarian'] = 'Barbarian',
    ['juggernaut'] = 'Juggernaut',
    ['lich'] = 'Lich',
    ['cryomancer'] = 'Cryomancer',
    ['pyromancer'] = 'Pyromancer',
    ['corruptor'] = 'Corruptor',
    ['beastmaster'] = 'Beastmaster',
    ['launcher'] = 'Launcher',
    ['jester'] = 'Jester',
    ['assassin'] = 'Assassin',
    ['host'] = 'Host',
    ['carver'] = 'Carver',
    ['bane'] = 'Bane',
    ['psykino'] = 'Psykino',
    ['barrager'] = 'Barrager',
    ['highlander'] = 'Highlander',
    ['fairy'] = 'Fairy',
    ['priest'] = 'Priest',
    ['infestor'] = 'Infestor',
    ['flagellant'] = 'Flagellant',
    ['arcanist'] = 'Arcanist',
    ['illusionist'] = 'Illusionist',
    ['artificer'] = 'Artificer',
    ['witch'] = 'Witch',
    ['silencer'] = 'Silencer',
    ['vulcanist'] = 'Vulcanist',
    ['warden'] = 'Warden',
    ['psychic'] = 'Psychic',
    ['miner'] = 'Miner',
    ['merchant'] = 'Merchant',
    ['usurer'] = 'Usurer',
    ['gambler'] = 'Gambler',
    ['thief'] = 'Thief',
  }

Data.Colors = {
    ['vagrant'] = 'fg',
    ['swordsman'] = 'yellow',
    ['wizard'] = 'blue',
    ['magician'] = 'blue',
    ['archer'] = 'green',
    ['scout'] = 'red',
    ['cleric'] = 'green',
    ['outlaw'] = 'red',
    ['blade'] = 'yellow',
    ['elementor'] = 'blue',
    ['saboteur'] = 'orange',
    ['bomber'] = 'orange',
    ['stormweaver'] = 'blue',
    ['sage'] = 'purple',
    ['squire'] = 'yellow',
    ['cannoneer'] = 'orange',
    ['dual_gunner'] = 'green',
    ['hunter'] = 'green',
    ['sentry'] = 'green',
    ['chronomancer'] = 'blue',
    ['spellblade'] = 'blue',
    ['psykeeper'] = 'fg',
    ['engineer'] = 'orange',
    ['plague_doctor'] = 'purple',
    ['barbarian'] = 'yellow',
    ['juggernaut'] = 'yellow',
    ['lich'] = 'blue',
    ['cryomancer'] = 'blue',
    ['pyromancer'] = 'red',
    ['corruptor'] = 'orange',
    ['beastmaster'] = 'red',
    ['launcher'] = 'yellow',
    ['jester'] = 'red',
    ['assassin'] = 'purple',
    ['host'] = 'orange',
    ['carver'] = 'green',
    ['bane'] = 'purple',
    ['psykino'] = 'fg',
    ['barrager'] = 'green',
    ['highlander'] = 'yellow',
    ['fairy'] = 'green',
    ['priest'] = 'green',
    ['infestor'] = 'orange',
    ['flagellant'] = 'fg',
    ['arcanist'] = 'blue2',
    ['illusionist'] = 'blue2',
    ['artificer'] = 'blue2',
    ['witch'] = 'purple',
    ['silencer'] = 'blue2',
    ['vulcanist'] = 'red',
    ['warden'] = 'yellow',
    ['psychic'] = 'fg',
    ['miner'] = 'yellow2',
    ['merchant'] = 'yellow2',
    ['usurer'] = 'purple',
    ['gambler'] = 'yellow2',
    ['thief'] = 'red',
  }

Data.Classes = {
    ['vagrant'] = {'explorer', 'psyker'},
    ['swordsman'] = {'warrior'},
    ['wizard'] = {'mage', 'nuker'},
    ['magician'] = {'mage'},
    ['archer'] = {'ranger'},
    ['scout'] = {'rogue'},
    ['cleric'] = {'healer'},
    ['outlaw'] = {'warrior', 'rogue'},
    ['blade'] = {'warrior', 'nuker'},
    ['elementor'] = {'mage', 'nuker'},
    -- ['saboteur'] = {'rogue', 'conjurer', 'nuker'},
    ['bomber'] = {'nuker', 'conjurer'},
    ['stormweaver'] = {'enchanter'},
    ['sage'] = {'nuker', 'forcer'},
    ['squire'] = {'warrior', 'enchanter'},
    ['cannoneer'] = {'ranger', 'nuker'},
    ['dual_gunner'] = {'ranger', 'rogue'},
    -- ['hunter'] = {'ranger', 'conjurer', 'forcer'},
    ['sentry'] = {'ranger', 'conjurer'},
    ['chronomancer'] = {'mage', 'enchanter'},
    ['spellblade'] = {'mage', 'rogue'},
    ['psykeeper'] = {'healer', 'psyker'},
    ['engineer'] = {'conjurer'},
    ['plague_doctor'] = {'nuker', 'voider'},
    ['barbarian'] = {'curser', 'warrior'},
    ['juggernaut'] = {'forcer', 'warrior'},
    ['lich'] = {'mage'},
    ['cryomancer'] = {'mage', 'voider'},
    ['pyromancer'] = {'mage', 'nuker', 'voider'},
    ['corruptor'] = {'ranger', 'swarmer'},
    ['beastmaster'] = {'rogue', 'swarmer'},
    ['launcher'] = {'curser', 'forcer'},
    ['jester'] = {'curser', 'rogue'},
    ['assassin'] = {'rogue', 'voider'},
    ['host'] = {'swarmer'},
    ['carver'] = {'conjurer', 'healer'},
    ['bane'] = {'curser', 'voider'},
    ['psykino'] = {'mage', 'psyker', 'forcer'},
    ['barrager'] = {'ranger', 'forcer'},
    ['highlander'] = {'warrior'},
    ['fairy'] = {'enchanter', 'healer'},
    ['priest'] = {'healer'},
    ['infestor'] = {'curser', 'swarmer'},
    ['flagellant'] = {'psyker', 'enchanter'},
    ['arcanist'] = {'sorcerer'},
    -- ['illusionist'] = {'sorcerer', 'conjurer'},
    ['artificer'] = {'sorcerer', 'conjurer'},
    ['witch'] = {'sorcerer', 'voider'},
    ['silencer'] = {'sorcerer', 'curser'},
    ['vulcanist'] = {'sorcerer', 'nuker'},
    ['warden'] = {'sorcerer', 'forcer'},
    ['psychic'] = {'sorcerer', 'psyker'},
    ['miner'] = {'mercenary'},
    ['merchant'] = {'mercenary'},
    ['usurer'] = {'curser', 'mercenary', 'voider'},
    ['gambler'] = {'mercenary', 'sorcerer'},
    ['thief'] = {'rogue', 'mercenary'},
  }

Data.Tiers = {
    ['vagrant'] = 1,
    ['swordsman'] = 1,
    ['magician'] = 1,
    ['archer'] = 1,
    ['scout'] = 1,
    ['cleric'] = 1,
    ['outlaw'] = 2,
    ['blade'] = 4,
    ['elementor'] = 3,
    -- ['saboteur'] = 2,
    ['bomber'] = 2,
    ['wizard'] = 2,
    ['stormweaver'] = 3,
    ['sage'] = 2,
    ['squire'] = 2,
    ['cannoneer'] = 4,
    ['dual_gunner'] = 2,
    -- ['hunter'] = 2,
    ['sentry'] = 2,
    ['chronomancer'] = 2,
    ['spellblade'] = 3,
    ['psykeeper'] = 3,
    ['engineer'] = 3,
    ['plague_doctor'] = 4,
    ['barbarian'] = 2,
    ['juggernaut'] = 3,
    -- ['lich'] = 4,
    ['cryomancer'] = 2,
    ['pyromancer'] = 3,
    ['corruptor'] = 4,
    ['beastmaster'] = 2,
    -- ['launcher'] = 2,
    ['jester'] = 2,
    ['assassin'] = 3,
    ['host'] = 3,
    ['carver'] = 2,
    ['bane'] = 3,
    ['psykino'] = 4,
    ['barrager'] = 3,
    ['highlander'] = 4,
    ['fairy'] = 4,
    ['priest'] = 4,
    ['infestor'] = 3,
    ['flagellant'] = 3,
    ['arcanist'] = 1,
    -- ['illusionist'] = 3,
    ['artificer'] = 3,
    ['witch'] = 2,
    ['silencer'] = 2,
    ['vulcanist'] = 4,
    ['warden'] = 4,
    ['psychic'] = 2,
    ['miner'] = 2,
    ['merchant'] = 1,
    ['usurer'] = 3,
    ['gambler'] = 3,
    ['thief'] = 4,
  }

Data.TierPools = {
    [1] = {'vagrant', 'swordsman', 'magician', 'archer', 'scout', 'cleric', 'arcanist', 'merchant'},
    [2] = {'wizard', 'bomber', 'sage', 'squire', 'dual_gunner', 'sentry', 'chronomancer', 'barbarian', 'cryomancer', 'beastmaster', 'jester', 'carver', 'psychic', 'witch', 'silencer', 'outlaw', 'miner'},
    [3] = {'elementor', 'stormweaver', 'spellblade', 'psykeeper', 'engineer', 'juggernaut', 'pyromancer', 'host', 'assassin', 'bane', 'barrager', 'infestor', 'flagellant', 'artificer', 'usurer', 'gambler'},
    [4] = {'priest', 'highlander', 'psykino', 'fairy', 'blade', 'plague_doctor', 'cannoneer', 'vulcanist', 'warden', 'corruptor', 'thief'},
  }

Data.ClassStats = {
    ['ranger'] = {hp = 1, dmg = 1.2, aspd = 1.5, area_dmg = 1, area_size = 1, def = 0.9, mvspd = 1.2},
    ['warrior'] = {hp = 1.4, dmg = 1.1, aspd = 0.9, area_dmg = 1, area_size = 1, def = 1.25, mvspd = 0.9},
    ['mage'] = {hp = 0.6, dmg = 1.4, aspd = 1, area_dmg = 1.25, area_size = 1.2, def = 0.75, mvspd = 1},
    ['rogue'] = {hp = 0.8, dmg = 1.3, aspd = 1.1, area_dmg = 0.6, area_size = 0.6, def = 0.8, mvspd = 1.4},
    ['healer'] = {hp = 1.2, dmg = 1, aspd = 0.5, area_dmg = 1, area_size = 1, def = 1.2, mvspd = 1},
    ['enchanter'] = {hp = 1.2, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1.2, mvspd = 1.2},
    ['nuker'] = {hp = 0.9, dmg = 1, aspd = 0.75, area_dmg = 1.5, area_size = 1.5, def = 1, mvspd = 1},
    ['conjurer'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1},
    ['psyker'] = {hp = 1.5, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 0.5, mvspd = 1},
    ['curser'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 0.75, mvspd = 1},
    ['forcer'] = {hp = 1.25, dmg = 1.1, aspd = 0.9, area_dmg = 0.75, area_size = 0.75, def = 1.2, mvspd = 1},
    ['swarmer'] = {hp = 1.2, dmg = 1, aspd = 1.25, area_dmg = 1, area_size = 1, def = 0.75, mvspd = 0.75},
    ['voider'] = {hp = 0.75, dmg = 1.3, aspd = 1, area_dmg = 0.8, area_size = 0.75, def = 0.6, mvspd = 0.8},
    ['sorcerer'] = {hp = 0.8, dmg = 1.3, aspd = 1, area_dmg = 1.2, area_size = 1, def = 0.8, mvspd = 1},
    ['mercenary'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1},
    ['explorer'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1.25},
    ['seeker'] = {hp = 0.5, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 0.3},
    ['mini_boss'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 0.3},
    ['enemy_critter'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 0.5},
    ['saboteur'] = {hp = 1, dmg = 1, aspd = 1, area_dmg = 1, area_size = 1, def = 1, mvspd = 1.4},
  }

Data.GoldRewards = {
    [1] = {3, 3},
    [2] = {3, 3},
    [3] = {5, 6},
    [4] = {4, 5},
    [5] = {5, 8},
    [6] = {8, 10},
    [7] = {8, 10}, 
    [8] = {12, 14},
    [9] = {14, 18},
    [10] = {10, 13},
    [11] = {12, 15},
    [12] = {18, 20},
    [13] = {10, 14},
    [14] = {12, 16},
    [15] = {14, 18},
    [16] = {12, 12},
    [17] = {12, 12},
    [18] = {20, 24}, 
    [19] = {8, 12},
    [20] = {10, 14}, 
    [21] = {20, 28},
    [22] = {32, 32},
    [23] = {36, 36},
    [24] = {48, 48},
    [25] = {100, 100},
  }

Data.ShopOdds = {
    [1] = {70, 20, 10, 0},
    [2] = {50, 30, 15, 5},
    [3] = {25, 45, 20, 10},
    [4] = {10, 25, 45, 20},
    [5] = {5, 15, 30, 50},
  }

Data.Waves = {
      2, 3, 4,
      3, 4, 4, 5,
      5, 5, 5, 5, 7,
      6, 6, 7, 7, 8, 10,
      8, 8, 10, 12, 14, 16, 25,
    }

Data.DistributedChance = {
      0, 5, 10,
      10, 15, 15, 20,
      20, 20, 20, 20, 25,
      25, 25, 25, 25, 25, 30,
      20, 25, 30, 35, 40, 45, 50,
    }

return Data
]====]; s.Parent = folder end
do local s = Instance.new("ModuleScript"); s.Name = "TitleGlyphs"; s.Source = [====[-- Original SNKRX title lettering: FatPixelFont by Tyemu. See ../ASSETS.md.
return {
 {31,0,3,1},
 {4,1,7,1},
 {30,1,5,1},
 {40,1,2,1},
 {49,1,7,1},
 {2,2,10,1},
 {18,2,3,1},
 {26,2,3,1},
 {30,2,5,1},
 {39,2,4,1},
 {48,2,10,1},
 {1,3,12,1},
 {17,3,5,1},
 {25,3,10,1},
 {39,3,4,1},
 {48,3,11,1},
 {64,3,3,1},
 {73,3,3,1},
 {1,4,12,1},
 {17,4,5,1},
 {25,4,10,1},
 {39,4,4,1},
 {48,4,11,1},
 {63,4,5,1},
 {72,4,5,1},
 {0,5,5,1},
 {9,5,3,1},
 {17,5,6,1},
 {25,5,5,1},
 {31,5,4,1},
 {38,5,5,1},
 {48,5,4,1},
 {54,5,6,1},
 {63,5,6,1},
 {71,5,6,1},
 {0,6,4,1},
 {17,6,6,1},
 {25,6,5,1},
 {31,6,5,1},
 {38,6,5,1},
 {48,6,4,1},
 {55,6,5,1},
 {63,6,14,1},
 {0,7,5,1},
 {17,7,7,1},
 {25,7,5,1},
 {31,7,5,1},
 {38,7,5,1},
 {48,7,4,1},
 {55,7,5,1},
 {63,7,13,1},
 {0,8,10,1},
 {17,8,7,1},
 {25,8,5,1},
 {32,8,10,1},
 {48,8,4,1},
 {54,8,5,1},
 {64,8,11,1},
 {1,9,10,1},
 {17,9,7,1},
 {25,9,5,1},
 {32,9,9,1},
 {48,9,11,1},
 {65,9,9,1},
 {1,10,11,1},
 {16,10,14,1},
 {32,10,10,1},
 {49,10,9,1},
 {66,10,7,1},
 {3,11,9,1},
 {16,11,4,1},
 {21,11,9,1},
 {32,11,11,1},
 {49,11,9,1},
 {66,11,7,1},
 {8,12,5,1},
 {16,12,4,1},
 {21,12,8,1},
 {32,12,4,1},
 {38,12,6,1},
 {49,12,9,1},
 {66,12,7,1},
 {9,13,4,1},
 {16,13,5,1},
 {22,13,7,1},
 {32,13,5,1},
 {39,13,6,1},
 {49,13,10,1},
 {65,13,9,1},
 {1,14,3,1},
 {8,14,5,1},
 {16,14,5,1},
 {22,14,7,1},
 {32,14,5,1},
 {40,14,5,1},
 {49,14,5,1},
 {55,14,5,1},
 {64,14,11,1},
 {0,15,13,1},
 {16,15,5,1},
 {23,15,6,1},
 {33,15,4,1},
 {41,15,5,1},
 {49,15,5,1},
 {55,15,5,1},
 {63,15,13,1},
 {0,16,13,1},
 {16,16,5,1},
 {23,16,6,1},
 {33,16,4,1},
 {42,16,4,1},
 {49,16,5,1},
 {56,16,5,1},
 {62,16,7,1},
 {70,16,7,1},
 {0,17,12,1},
 {16,17,5,1},
 {24,17,5,1},
 {33,17,4,1},
 {42,17,4,1},
 {49,17,5,1},
 {56,17,5,1},
 {62,17,6,1},
 {71,17,6,1},
 {1,18,10,1},
 {17,18,4,1},
 {24,18,5,1},
 {33,18,4,1},
 {43,18,2,1},
 {49,18,5,1},
 {57,18,4,1},
 {62,18,5,1},
 {72,18,5,1},
 {2,19,7,1},
 {25,19,3,1},
 {34,19,2,1},
 {50,19,3,1},
 {58,19,2,1},
 {63,19,3,1},
 {73,19,3,1},
}
]====]; s.Parent = folder end
game:GetService("ChangeHistoryService"):SetWaypoint("Before SNKRX port install")
if old then old:Destroy() end
folder.Parent = target
game:GetService("ChangeHistoryService"):SetWaypoint("SNKRX port installed")
return "Installed SNKRX preview (" .. #folder:GetChildren() .. " scripts). Press Play."
