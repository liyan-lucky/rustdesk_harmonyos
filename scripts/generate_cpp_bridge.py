#!/usr/bin/env python3
"""Generate C ABI declarations, NAPI wrappers, and NAPI registrations from bridge_api.rs"""
import re
import sys

BRIDGE_API_RS = r"L:\Visual_Studio_Code\99_Temp\rustdesk-master\src\harmony_bridge\core.rs"
ABI_HEADER = r"L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_abi.h"
LOADER_CPP = r"L:\Visual_Studio_Code\11_Rustdesk_harmonyos\entry\src\main\cpp\rustdesk_bridge_loader.cpp"

# Read core.rs to get all pub fn signatures
with open(BRIDGE_API_RS, 'r', encoding='utf-8') as f:
    core_content = f.read()

# Extract all pub fn from core.rs (these are the Rust-side functions)
# We need to map them to C ABI names: rustdesk_bridge_<name>
rust_fns = []
# Match pub fn declarations
fn_pattern = r'pub fn (\w+)\(([^)]*)\)(?:\s*->\s*([^{]+))?'
for m in re.finditer(fn_pattern, core_content):
    name = m.group(1)
    params_str = m.group(2).strip()
    ret_str = m.group(3).strip() if m.group(3) else ''
    
    # Skip internal functions (not bridge API)
    internals = ['connect_state', 'local_options', 'latest_video_frame', 'active_session',
                 'incoming_service_started', 'update_connect_state', 'queue_event',
                 'current_timestamp_millis', 'next_bridge_job_id', 'escape_json',
                 'key_code_to_official_key_name', 'apply_server_options', 'read_cached_peer_info',
                 'peer_info_detail', 'mark_peer_connected_with_cached_info', 'option_is_enabled',
                 'publish_real_video_frame']
    if name in internals:
        continue
    
    # Parse parameters
    params = []
    if params_str:
        for p in params_str.split(','):
            p = p.strip()
            if not p:
                continue
            # Handle _prefix params
            parts = p.split(':')
            if len(parts) == 2:
                pname = parts[0].strip().lstrip('_')
                ptype = parts[1].strip()
                params.append((pname, ptype))
    
    # Determine return type
    if not ret_str or ret_str == '()':
        ret = 'void'
    elif ret_str == 'String':
        ret = 'string'
    elif ret_str == 'bool':
        ret = 'bool'
    elif ret_str in ('i32', 'c_int'):
        ret = 'i32'
    elif ret_str == 'u64':
        ret = 'u64'
    else:
        ret = ret_str
    
    rust_fns.append((name, params, ret))

print(f"Found {len(rust_fns)} pub fn in core.rs")

# Read existing ABI header
with open(ABI_HEADER, 'r', encoding='utf-8') as f:
    header_content = f.read()

existing_abi = set(re.findall(r'rustdesk_bridge_(\w+)\s*\(', header_content))
print(f"Existing ABI declarations: {len(existing_abi)}")

# Read existing loader
with open(LOADER_CPP, 'r', encoding='utf-8') as f:
    loader_content = f.read()

existing_napi = set(re.findall(r'"(\w+)",\s*nullptr,\s*(\w+)', loader_content))
existing_napi_names = {name for name, func in existing_napi}
print(f"Existing NAPI registrations: {len(existing_napi_names)}")

# Generate missing declarations
def rust_type_to_c(pname, ptype):
    """Convert Rust type to C type for ABI header"""
    if ptype == '&str':
        return 'const char *'
    elif ptype == 'bool':
        return 'int'
    elif ptype in ('i32', 'c_int'):
        return 'int'
    elif ptype == 'usize':
        return 'unsigned long long'
    elif ptype == 'u64':
        return 'unsigned long long'
    elif ptype == 'i64':
        return 'long long'
    elif ptype == '&mut [u8]':
        return 'unsigned char *'
    elif ptype == '*mut c_char':
        return 'char *'
    elif ptype == '*const c_char':
        return 'const char *'
    else:
        return ptype

def rust_ret_to_c(ret):
    if ret == 'string':
        return 'const char *'
    elif ret == 'bool':
        return 'int'
    elif ret == 'i32':
        return 'int'
    elif ret == 'void':
        return 'void'
    elif ret == 'u64':
        return 'unsigned long long'
    else:
        return ret

def to_camel_case(name):
    """Convert snake_case to camelCase"""
    parts = name.split('_')
    return parts[0] + ''.join(p.capitalize() for p in parts[1:])

def to_napi_class_name(name):
    """Convert snake_case to PascalCase for NAPI function"""
    return ''.join(p.capitalize() for p in name.split('_'))

# Generate PART 1: C ABI declarations
abi_lines = []
# Generate PART 2: NAPI wrappers
napi_lines = []
# Generate PART 3: NAPI registrations
napi_regs = []

