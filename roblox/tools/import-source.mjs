// Copy literal balance tables from the original game; do not retype its roster.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import crypto from 'node:crypto';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const main = fs.readFileSync(path.join(root, 'main.lua'), 'utf8');
function table(source, name) {
  const start = source.indexOf(name + ' = {');
  if (start < 0) throw new Error(`Missing source table ${name}`);
  const from = source.indexOf('{', start);
  let depth = 0, quote = null, comment = false;
  for (let i = from; i < source.length; i++) {
    const c = source[i];
    if (comment) { if (c === '\n') comment = false; continue; }
    if (quote) { if (c === '\\') i++; else if (c === quote) quote = null; continue; }
    if (c === '-' && source[i+1] === '-') {comment = true; continue;}
    if (c === '"' || c === "'") {quote = c; continue;}
    if (c === '{') depth++;
    if (c === '}' && --depth === 0) return source.slice(from, i+1).replace(/\r/g, '');
  }
  throw new Error(`Unclosed table ${name}`);
}
const names = {
  Names:'character_names', Colors:'character_color_strings', Classes:'character_classes',
  Tiers:'character_tiers', TierPools:'tier_to_characters', ClassStats:'class_stat_multipliers',
  GoldRewards:'level_to_gold_gained', ShopOdds:'level_to_shop_odds',
};
let output = '-- Generated from upstream main.lua by tools/import-source.mjs.\n-- Original code: MIT, Copyright (c) 2021 a327ex. See ../../LICENSE.\nlocal Data = {}\n';
for (const [key, original] of Object.entries(names)) output += `\nData.${key} = ${table(main, original)}\n`;
const arena = fs.readFileSync(path.join(root, 'arena.lua'), 'utf8');
output += `\nData.Waves = ${table(arena, 'self.level_to_max_waves')}\n`;
output += `\nData.DistributedChance = ${table(arena, 'self.level_to_distributed_enemies_chance')}\n`;
output += '\nreturn Data\n';
const dest = path.join(root, 'roblox/src/SourceData.luau');
if (process.argv.includes('--check')) {
  if (fs.readFileSync(dest, 'utf8') !== output) throw new Error('SourceData has drifted; regenerate it.');
  console.log('Original balance-table parity passed.');
} else {
  fs.mkdirSync(path.dirname(dest), {recursive:true}); fs.writeFileSync(dest, output);
  const files = ['main.lua','player.lua','objects.lua','arena.lua','buy_screen.lua','enemies.lua','shared.lua'];
  const hashes = Object.fromEntries(files.map(f => [f, crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex')]));
  fs.writeFileSync(path.join(root,'roblox/upstream.json'), JSON.stringify({repository:'https://github.com/a327ex/SNKRX',commit:'6b93a64d694d59472375467648868ae4521d6706',sha256:hashes},null,2)+'\n');
  console.log('Imported original roster, class multipliers, rewards, shop odds and wave tables.');
}
