const fs = require('fs');
const f = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_abi.h`;
let c = fs.readFileSync(f, 'utf-8');
const lines = c.split('\n');
const seen = new Set();
const deduped = [];
for (const line of lines) {
  const m = line.match(/rustdesk_bridge_(\w+)\s*\(/);
  if (m) {
    if (seen.has(m[1])) {
      continue; // skip duplicate
    }
    seen.add(m[1]);
  }
  deduped.push(line);
}
fs.writeFileSync(f, deduped.join('\n'), 'utf-8');
console.log(`Deduped: ${lines.length} -> ${deduped.length} lines`);