for name, params, ret in rust_fns:
    abi_name = name  # without rustdesk_bridge_ prefix for check
    c_name = f"rustdesk_bridge_{name}"
    camel_name = to_camel_case(name)
    napi_class = to_napi_class_name(name)
    
    if abi_name in existing_abi and camel_name in existing_napi_names:
        continue  # Already exists
    
    # PART 1: C ABI declaration
    c_params = []
    for pname, ptype in params:
        ctype = rust_type_to_c(pname, ptype)
        if ptype == '&str' or ptype == 'bool':
            c_params.append(f"{ctype}")
        else:
            c_params.append(f"{ctype}")
    
    # Build C param list with names
    c_param_decls = []
    for i, (pname, ptype) in enumerate(params):
        ctype = rust_type_to_c(pname, ptype)
        if ptype == '&mut [u8]':
            c_param_decls.append(f"{ctype} buffer, unsigned long long buffer_len")
        elif ptype in ('&str',):
            c_param_decls.append(f"{ctype} {pname}")
        elif ptype == 'bool':
            c_param_decls.append(f"{ctype} {pname}")
        elif ptype == 'usize':
            c_param_decls.append(f"{ctype} {pname}")
        else:
            c_param_decls.append(f"{ctype} {pname}")
    
    cret = rust_ret_to_c(ret)
    
    if abi_name not in existing_abi:
        if not c_param_decls:
            abi_lines.append(f"{cret} {c_name}(void);")
        else:
            abi_lines.append(f"{cret} {c_name}({', '.join(c_param_decls)});")
    
    # PART 2: NAPI wrapper
    if camel_name not in existing_napi_names:
        # Generate NAPI function
        napi_func = f"napi_value {napi_class}(napi_env env, napi_callback_info info) {{\n"
        
        argc = len(params)
        # Skip buffer_len params (they come from ArrayBuffer)
        real_params = [(pn, pt) for pn, pt in params if pt != 'u64' or pn != 'buffer_len']
        
        if argc > 0:
            napi_func += f"  size_t argc = {argc};\n"
            napi_func += f"  napi_value args[{argc}] = {{nullptr}};\n"
            napi_func += f"  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);\n"
        
        # Read parameters
        var_names = []
        for i, (pname, ptype) in enumerate(params):
            if ptype == '&str':
                napi_func += f"  std::string {pname};\n"
                napi_func += f"  if (argc > {i}) ReadUtf8String(env, args[{i}], &{pname});\n"
                var_names.append(pname)
            elif ptype == 'bool':
                napi_func += f"  bool {pname} = false;\n"
                napi_func += f"  if (argc > {i}) napi_get_value_bool(env, args[{i}], &{pname});\n"
                var_names.append(pname)
            elif ptype in ('i32', 'c_int'):
                napi_func += f"  int32_t {pname} = 0;\n"
                napi_func += f"  if (argc > {i}) napi_get_value_int32(env, args[{i}], &{pname});\n"
                var_names.append(pname)
            elif ptype == 'usize':
                napi_func += f"  int64_t {pname} = 0;\n"
                napi_func += f"  if (argc > {i}) napi_get_value_int64(env, args[{i}], &{pname});\n"
                var_names.append(pname)
            elif ptype == 'i64':
                napi_func += f"  int64_t {pname} = 0;\n"
                napi_func += f"  if (argc > {i}) napi_get_value_int64(env, args[{i}], &{pname});\n"
                var_names.append(pname)
        
        # Build C call arguments
        call_args = []
        for pname, ptype in params:
            if ptype == '&str':
                call_args.append(f"{pname}.c_str()")
            elif ptype == 'bool':
                call_args.append(f"{pname} ? 1 : 0")
            elif ptype == 'usize':
                call_args.append(f"static_cast<unsigned long long>({pname})")
            else:
                call_args.append(pname)
        
        call = f"{c_name}({', '.join(call_args)})"
        
        # Return value handling
        if ret == 'void':
            napi_func += f"  {call};\n"
            napi_func += f"  napi_value undefined = nullptr;\n"
            napi_func += f"  napi_get_undefined(env, &undefined);\n"
            napi_func += f"  return undefined;\n"
        elif ret == 'bool':
            napi_func += f"  return MakeBool(env, {call} != 0);\n"
        elif ret == 'string':
            napi_func += f"  return MakeString(env, CopyOwnedText({call}));\n"
        elif ret == 'i32':
            napi_func += f"  int32_t result_val = {call};\n"
            napi_func += f"  napi_value result = nullptr;\n"
            napi_func += f"  napi_create_int32(env, result_val, &result);\n"
            napi_func += f"  return result;\n"
        else:
            napi_func += f"  {call};\n"
            napi_func += f"  napi_value undefined = nullptr;\n"
            napi_func += f"  napi_get_undefined(env, &undefined);\n"
            napi_func += f"  return undefined;\n"
        
        napi_func += f"}}\n"
        napi_lines.append(napi_func)
        
        # PART 3: NAPI registration
        napi_regs.append(f'    {{"{camel_name}", nullptr, {napi_class}, nullptr, nullptr, nullptr, napi_default, nullptr}},')

# Output
print(f"\nMissing ABI declarations: {len(abi_lines)}")
print(f"Missing NAPI wrappers: {len(napi_lines)}")
print(f"Missing NAPI registrations: {len(napi_regs)}")

# Write to files
if abi_lines:
    # Insert before #ifdef __cplusplus
    insert_pos = header_content.rfind('#ifdef __cplusplus')
    new_header = header_content[:insert_pos] + '\n'.join(abi_lines) + '\n\n' + header_content[insert_pos:]
    with open(ABI_HEADER, 'w', encoding='utf-8') as f:
        f.write(new_header)
    print(f"Updated ABI header with {len(abi_lines)} new declarations")

if napi_lines:
    # Insert before } // namespace
    insert_pos = loader_content.rfind('} // namespace')
    napi_block = '\n'.join(napi_lines) + '\n\n'
    new_loader = loader_content[:insert_pos] + napi_block + loader_content[insert_pos:]
    
    # Insert NAPI registrations before the closing brace of desc[]
    desc_close = new_loader.rfind('  };')
    desc_pos = new_loader.rfind('{', 0, desc_close)  # Find the opening of desc[]
    # Actually find the line with the last registration entry before };
    # Insert before the closing };
    reg_block = '\n'.join(napi_regs) + '\n'
    new_loader = new_loader[:desc_close] + reg_block + new_loader[desc_close:]
    
    with open(LOADER_CPP, 'w', encoding='utf-8') as f:
        f.write(new_loader)
    print(f"Updated loader with {len(napi_lines)} new NAPI wrappers and {len(napi_regs)} registrations")

print("\nDone!")
