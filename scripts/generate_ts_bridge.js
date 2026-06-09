const fs = require('fs');

const CORE_RS = String.raw`L:\Visual_Studio_Code\99_Temp\rustdesk-master\src\harmony_bridge\core.rs`;
const INDEX_D_TS = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\types\librustdesk_bridge\index.d.ts`;
const NATIVE_BRIDGE_TS = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\ets\services\NativeRustDeskBridge.ts`;
const LIB_BRIDGE_D_TS = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\ets\services\librustdesk_bridge.d.ts`;

const coreContent = fs.readFileSync(CORE_RS, 'utf-8');
const indexContent = fs.readFileSync(INDEX_D_TS, 'utf-8');
const nativeContent = fs.readFileSync(NATIVE_BRIDGE_TS, 'utf-8');

// Parse existing TS declarations
const existingTsNames = new Set();
const tsRe = /export const (\w+):/g;
let m;
while ((m = tsRe.exec(indexContent)) !== null) existingTsNames.add(m[1]);

// Parse existing NativeRustDeskBridge static methods
const existingStaticNames = new Set();
const staticRe = /static (\w+)\(/g;
while ((m = staticRe.exec(nativeContent)) !== null) existingStaticNames.add(m[1]);

// Internal functions to skip
const internals = new Set([
  'connect_state', 'local_options', 'latest_video_frame', 'active_session',
  'incoming_service_started', 'update_connect_state', 'queue_event',
  'current_timestamp_millis', 'next_bridge_job_id', 'escape_json',
  'key_code_to_official_key_name', 'apply_server_options', 'read_cached_peer_info',
  'peer_info_detail', 'mark_peer_connected_with_cached_info', 'option_is_enabled',
  'publish_real_video_frame'
]);

// Parse pub fn from core.rs
const fnRe = /pub fn (\w+)\(([^)]*)\)(?:\s*->\s*([^{]+?))?\s*\{/g;
const rustFns = [];
while ((m = fnRe.exec(coreContent)) !== null) {
  const name = m[1];
  if (internals.has(name)) continue;
  
  const paramsStr = m[2].trim();
  const retStr = m[3] ? m[3].trim() : '';
  
  const params = [];
  if (paramsStr) {
    let depth = 0, current = '';
    for (const ch of paramsStr) {
      if (ch === '<' || ch === '(') depth++;
      if (ch === '>' || ch === ')') depth--;
      if (ch === ',' && depth === 0) { params.push(current.trim()); current = ''; }
      else { current += ch; }
    }
    if (current.trim()) params.push(current.trim());
  }
  
  const parsedParams = params.map(p => {
    const colonIdx = p.indexOf(':');
    if (colonIdx === -1) return null;
    let pname = p.substring(0, colonIdx).trim().replace(/^_+/, '');
    let ptype = p.substring(colonIdx + 1).trim();
    return { name: pname, type: ptype };
  }).filter(Boolean);
  
  let ret = 'void';
  if (!retStr || retStr === '()') ret = 'void';
  else if (retStr === 'String') ret = 'string';
  else if (retStr === 'bool') ret = 'boolean';
  else if (retStr === 'i32' || retStr === 'c_int') ret = 'number';
  else if (retStr === 'u64') ret = 'number';
  else ret = 'any';
  
  rustFns.push({ name, params: parsedParams, ret });
}

function toCamelCase(name) {
  return name.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

function toSnakeCase(name) {
  return name;
}

function rustParamToTs(p) {
  if (p.type === '&str') return `${p.name}: string`;
  if (p.type === 'bool') return `${p.name}: boolean`;
  if (p.type === 'i32' || p.type === 'c_int' || p.type === 'usize' || p.type === 'u64' || p.type === 'i64') return `${p.name}: number`;
  return `${p.name}: any`;
}

function tsDefaultReturn(ret) {
  if (ret === 'string') return "''";
  if (ret === 'boolean') return 'false';
  if (ret === 'number') return '0';
  if (ret === 'void') return '';
  return 'undefined';
}

// Generate index.d.ts additions
const tsDecls = [];
// Generate NativeRustDeskBridge.ts additions
const tsMethods = [];

for (const { name, params, ret } of rustFns) {
  const camelName = toCamelCase(name);
  const snakeName = name;
  const bridgeName = `rustdesk_bridge_${name}`;
  
  const inTs = existingTsNames.has(camelName);
  const inStatic = existingStaticNames.has(camelName);
  
  if (inTs && inStatic) continue;
  
  const tsParams = params.map(p => rustParamToTs(p));
  const tsParamNames = params.map(p => p.name);
  
  // index.d.ts
  if (!inTs) {
    tsDecls.push(`export const ${camelName}: (${tsParams.join(', ')}) => ${ret};`);
  }
  
  // NativeRustDeskBridge.ts
  if (!inStatic) {
    const defaultRet = tsDefaultReturn(ret);
    const paramTuple = params.length === 0 ? '[]' : `[${tsParams.join(', ')}]`;
    
    let method = `  static ${camelName}(${tsParams.join(', ')}): ${ret} {\n`;
    method += `    const nativeModule = NativeRustDeskBridge.getModule();\n`;
    method += `    const fn = NativeRustDeskBridge.resolveFunction<${paramTuple}, ${ret}>(\n`;
    method += `      nativeModule,\n`;
    method += `      ['${camelName}', '${snakeName}', '${bridgeName}']\n`;
    method += `    );\n`;
    
    if (ret === 'void') {
      method += `    if (!fn) return;\n`;
      method += `    try { fn(${tsParamNames.join(', ')}); } catch { /* ignore */ }\n`;
    } else {
      method += `    if (!fn) return ${defaultRet};\n`;
      method += `    try { return fn(${tsParamNames.join(', ')}) || ${defaultRet}; } catch { return ${defaultRet}; }\n`;
    }
    
    method += `  }\n`;
    tsMethods.push(method);
  }
}

console.log(`Missing TS declarations: ${tsDecls.length}`);
console.log(`Missing TS methods: ${tsMethods.length}`);

// Update index.d.ts
if (tsDecls.length > 0) {
  const newIndex = indexContent.trimEnd() + '\n' + tsDecls.join('\n') + '\n';
  fs.writeFileSync(INDEX_D_TS, newIndex, 'utf-8');
  console.log(`Updated index.d.ts with ${tsDecls.length} declarations`);
}

// Update NativeRustDeskBridge.ts - insert before the last closing brace of the class
if (tsMethods.length > 0) {
  // Find the last static method's closing brace, then insert after it
  // Better: find the class closing brace
  // Look for the pattern of the last method before the closing }
  const classClosePos = nativeContent.lastIndexOf('\n}');
  if (classClosePos > 0) {
    const insertPos = classClosePos;
    const newContent = nativeContent.substring(0, insertPos) + 
      '\n  // ---- extended session & main functions ----\n' +
      tsMethods.join('\n') + '\n' + 
      nativeContent.substring(insertPos);
    fs.writeFileSync(NATIVE_BRIDGE_TS, newContent, 'utf-8');
    console.log(`Updated NativeRustDeskBridge.ts with ${tsMethods.length} methods`);
  } else {
    console.log('Could not find class closing brace in NativeRustDeskBridge.ts');
  }
}

// Update librustdesk_bridge.d.ts if it exists
try {
  const libContent = fs.readFileSync(LIB_BRIDGE_D_TS, 'utf-8');
  const existingLibNames = new Set();
  const libRe = /(\w+)\s*\(/g;
  while ((m = libRe.exec(libContent)) !== null) existingLibNames.add(m[1]);
  
  const libDecls = [];
  for (const { name, params, ret } of rustFns) {
    const camelName = toCamelCase(name);
    if (existingLibNames.has(camelName)) continue;
    const tsParams = params.map(p => rustParamToTs(p));
    libDecls.push(`  ${camelName}(${tsParams.join(', ')}): ${ret};`);
  }
  
  if (libDecls.length > 0) {
    const interfaceClose = libContent.lastIndexOf('}');
    const newLib = libContent.substring(0, interfaceClose) + 
      '\n' + libDecls.join('\n') + '\n' + 
      libContent.substring(interfaceClose);
    fs.writeFileSync(LIB_BRIDGE_D_TS, newLib, 'utf-8');
    console.log(`Updated librustdesk_bridge.d.ts with ${libDecls.length} declarations`);
  }
} catch (e) {
  console.log(`librustdesk_bridge.d.ts not found or error: ${e.message}`);
}

console.log('Done!');
