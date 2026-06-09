const fs = require('fs');
const f = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_loader.cpp`;
let c = fs.readFileSync(f, 'utf-8');

// Remove duplicate napi_value function definitions
const funcRe = /napi_value (\w+)\(napi_env env, napi_callback_info info\)/g;
const seenFuncs = new Set();
const funcPositions = [];
while ((m = funcRe.exec(c)) !== null) {
  funcPositions.push({ name: m[1], index: m.index });
}

// Find duplicates (keep first, remove subsequent)
const dupes = funcPositions.filter(p => {
  if (seenFuncs.has(p.name)) return true;
  seenFuncs.add(p.name);
  return false;
});

console.log(`Duplicate NAPI functions: ${dupes.length}`);
dupes.forEach(d => console.log(`  ${d.name}`));

// Remove duplicate registration entries
const regRe = /\{"(\w+)", nullptr, (\w+), nullptr, nullptr, nullptr, napi_default, nullptr\},/g;
const seenRegs = new Set();
let newC = c.replace(regRe, (match, name, func) => {
  if (seenRegs.has(name)) return '';
  seenRegs.add(name);
  return match;
});

fs.writeFileSync(f, newC, 'utf-8');
console.log('Removed duplicate registrations');

// For duplicate function definitions, we need to manually remove them
// This is complex - let's just note them for now
if (dupes.length > 0) {
  console.log('NOTE: Duplicate function definitions need manual removal');
}
