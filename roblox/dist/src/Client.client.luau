--!nonstrict
-- Roblox presentation for the preserved 480x270 arena. No imported audio/font assets.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

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
for key,value in pairs({bg="101C39",fg="F5F8FF",panel="203458",muted="B6C7E6",mint="72F4CC",pink="FF79BC",sky="69D9FF"}) do palette[key]=Color3.fromHex(value) end
local function make(class, properties, parent)
 local item = Instance.new(class)
 for key,value in pairs(properties) do item[key] = value end
 item.Parent = parent
 return item
end
local bg = make("Frame",{Name="Background",Size=UDim2.fromScale(1,1),BackgroundColor3=palette.bg,BorderSizePixel=0},gui)
bg.BackgroundColor3=Color3.new(1,1,1)
make("UIGradient",{Color=ColorSequence.new(Color3.fromHex("244B73"),Color3.fromHex("392752")),Rotation=30},bg)
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
  TextColor3=palette[color] or palette.fg,Font=Enum.Font.GothamMedium,TextSize=size,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},parent)
end
local function button(parent,name,label,x,y,w,h,callback,color)
 local b = make("TextButton",{Name=name,Text=label,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=palette.panel,
  BorderSizePixel=0,TextColor3=palette[color] or palette.fg,Font=Enum.Font.GothamMedium,TextSize=10,TextWrapped=true,AutoButtonColor=false},parent)
 make("UICorner",{CornerRadius=UDim.new(0,7)},b)
 make("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=Color3.fromHex("496185"),Thickness=1,Transparency=0.35},b)
 local bounce=make("UIScale",{Scale=1},b)
 local normal, normalBackground=b.TextColor3,b.BackgroundColor3
 b.MouseEnter:Connect(function()
  normal,normalBackground=b.TextColor3,b.BackgroundColor3
  b.BackgroundColor3=palette.fg;b.TextColor3=palette.bg
  TweenService:Create(bounce,TweenInfo.new(0.18,Enum.EasingStyle.Back),{Scale=1.025}):Play()
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
arena.BackgroundColor3 = Color3.fromHex("142943")
make("UICorner",{CornerRadius=UDim.new(0,9)},arena)
make("UIStroke",{Color=palette.sky,Thickness=1,Transparency=0.55},arena)
for x=16,380,16 do for y=16,212,16 do
 local dot=frame(arena,"Grid",x,y,1,1,"sky");dot.BackgroundTransparency=0.87
end end
arena.Visible = false
local actors = frame(stage,"Actors",0,0,480,270,"bg"); actors.BackgroundTransparency=1; actors.Visible=false
local hud = text(stage,"HUD","",48,5,310,18,10,"fg")
local waveText = text(stage,"Wave","",355,5,78,18,9,"yellow")
local help = text(stage,"Help","",48,248,384,16,8,"fg")
local pauseButton = button(stage,"Pause","pause",434,4,40,18,function() if sim and run.phase=="arena" then sim.paused=not sim.paused end end)
pauseButton.Visible=false
local pauseOverlay = frame(stage,"PauseOverlay",125,90,230,85,"panel"); pauseOverlay.Visible=false
make("UICorner",{CornerRadius=UDim.new(0,12)},pauseOverlay)
pauseOverlay.ZIndex=20
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
local showBonuses=false
local selectedParty
local roles={vagrant="Adventure buddy",swordsman="Close-up fighter",magician="Magic blaster",archer="Long-range shots",scout="Bouncing knives",cleric="Team healer",arcanist="Orbiting magic",merchant="Gold collector"}
local shortHelp={vagrant="Shoots nearby enemies.",swordsman="Hits a crowd at once.",magician="Blasts enemies with magic.",archer="Arrows pierce enemies.",scout="Knives jump between foes.",cleric="Drops healing for your team.",arcanist="Magic orbs fire extra bolts.",merchant="Earns bonus gold interest."}
local function rounded(parent,name,x,y,w,h,color)
 local f=frame(parent,name,x,y,w,h,color)
 make("UICorner",{CornerRadius=UDim.new(0,10)},f)
 return f
end
local function bold(parent,name,label,x,y,w,h,size,color)
 local t=text(parent,name,label,x,y,w,h,size,color);t.Font=Enum.Font.GothamBold;return t
end
local function heroFace(parent,character,x,y,size)
 local color=Data.Colors[character]
 local f=rounded(parent,"Hero",x,y,size,size,color)
 make("UIGradient",{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(150,175,205)),Rotation=90},f)
 local shine=rounded(f,"Shine",size*.12,size*.08,size*.76,size*.18,"fg");shine.BackgroundTransparency=.78
 for _,ex in ipairs({.28,.65}) do
  local eye=rounded(f,"Eye",size*ex,size*.42,size*.14,size*.21,"fg")
  rounded(eye,"Pupil",size*.045,size*.06,size*.075,size*.12,"bg")
 end
 local smile=rounded(f,"Smile",size*.42,size*.74,size*.22,size*.06,"bg")
 return f
end
local function primary(parent,name,label,x,y,w,h,callback)
 local b=button(parent,name,label,x,y,w,h,callback,"bg");b.BackgroundColor3=palette.mint;b.Font=Enum.Font.GothamBold;b.TextSize=12;return b
end
local function scrim()
 local shade=make("TextButton",{Name="ModalBackdrop",Text="",AutoButtonColor=false,Size=UDim2.fromScale(1,1),BackgroundColor3=palette.bg,BackgroundTransparency=.16,BorderSizePixel=0,ZIndex=9},screen)
 return shade
end
local function renderMenu()
 screen:ClearAllChildren();screen.BackgroundTransparency=1
 if screenMode=="title" then
  text(screen,"Eyebrow","BUILD A TEAM. BECOME A SNAKE.",26,24,290,16,9,"mint")
  bold(screen,"Title","SNKRX\nSQUAD UP!",24,46,250,98,34,"fg")
  text(screen,"Subtitle","Tiny heroes. Big teamwork.\nRecruit your favorites and take on the arena!",27,146,224,34,11,"muted")
  primary(screen,"ArenaRun",if #run.party>0 then "CONTINUE  >" else "LET'S PLAY  >",26,191,162,35,function() screenMode="shop" end)
  button(screen,"HowTo","How to play",26,232,162,24,function() infoMode=not infoMode;lastRevision=-1 end)
  local art=rounded(screen,"HeroArt",274,28,182,208,"panel");art.BackgroundColor3=Color3.new(1,1,1)
  make("UIGradient",{Color=ColorSequence.new(Color3.fromHex("304D80"),Color3.fromHex("503C75")),Rotation=45},art)
  for i,c in ipairs({"cleric","archer","magician","scout","swordsman"}) do
   local f=heroFace(art,c,20+((i-1)%2)*67,19+math.floor((i-1)/2)*54,43);f.Rotation=if i%2==0 then 9 else -8
  end
  bold(art,"Tag","BETTER TOGETHER",14,180,156,18,10,"mint")
  text(screen,"Credit","SNKRX by a327ex · Roblox preview",275,243,193,16,8,"muted")
  if infoMode then
   scrim()
   local modal=rounded(screen,"HowToPanel",88,38,304,194,"panel");modal.ZIndex=10
   bold(modal,"Heading","Your first adventure",18,14,266,26,19,"fg")
   text(modal,"Steps","1   Pick heroes in the shop.\n2   Steer with A / D or arrow keys.\n3   Your squad attacks automatically!\n4   Buy 3 matching heroes to level up.",18,51,266,92,12,"fg")
   primary(modal,"Close","GOT IT!",18,152,268,28,function() infoMode=false;lastRevision=-1 end)
  end
 elseif run.phase=="shop" then
  bold(screen,"ShopTitle","BUILD YOUR SQUAD",12,3,267,24,20,"fg")
  text(screen,"Subtitle","Pick a hero. Grow your team. Get ready to battle!",13,29,310,15,9,"muted")
  local wallet=rounded(screen,"Wallet",357,5,110,30,"panel")
  centerLabel(wallet,"Gold",tostring(run.gold).."  GOLD",0,0,110,30,15,"yellow")
  rounded(screen,"ShopPanel",10,49,320,165,"panel")
  bold(screen,"Recruit","RECRUIT HEROES",20,55,165,16,10,"sky")
  button(screen,"Reroll","Refresh · 2 gold",189,54,91,20,function() if not run:reroll() then run.message="You need 2 gold to refresh.";run.revision+=1 end end)
  button(screen,"Lock",if run.locked then "Saved" else "Save",284,54,37,20,function() run:toggleLock() end,if run.locked then "mint" else "fg")
  for i=1,3 do
   local x=18+(i-1)*103
   local character=run.cards[i]
   local card=rounded(screen,"Offer"..i,x,81,98,125,"bg")
   if character then
    heroFace(card,character,31,8,35)
    local n=centerLabel(card,"Name",Data.Names[character],2,47,94,17,12,"fg");n.Font=Enum.Font.GothamBold
    centerLabel(card,"Role",roles[character],2,66,94,13,8,"sky")
    centerLabel(card,"Description",shortHelp[character],6,80,86,20,8,"muted")
    local owned=0
    for _,u in ipairs(run.party) do if u.character==character then owned=u.copies end end
    local buy=primary(card,"Card"..i,(if owned>0 then "UPGRADE" else "RECRUIT").." · 1",5,103,88,18,function() run:buy(i) end);buy.TextSize=9
    if run.gold<1 then buy.BackgroundColor3=palette.panel;buy.TextColor3=palette.muted end
   else
    centerLabel(card,"Check","+",0,20,98,32,29,"mint")
    centerLabel(card,"Joined","ON YOUR TEAM!",5,62,88,28,11,"mint")
   end
  end
  rounded(screen,"PartyPanel",339,49,129,165,"panel")
  bold(screen,"PartyTitle","YOUR TEAM  "..#run.party.."/7",349,56,112,17,10,"fg")
  if #run.party==0 then
   centerLabel(screen,"Empty","Your adventure\nstarts here!\n\nRecruit a hero\nto join your squad.",350,87,107,88,11,"muted")
  end
  for i,u in ipairs(run.party) do
   local y=78+(i-1)*18
   local b=button(screen,"Party"..i,"",346,y,115,16,function() selectedParty=i;lastRevision=-1 end)
   rounded(b,"Color",4,3,10,10,Data.Colors[u.character])
   text(b,"Name",Data.Names[u.character],18,0,72,16,9,"fg")
   text(b,"Level","L"..u.level,94,0,20,16,9,"mint")
  end
  text(screen,"Message",run.message,13,217,318,15,9,"yellow")
  text(screen,"Tip","Tip: 3 matching heroes = a stronger hero!",13,239,286,15,9,"muted")
  button(screen,"Back","Home",12,253,48,17,function() screenMode="title" end)
  button(screen,"Bonuses","Team bonuses",69,253,99,17,function() showBonuses=true;lastRevision=-1 end)
  local go=primary(screen,"Go","BATTLE  "..run.arena.."  >",339,222,129,37,enterArena)
  if #run.party==0 then go.BackgroundColor3=palette.panel;go.TextColor3=palette.muted end
  if showBonuses then
   scrim()
   local modal=rounded(screen,"BonusesPanel",74,29,332,211,"panel");modal.ZIndex=10
   bold(modal,"Title","TEAM BONUSES",18,12,296,25,18,"fg")
   local levels,counts=Rules.classLevels(run.party)
   local classes={};for class in pairs(counts) do table.insert(classes,class) end;table.sort(classes)
   for i,class in ipairs(classes) do
    local x,y=18+((i-1)%3)*101,48+math.floor((i-1)/3)*43
    classBadge(modal,class,x,y,nil,(levels[class] or 0)>0)
    text(modal,"ClassName",class,x+23,y,78,12,8,"fg")
    text(modal,"Count",counts[class].." heroes",x+23,y+13,78,12,8,"muted")
   end
   if #classes==0 then centerLabel(modal,"Empty","Recruit heroes to discover team bonuses!",18,62,296,54,13,"muted") end
   primary(modal,"Close","DONE",18,174,296,25,function() showBonuses=false;lastRevision=-1 end)
  end
  if selectedParty and run.party[selectedParty] then
   scrim()
   local index=selectedParty;local u=run.party[index]
   local modal=rounded(screen,"HeroDetails",74,37,332,199,"panel");modal.ZIndex=10
   heroFace(modal,u.character,17,18,43)
   bold(modal,"Title",Data.Names[u.character].." · Level "..u.level,73,18,246,24,17,"fg")
   text(modal,"Copies",u.copies.." / "..(if u.level==3 then 9 elseif u.level==2 then 9 else 3).." copies",74,43,210,16,10,"mint")
   text(modal,"Body",Rules.Descriptions[u.character],18,71,296,46,11,"fg")
   button(modal,"Up","Move earlier",18,124,142,25,function() run:move(index,-1);selectedParty=nil end)
   button(modal,"Down","Move later",172,124,142,25,function() run:move(index,1);selectedParty=nil end)
   button(modal,"Sell","Sell · +"..run:salePrice(index).." gold",18,158,142,26,function() run:sell(index);selectedParty=nil end,"pink")
   primary(modal,"Close","DONE",172,158,142,26,function() selectedParty=nil;lastRevision=-1 end)
  end
 else
  local won=run.phase=="complete"
  local panel=rounded(screen,"Result",63,24,354,224,"panel")
  centerLabel(panel,"Star",if won then "★  ★  ★" else "ONE MORE TRY?",15,18,324,30,26,if won then "yellow" else "pink")
  local heading=centerLabel(panel,"Title",if won then "SQUAD GOALS!" else "You have got this!",15,60,324,34,25,"fg");heading.Font=Enum.Font.GothamBold
  centerLabel(panel,"Message",if won then "Both preview arenas cleared! More adventures are on the way." else "Every great squad starts somewhere. Try new heroes and jump back in!",30,102,294,45,12,"muted")
  primary(panel,"NewRun","PLAY AGAIN  >",45,164,264,36,restart)
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
 if infoMode or showBonuses or selectedParty then return end
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
