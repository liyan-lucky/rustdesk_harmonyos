const fs = require('fs');
const path = require('path');

const CORE_RS = String.raw`L:\Visual_Studio_Code\99_Temp\rustdesk-master\src\harmony_bridge\core.rs`;
const BRIDGE_API_RS = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\native_rust_core\src\bridge_api.rs`;

const coreContent = fs.readFileSync(CORE_RS, 'utf-8');
const bridgeContent = fs.readFileSync(BRIDGE_API_RS, 'utf-8');

const internals = new Set([
  'connect_state', 'local_options', 'latest_video_frame', 'active_session',
  'incoming_service_started', 'update_connect_state', 'queue_event',
  'current_timestamp_millis', 'next_bridge_job_id', 'escape_json',
  'key_code_to_official_key_name', 'apply_server_options', 'read_cached_peer_info',
  'peer_info_detail', 'mark_peer_connected_with_cached_info', 'option_is_enabled',
  'publish_real_video_frame'
]);

const fnRe = /pub fn (\w+)\(([^)]*)\)(?:\s*->\s*([^{]+?))?\s*\{/g;
const coreFns = [];
while ((m = fnRe.exec(coreContent)) !== null) {
  const name = m[1];
  if (internals.has(name)) continue;
  coreFns.push(name);
}

const existingBridge = new Set();
const bridgeRe = /fn rustdesk_bridge_(\w+)\s*\(/g;
while ((m = bridgeRe.exec(bridgeContent)) !== null) existingBridge.add(m[1]);

const missing = coreFns.filter(n => !existingBridge.has(n));
console.log(`Core fns: ${coreFns.length}, Bridge fns: ${existingBridge.size}, Missing: ${missing.length}`);

// For each missing function, generate a bridge_api.rs entry
// We need to know the parameter types and return type
// Parse from core.rs more carefully
const fnDetailsRe = /pub fn (\w+)\(([^)]*)\)(?:\s*->\s*([^{]+?))?\s*\{/g;
const fnMap = new Map();
while ((m = fnDetailsRe.exec(coreContent)) !== null) {
  fnMap.set(m[1], { params: m[2].trim(), ret: m[3] ? m[3].trim() : '' });
}

function rustTypeToC(type) {
  type = type.trim();
  if (type === '&str') return '*const c_char';
  if (type === 'bool') return 'c_int';
  if (type === 'i32' || type === 'c_int') return 'c_int';
  if (type === 'i64') return 'i64';
  if (type === 'u64') return 'u64';
  if (type === 'usize') return 'usize';
  if (type === 'f64') return 'f64';
  if (type === 'String') return '*const c_char';
  return type;
}

function isReturnString(ret) {
  return ret === 'String';
}

function isReturnBool(ret) {
  return ret === 'bool';
}

function isReturnVoid(ret) {
  return !ret || ret === '()' || ret === 'void';
}

function isReturnI32(ret) {
  return ret === 'i32' || ret === 'c_int';
}

function isReturnUsize(ret) {
  return ret === 'usize';
}

function isReturnF64(ret) {
  return ret === 'f64';
}

function isReturnU64(ret) {
  return ret === 'u64';
}

function isReturnI64(ret) {
  return ret === 'i64';
}

const newEntries = [];

for (const name of missing) {
  const info = fnMap.get(name);
  if (!info) { console.log(`WARN: no info for ${name}`); continue; }
  
  const paramsStr = info.params;
  const ret = info.ret;
  
  // Parse params
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
  
  // Build C ABI params
  const cParams = [];
  const callArgs = [];
  
  for (const p of parsedParams) {
    const ctype = rustTypeToC(p.type);
    cParams.push(`${p.name}: ${ctype}`);
    
    if (p.type === '&str') {
      callArgs.push(`&${p.name}`);
    } else if (p.type === 'bool') {
      callArgs.push(`${p.name} != 0`);
    } else {
      callArgs.push(p.name);
    }
  }
  
  // Build C ABI return type
  let cRet = '()';
  let retExpr = '';
  
  if (isReturnString(ret)) {
    cRet = '*const c_char';
    retExpr = `to_owned_c_string(rustdesk_core::harmony_bridge::${name}(${callArgs.join(', ')}))`;
  } else if (isReturnBool(ret)) {
    cRet = 'c_int';
    retExpr = `if rustdesk_core::harmony_bridge::${name}(${callArgs.join(', ')}) { 1 } else { 0 }`;
  } else if (isReturnI32(ret) || isReturnUsize(ret)) {
    cRet = rustTypeToC(ret);
    retExpr = `rustdesk_core::harmony_bridge::${name}(${callArgs.join(', ')})`;
  } else if (isReturnF64(ret)) {
    cRet = 'f64';
    retExpr = `rustdesk_core::harmony_bridge::${name}(${callArgs.join(', ')})`;
  } else if (isReturnU64(ret) || isReturnI64(ret)) {
    cRet = rustTypeToC(ret);
    retExpr = `rustdesk_core::harmony_bridge::${name}(${callArgs.join(', ')})`;
  } else {
    // void or unknown
    retExpr = `rustdesk_core::harmony_bridge::${name}(${callArgs.join(', ')})`;
  }
  
  // Generate the function
  let fnCode = '';
  
  if (isReturnString(ret)) {
    // Need to read &str params first
    const strParams = parsedParams.filter(p => p.type === '&str');
    const otherParams = parsedParams.filter(p => p.type !== '&str');
    
    fnCode += `#[no_mangle]\n`;
    fnCode += `pub extern "C" fn rustdesk_bridge_${name}(${cParams.join(', ')}) -> ${cRet} {\n`;
    for (const p of strParams) {
      fnCode += `    let ${p.name} = read_c_string(${p.name});\n`;
    }
    fnCode += `    ${retExpr}\n`;
    fnCode += `}\n\n`;
  } else if (isReturnBool(ret)) {
    const strParams = parsedParams.filter(p => p.type === '&str');
    
    fnCode += `#[no_mangle]\n`;
    fnCode += `pub extern "C" fn rustdesk_bridge_${name}(${cParams.join(', ')}) -> ${cRet} {\n`;
    for (const p of strParams) {
      fnCode += `    let ${p.name} = read_c_string(${p.name});\n`;
    }
    fnCode += `    ${retExpr}\n`;
    fnCode += `}\n\n`;
  } else if (isReturnVoid(ret)) {
    const strParams = parsedParams.filter(p => p.type === '&str');
    
    fnCode += `#[no_mangle]\n`;
    fnCode += `pub extern "C" fn rustdesk_bridge_${name}(${cParams.join(', ')}) {\n`;
    for (const p of strParams) {
      fnCode += `    let ${p.name} = read_c_string(${p.name});\n`;
    }
    fnCode += `    ${retExpr};\n`;
    fnCode += `}\n\n`;
  } else {
    const strParams = parsedParams.filter(p => p.type === '&str');
    
    fnCode += `#[no_mangle]\n`;
    fnCode += `pub extern "C" fn rustdesk_bridge_${name}(${cParams.join(', ')}) -> ${cRet} {\n`;
    for (const p of strParams) {
      fnCode += `    let ${p.name} = read_c_string(${p.name});\n`;
    }
    fnCode += `    ${retExpr}\n`;
    fnCode += `}\n\n`;
  }
  
  newEntries.push(fnCode);
}

// Append to bridge_api.rs
const insertPos = bridgeContent.lastIndexOf('fn rustdesk_bridge_');
const lastFnEnd = bridgeContent.indexOf('\n}', insertPos) + 2;

const newContent = bridgeContent.substring(0, lastFnEnd) + '\n\n' + 
  '// ---- extended functions (auto-generated) ----\n\n' +
  newEntries.join('') + 
  bridgeContent.substring(lastFnEnd);

fs.writeFileSync(BRIDGE_API_RS, newContent, 'utf-8');
console.log(`Added ${newEntries.length} new bridge functions`);
