import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const runtime=name=>process.env.LUAU_BIN?path.join(process.env.LUAU_BIN,name+(process.platform==='win32'?'.exe':'')):name;
function run(exe,args){
 const r=spawnSync(exe,args,{cwd:root,stdio:'inherit'});
 if(r.error) throw r.error;
 if(r.status!==0) throw new Error(`${exe} failed (${r.status})`);
}
const upstream=JSON.parse(fs.readFileSync(path.join(root,'roblox/upstream.json'),'utf8'));
for(const [file,hash] of Object.entries(upstream.sha256)){
 const actual=crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
 if(actual!==hash) throw new Error(`Original source changed: ${file}`);
}
console.log('Original source files unchanged.');
run(process.execPath,['roblox/tools/import-source.mjs','--check']);
const sources=fs.readdirSync(path.join(root,'roblox/src')).filter(f=>f.endsWith('.luau')).map(f=>'roblox/src/'+f);
run(runtime('luau-compile'),['--null',...sources]);
run(runtime('luau-analyze'),['roblox/src/Rules.luau','roblox/src/Run.luau','roblox/src/Simulation.luau']);
run(runtime('luau'),['roblox/tests/run.luau']);
