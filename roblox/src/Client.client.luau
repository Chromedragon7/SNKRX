--!nonstrict
-- Roblox presentation for the preserved 480x270 arena. No imported audio/font assets.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TitleGlyphs = require("./TitleGlyphs")
local Data = require("./SourceData")
local Rules = require("./Rules")
local Run = require("./Run")
local Simulation = require("./Simulation")
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
