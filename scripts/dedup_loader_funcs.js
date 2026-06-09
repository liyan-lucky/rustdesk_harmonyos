const fs = require('fs');
const f = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_loader.cpp`;
let c = fs.readFileSync(f, 'utf-8');

// Find all napi_value function definitions and remove duplicates (keep first occurrence)
const lines = c.split('\n');
const seenFuncs = new Set();
const result = [];
let skipUntilBrace = false;
let braceDepth = 0;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  
  // Check for function definition start
  const funcMatch = line.match(/napi_value (\w+)\(napi_env env, napi_callback_info info\)/);
  if (funcMatch) {
    const name = funcMatch[1];
    if (seenFuncs.has(name)) {
      // Skip this duplicate function
      skipUntilBrace = true;
      braceDepth = 0;
      continue;
    }
    seenFuncs.add(name);
  }
  
  if (skipUntilBrace) {
    // Count braces to find end of function
    for (const ch of line) {
      if (ch === '{') braceDepth++;
      if (ch === '}') braceDepth--;
    }
    if (braceDepth <= 0 && line.includes('}')) {
      skipUntilBrace = false;
    }
    continue;
  }
  
  result.push(line);
}

fs.writeFileSync(f, result.join('\n'), 'utf-8');
console.log(`Removed duplicate function defs: ${lines.length} -> ${result.length} lines`);
