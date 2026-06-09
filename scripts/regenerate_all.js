const fs = require('fs');
const path = require('path');

const CORE_RS = String.raw`L:\Visual_Studio_Code\99_Temp\rustdesk-master\src\harmony_bridge\core.rs`;
const LOADER_CPP = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_loader.cpp`;
const ABI_HEADER = String.raw`L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_abi.h`;

const coreContent = fs.readFileSync(CORE_RS, 'utf-8');
const loaderContent = fs.readFileSync(LOADER_CPP, 'utf-8');

// Parse core.rs pub fn
const internals = new Set([
  'connect_state','local_options','latest_video_frame','active_session',
  'incoming_service_started','update_connect_state','queue_event',
  'current_timestamp_millis','next_bridge_job_id','escape_json',
  'key_code_to_official_key_name','apply_server_options','read_cached_peer_info',
  'peer_info_detail','mark_peer_connected_with_cached_info','option_is_enabled',
  'publish_real_video_frame','get_local_option','set_local_option'
]);

const fnRe = /pub fn (\w+)\(([^)]*)\)(?:\s*->\s*([^{]+?))?\s*\{/g;
const fns = [];
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
  else if (retStr === 'bool') ret = 'bool';
  else if (retStr === 'i32' || retStr === 'c_int') ret = 'i32';
  else if (retStr === 'u64') ret = 'u64';
  else if (retStr === 'i64') ret = 'i64';
  else if (retStr === 'f64') ret = 'f64';
  else if (retStr === 'usize') ret = 'usize';
  else ret = retStr;
  
  fns.push({ name, params: parsedParams, ret });
}

console.log(`Found ${fns.length} pub fn in core.rs`);

// Generate complete ABI header
let abiContent = `#pragma once

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

