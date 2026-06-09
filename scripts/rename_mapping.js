// OHOS自定义名 → 官方wire_名 的映射
// 基于功能语义匹配
const RENAME_MAP = {
  // session 操作 - OHOS自定义 → 官方名
  "close_session": "session_close",
  "reconnect_session": "session_reconnect",
  "restart_remote_device": "session_restart_remote_device",
  "lock_remote_screen": "session_ctrl_alt_del",  // lock_screen在官方没有独立wire_,用ctrl_alt_del近似
  "send_ctrl_alt_del": "session_ctrl_alt_del",   // 同上，合并
  "read_remote_directory": "session_read_remote_dir",
  "create_remote_directory": "session_create_dir",
  "send_chat_message": "session_send_chat",
  "send_mouse_input": "session_send_mouse",
  "send_keyboard_input": "session_input_key",    // 官方已有session_input_key，这个是重复
  "send_clipboard_data": "session_input_string",  // 官方已有session_input_string
  "open_terminal": "session_open_terminal",
  "send_terminal_input": "session_send_terminal_input",
  "resize_terminal": "session_resize_terminal",
  "close_terminal": "session_close_terminal",
  "start_file_transfer": "session_send_files",    // 官方已有session_send_files
  "refresh_session_video": "session_refresh",     // 不完全对应但语义接近
  "apply_session_option": "session_set_option",   // 官方已有session_set_option
  "mark_session_connected": "session_start",      // 近似
  "submit_session_password": "session_login",     // 官方没有session_login wire_,但有session_login
  
  // main 级别
  "main_option_synced": "option_synced",
  "main_use_texture_render": "main_get_use_texture_render",
  "get_local_option": "main_get_local_option",
  "set_local_option": "main_set_local_option",
  "account_auth": "main_account_auth",
  "account_auth_cancel": "main_account_auth_cancel",
  "account_auth_result": "main_account_auth_result",
  "discover_lan_peers": "main_discover",
  "load_lan_peers": "main_load_lan_peers",
  "remove_discovered_peer": "main_remove_discovered",
  
  // 其他
  "string_free": "free",  // C标准函数，不需要映射
};

// 需要新增的官方名函数（OHOS完全没有对应实现的）
const NEW_OFFICIAL_FUNCS = [
  "session_add_existed_sync",
  "session_add_job",
  "session_add_sync",
  "session_enter_or_leave",
  "session_get_audit_guid",
  "session_get_audit_server_sync",
  "session_get_common",
  "session_get_common_sync",
  "session_get_conn_session_id",
  "session_get_displays_as_individual_windows",
  "session_get_edge_scroll_edge_thickness",
  "session_get_last_audit_note",
  "session_get_reverse_mouse_wheel_sync",
  "session_get_rgba_size",
  "session_get_toggle_option",
  "session_get_toggle_option_sync",
  "session_get_use_all_my_displays_for_the_remote_session",
  "session_handle_screenshot",
  "session_is_multi_ui_session",
  "session_next_rgba",
  "session_on_waiting_for_image_dialog_show",
  "session_printer_response",
  "session_read_dir_to_remove_recursive",
  "session_read_local_dir_sync",
  "session_read_local_empty_dirs_recursive_sync",
  "session_read_remote_empty_dirs_recursive_sync",
  "session_register_gpu_texture",
  "session_register_pixelbuffer_texture",
  "session_remove_all_empty_dirs",
  "session_request_new_display_init_msgs",
  "session_set_audit_guid",
  "session_set_displays_as_individual_windows",
  "session_set_edge_scroll_edge_thickness",
  "session_set_use_all_my_displays_for_the_remote_session",
  "session_start_with_displays",
  "main_init",
];

console.log("=== RENAME MAP (OHOS→Official) ===");
for (const [from, to] of Object.entries(RENAME_MAP)) {
  console.log(`  ${from} → ${to}`);
}
console.log(`\nTotal renames: ${Object.keys(RENAME_MAP).length}`);
console.log(`New official funcs needed: ${NEW_OFFICIAL_FUNCS.length}`);
