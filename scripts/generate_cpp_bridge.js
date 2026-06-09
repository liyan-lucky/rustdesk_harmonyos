const fs = require('fs');
const path = require('path');

const CORE_RS = String.raw`L:\Visual_Studio_Code\99_Temp\rustdesk-master\src\harmony_bridge\core.rs`;
const ABI_HEADER = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_abi.h`;
const LOADER_CPP = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_loader.cpp`;

const coreContent = fs.readFileSync(CORE_RS, 'utf-8');
const headerContent = fs.readFileSync(ABI_HEADER, 'utf-8');
const loaderContent = fs.readFileSync(LOADER_CPP, 'utf-8');

// Extract existing ABI function names
const existingAbi = new Set();
const abiRe = /rustdesk_bridge_(\w+)\s*\(/g;
let m;
while ((m = abiRe.exec(headerContent)) !== null) existingAbi.add(m[1]);

// Extract existing NAPI registration names
const existingNapi = new Set();
const napiRe = /"(\w+)",\s*nullptr,\s*\w+/g;
while ((m = napiRe.exec(loaderContent)) !== null) existingNapi.add(m[1]);

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
    // Split by comma, but handle nested types
    let depth = 0, current = '';
    for (const ch of paramsStr) {
      if (ch === '<' || ch === '(') depth++;
      if (ch === '>' || ch === ')') depth--;
      if (ch === ',' && depth === 0) {
        params.push(current.trim());
        current = '';
      } else {
        current += ch;
      }
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
  else if (retStr === 'bool') ret = 'bool';
  else if (retStr === 'i32' || retStr === 'c_int') ret = 'i32';
  else if (retStr === 'u64') ret = 'u64';
  else ret = retStr;
  
  rustFns.push({ name, params: parsedParams, ret });
}

console.log(`Found ${rustFns.length} pub fn in core.rs`);
console.log(`Existing ABI: ${existingAbi.size}, Existing NAPI: ${existingNapi.size}`);

// Type conversion helpers
function rustTypeToC(ptype) {
  if (ptype === '&str') return 'const char *';
  if (ptype === 'bool') return 'int';
  if (ptype === 'i32' || ptype === 'c_int') return 'int';
  if (ptype === 'usize') return 'unsigned long long';
  if (ptype === 'u64') return 'unsigned long long';
  if (ptype === 'i64') return 'long long';
  return ptype;
}

function rustRetToC(ret) {
  if (ret === 'string') return 'const char *';
  if (ret === 'bool') return 'int';
  if (ret === 'i32') return 'int';
  if (ret === 'void') return 'void';
  if (ret === 'u64') return 'unsigned long long';
  return ret;
}

function toCamelCase(name) {
  return name.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

function toPascalCase(name) {
  return name.split('_').map(p => p.charAt(0).toUpperCase() + p.slice(1)).join('');
}

const abiLines = [];
const napiLines = [];
const napiRegs = [];

for (const { name, params, ret } of rustFns) {
  const cName = `rustdesk_bridge_${name}`;
  const camelName = toCamelCase(name);
  const napiClass = toPascalCase(name);
  
  const inAbi = existingAbi.has(name);
  const inNapi = existingNapi.has(camelName);
  
  if (inAbi && inNapi) continue;
  
  // PART 1: C ABI declaration
  if (!inAbi) {
    const cParamDecls = params.map(p => `${rustTypeToC(p.type)} ${p.name}`);
    const cret = rustRetToC(ret);
    if (cParamDecls.length === 0) {
      abiLines.push(`${cret} ${cName}(void);`);
    } else {
      abiLines.push(`${cret} ${cName}(${cParamDecls.join(', ')});`);
    }
  }
  
  // PART 2: NAPI wrapper
  if (!inNapi) {
    const argc = params.length;
    let code = `napi_value ${napiClass}(napi_env env, napi_callback_info info) {\n`;
    
    if (argc > 0) {
      code += `  size_t argc = ${argc};\n`;
      code += `  napi_value args[${argc}] = {nullptr};\n`;
      code += `  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);\n`;
    }
    
    // Read params
    for (let i = 0; i < params.length; i++) {
      const p = params[i];
      if (p.type === '&str') {
        code += `  std::string ${p.name};\n`;
        code += `  if (argc > ${i}) ReadUtf8String(env, args[${i}], &${p.name});\n`;
      } else if (p.type === 'bool') {
        code += `  bool ${p.name} = false;\n`;
        code += `  if (argc > ${i}) napi_get_value_bool(env, args[${i}], &${p.name});\n`;
      } else if (p.type === 'i32' || p.type === 'c_int') {
        code += `  int32_t ${p.name} = 0;\n`;
        code += `  if (argc > ${i}) napi_get_value_int32(env, args[${i}], &${p.name});\n`;
      } else if (p.type === 'usize' || p.type === 'u64') {
        code += `  int64_t ${p.name} = 0;\n`;
        code += `  if (argc > ${i}) napi_get_value_int64(env, args[${i}], &${p.name});\n`;
      } else if (p.type === 'i64') {
        code += `  int64_t ${p.name} = 0;\n`;
        code += `  if (argc > ${i}) napi_get_value_int64(env, args[${i}], &${p.name});\n`;
      }
    }
    
    // Build call args
    const callArgs = params.map(p => {
      if (p.type === '&str') return `${p.name}.c_str()`;
      if (p.type === 'bool') return `${p.name} ? 1 : 0`;
      if (p.type === 'usize' || p.type === 'u64') return `static_cast<unsigned long long>(${p.name})`;
      return p.name;
    });
    
    const call = `${cName}(${callArgs.join(', ')})`;
    
    if (ret === 'void') {
      code += `  ${call};\n`;
      code += `  napi_value undefined = nullptr;\n`;
      code += `  napi_get_undefined(env, &undefined);\n`;
      code += `  return undefined;\n`;
    } else if (ret === 'bool') {
      code += `  return MakeBool(env, ${call} != 0);\n`;
    } else if (ret === 'string') {
      code += `  return MakeString(env, CopyOwnedText(${call}));\n`;
    } else if (ret === 'i32') {
      code += `  int32_t result_val = ${call};\n`;
      code += `  napi_value result = nullptr;\n`;
      code += `  napi_create_int32(env, result_val, &result);\n`;
      code += `  return result;\n`;
    } else {
      code += `  ${call};\n`;
      code += `  napi_value undefined = nullptr;\n`;
      code += `  napi_get_undefined(env, &undefined);\n`;
      code += `  return undefined;\n`;
    }
    
    code += `}\n`;
    napiLines.push(code);
    napiRegs.push(`    {"${camelName}", nullptr, ${napiClass}, nullptr, nullptr, nullptr, napi_default, nullptr},`);
  }
}

console.log(`Missing ABI: ${abiLines.length}, Missing NAPI: ${napiLines.length}, Missing regs: ${napiRegs.length}`);

// Update ABI header
if (abiLines.length > 0) {
  const insertPos = headerContent.lastIndexOf('#ifdef __cplusplus');
  const newHeader = headerContent.substring(0, insertPos) + 
    '// ---- extended session & main functions ----\n' +
    abiLines.join('\n') + '\n\n' + headerContent.substring(insertPos);
  fs.writeFileSync(ABI_HEADER, newHeader, 'utf-8');
  console.log(`Updated ABI header with ${abiLines.length} declarations`);
}

// Update loader
if (napiLines.length > 0) {
  // Insert NAPI functions before } // namespace
  const namespaceEnd = loaderContent.lastIndexOf('} // namespace');
  const napiBlock = '\n' + napiLines.join('\n') + '\n';
  let newLoader = loaderContent.substring(0, namespaceEnd) + napiBlock + loaderContent.substring(namespaceEnd);
  
  // Insert NAPI registrations before the closing }; of desc[]
  const descClose = newLoader.lastIndexOf('  };');
  const regBlock = napiRegs.join('\n') + '\n';
  newLoader = newLoader.substring(0, descClose) + regBlock + newLoader.substring(descClose);
  
  fs.writeFileSync(LOADER_CPP, newLoader, 'utf-8');
  console.log(`Updated loader with ${napiLines.length} NAPI wrappers and ${napiRegs.length} registrations`);
}

console.log('Done!');