`;

function rustTypeToC(ptype) {
  if (ptype === '&str') return 'const char *';
  if (ptype === 'bool') return 'int';
  if (ptype === 'i32' || ptype === 'c_int') return 'int';
  if (ptype === 'usize' || ptype === 'u64') return 'unsigned long long';
  if (ptype === 'i64') return 'long long';
  if (ptype === 'f64') return 'double';
  return ptype;
}

function rustRetToC(ret) {
  if (ret === 'string') return 'const char *';
  if (ret === 'bool') return 'int';
  if (ret === 'i32') return 'int';
  if (ret === 'void') return 'void';
  if (ret === 'u64' || ret === 'usize') return 'unsigned long long';
  if (ret === 'i64') return 'long long';
  if (ret === 'f64') return 'double';
  return ret;
}

for (const { name, params, ret } of fns) {
  const cName = `rustdesk_bridge_${name}`;
  const cParamDecls = params.map(p => `${rustTypeToC(p.type)} ${p.name}`);
  const cret = rustRetToC(ret);
  if (cParamDecls.length === 0) {
    abiContent += `${cret} ${cName}(void);\n`;
  } else {
    abiContent += `${cret} ${cName}(${cParamDecls.join(', ')});\n`;
  }
}

abiContent += `
#ifdef __cplusplus
}
#endif
`;

fs.writeFileSync(ABI_HEADER, abiContent, 'utf-8');
console.log(`Generated ABI header with ${fns.length} declarations`);

// Generate complete loader.cpp
// Keep the header section (includes + helper functions) from original
const loaderLines = loaderContent.split('\n');
let headerEnd = 0;
for (let i = 0; i < loaderLines.length; i++) {
  if (loaderLines[i].match(/^namespace \{/)) {
    headerEnd = i;
    break;
  }
}

const headerSection = loaderLines.slice(0, headerEnd).join('\n');

function toCamelCase(name) {
  return name.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
}

function toPascalCase(name) {
  return name.split('_').map(p => p.charAt(0).toUpperCase() + p.slice(1)).join('');
}

function rustParamToTs(p) {
  if (p.type === '&str') return `${p.name}: string`;
  if (p.type === 'bool') return `${p.name}: boolean`;
  if (['i32','c_int','usize','u64','i64','f64'].includes(p.type)) return `${p.name}: number`;
  return `${p.name}: any`;
}

// Generate NAPI functions
let napiFuncs = '';
let descEntries = '';

for (const { name, params, ret } of fns) {
  const cName = `rustdesk_bridge_${name}`;
  const camelName = toCamelCase(name);
  const napiClass = toPascalCase(name);
  const argc = params.length;
  
  let func = `napi_value ${napiClass}(napi_env env, napi_callback_info info) {\n`;
  
  if (argc > 0) {
    func += `  size_t argc = ${argc};\n`;
    func += `  napi_value args[${argc}] = {nullptr};\n`;
    func += `  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);\n`;
  }
  
  for (let i = 0; i < params.length; i++) {
    const p = params[i];
    if (p.type === '&str') {
      func += `  std::string ${p.name};\n`;
      func += `  if (argc > ${i}) ReadUtf8String(env, args[${i}], &${p.name});\n`;
    } else if (p.type === 'bool') {
      func += `  bool ${p.name} = false;\n`;
      func += `  if (argc > ${i}) napi_get_value_bool(env, args[${i}], &${p.name});\n`;
    } else if (p.type === 'i32' || p.type === 'c_int') {
      func += `  int32_t ${p.name} = 0;\n`;
      func += `  if (argc > ${i}) napi_get_value_int32(env, args[${i}], &${p.name});\n`;
    } else if (p.type === 'usize' || p.type === 'u64' || p.type === 'i64') {
      func += `  int64_t ${p.name} = 0;\n`;
      func += `  if (argc > ${i}) napi_get_value_int64(env, args[${i}], &${p.name});\n`;
    } else if (p.type === 'f64') {
      func += `  double ${p.name} = 0.0;\n`;
      func += `  if (argc > ${i}) napi_get_value_double(env, args[${i}], &${p.name});\n`;
    }
  }
  
  const callArgs = params.map(p => {
    if (p.type === '&str') return `${p.name}.c_str()`;
    if (p.type === 'bool') return `${p.name} ? 1 : 0`;
    if (p.type === 'usize' || p.type === 'u64') return `static_cast<unsigned long long>(${p.name})`;
    return p.name;
  });
  
  const call = `${cName}(${callArgs.join(', ')})`;
  
  if (ret === 'void') {
    func += `  ${call};\n`;
    func += `  napi_value undefined = nullptr;\n`;
    func += `  napi_get_undefined(env, &undefined);\n`;
    func += `  return undefined;\n`;
  } else if (ret === 'bool') {
    func += `  return MakeBool(env, ${call} != 0);\n`;
  } else if (ret === 'string') {
    func += `  return MakeString(env, CopyOwnedText(${call}));\n`;
  } else if (ret === 'i32') {
    func += `  int32_t result_val = ${call};\n`;
    func += `  napi_value result = nullptr;\n`;
    func += `  napi_create_int32(env, result_val, &result);\n`;
    func += `  return result;\n`;
  } else if (ret === 'f64') {
    func += `  double result_val = ${call};\n`;
    func += `  napi_value result = nullptr;\n`;
    func += `  napi_create_double(env, result_val, &result);\n`;
    func += `  return result;\n`;
  } else if (ret === 'u64' || ret === 'usize' || ret === 'i64') {
    func += `  int64_t result_val = static_cast<int64_t>(${call});\n`;
    func += `  napi_value result = nullptr;\n`;
    func += `  napi_create_int64(env, result_val, &result);\n`;
    func += `  return result;\n`;
  } else {
    func += `  ${call};\n`;
    func += `  napi_value undefined = nullptr;\n`;
    func += `  napi_get_undefined(env, &undefined);\n`;
    func += `  return undefined;\n`;
  }
  
  func += `}\n\n`;
  napiFuncs += func;
  descEntries += `    {"${camelName}", nullptr, ${napiClass}, nullptr, nullptr, nullptr, napi_default, nullptr},\n`;
}

// Build complete loader.cpp
const fullLoader = `${headerSection}
namespace {

${napiFuncs}
} // namespace

napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
${descEntries}
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, "RustDeskLoader", 
    "RustDesk bridge loader module registered (%d functions)", 
    (int)(sizeof(desc) / sizeof(desc[0])));
  return exports;
}

NAPI_MODULE("rustdesk_bridge", Init)
`;

fs.writeFileSync(LOADER_CPP, fullLoader, 'utf-8');
console.log(`Generated complete loader.cpp with ${fns.length} NAPI functions`);
