import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.join(root,'dist'); fs.mkdirSync(out,{recursive:true});
const scripts=fs.readdirSync(path.join(root,'src')).filter(n=>n.endsWith('.luau')).sort().map(file=>({
 name:file.replace('.client','').replace('.luau',''),class:file.includes('.client.')?'LocalScript':'ModuleScript',
 source:fs.readFileSync(path.join(root,'src',file),'utf8').replace(/require\("\.\/(\w+)"\)/g,'require(script.Parent:WaitForChild("$1"))'),
}));
fs.mkdirSync(path.join(out,'src'),{recursive:true});
for(const s of scripts) fs.writeFileSync(path.join(out,'src',s.name+(s.class==='LocalScript'?'.client':'')+'.luau'),s.source);
const xml=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const prop=(type,name,value)=>`<${type} name="${name}">${xml(value)}</${type}>`;
let id=0;
const item=(klass,name,children='',properties='')=>`<Item class="${klass}" referent="RBX${++id}"><Properties>${prop('string','Name',name)}${properties}</Properties>${children}</Item>`;
const code=scripts.map(s=>item(s.class,s.name,'',prop('ProtectedString','Source',s.source))).join('');
const folder=item('Folder','SNKRXPort',code);
const xmlRoot=body=>`<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4"><External>null</External><External>nil</External>${body}</roblox>`;
fs.writeFileSync(path.join(out,'SNKRX.rbxlx'),xmlRoot(item('Workspace','Workspace')+item('StarterPlayer','StarterPlayer',item('StarterPlayerScripts','StarterPlayerScripts',folder))));
fs.writeFileSync(path.join(out,'SNKRX.rbxmx'),xmlRoot(folder));
let installer='-- Install into a confirmed test place from the Studio Command Bar.\nlocal target = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")\nlocal old = target:FindFirstChild("SNKRXPort")\nif old and not old:GetAttribute("SNKRXManaged") then error("An unmanaged SNKRXPort already exists; refusing to overwrite it.") end\nlocal folder = Instance.new("Folder")\nfolder.Name = "SNKRXPort"\nfolder:SetAttribute("SNKRXManaged", true)\n';
for(const s of scripts){
 if(s.source.includes(']====]')) throw new Error('Lua delimiter collision');
 installer+=`do local s = Instance.new("${s.class}"); s.Name = "${s.name}"; s.Source = [====[${s.source}]====]; s.Parent = folder end\n`;
}
installer+='game:GetService("ChangeHistoryService"):SetWaypoint("Before SNKRX port install")\nif old then old:Destroy() end\nfolder.Parent = target\ngame:GetService("ChangeHistoryService"):SetWaypoint("SNKRX port installed")\nreturn "Installed SNKRX preview (" .. #folder:GetChildren() .. " scripts). Press Play."\n';
fs.writeFileSync(path.join(out,'install.luau'),installer);
console.log(`Built ${scripts.length} scripts into SNKRX.rbxlx, SNKRX.rbxmx, and install.luau.`);
