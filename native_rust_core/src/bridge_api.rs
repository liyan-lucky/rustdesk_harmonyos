use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

use crate::bridge_state;

fn read_c_string(value: *const c_char) -> String {
    if value.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(value) }
        .to_string_lossy()
        .trim()
        .to_owned()
}

fn to_owned_c_string(value: String) -> *const c_char {
    CString::new(value)
        .expect("bridge JSON should not contain embedded null bytes")
        .into_raw()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_core_snapshot(server: *const c_char) -> *const c_char {
    let server = read_c_string(server);
    let core_result = rustdesk_core::harmony_bridge::get_core_snapshot_json(&server);
    if core_result.trim() == "{}" || core_result.trim().is_empty() {
        let store = bridge_state::snapshot_store();
        let mut guard = store.lock().expect("snapshot mutex");
        guard.server = server.clone();
        to_owned_c_string(guard.to_json())
    } else {
        to_owned_c_string(core_result)
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_initialize_runtime(
    app_dir: *const c_char,
    custom_client_config: *const c_char,
) -> *const c_char {
    let app_dir = read_c_string(app_dir);
    let custom_client_config = read_c_string(custom_client_config);
    let core_result =
        rustdesk_core::harmony_bridge::initialize_runtime(&app_dir, &custom_client_config);
    if core_result.trim() == "{}" || core_result.trim().is_empty() {
        let store = bridge_state::snapshot_store();
        let mut guard = store.lock().expect("snapshot mutex");
        guard.adapter = "official-native".to_owned();
        guard.core_ready = true;
        guard.status_summary = "Official Harmony bridge ready".to_owned();
        guard.detail_message = format!(
            "HarmonyOS NAPI bridge initialized. appDir={}",
            if app_dir.is_empty() {
                "(empty)"
            } else {
                &app_dir
            }
        );
        to_owned_c_string(guard.to_json())
    } else {
        let store = bridge_state::snapshot_store();
        let mut guard = store.lock().expect("snapshot mutex");
        guard.adapter = "official-native".to_owned();
        guard.core_ready = true;
        guard.status_summary = "Official Harmony bridge ready".to_owned();
        drop(guard);
        to_owned_c_string(core_result)
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_pull_session_events() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::pull_session_events_json())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_pull_audio_frames() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::pull_audio_frames_json())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_latest_video_frame_metadata(
    since_frame_id: u64,
) -> *const c_char {
    to_owned_c_string(
        rustdesk_core::harmony_bridge::get_latest_video_frame_metadata_json(since_frame_id),
    )
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_copy_latest_video_frame(
    frame_id: u64,
    buffer: *mut u8,
    buffer_len: usize,
) -> c_int {
    if buffer.is_null() || buffer_len == 0 {
        return 0;
    }
    let target = unsafe { std::slice::from_raw_parts_mut(buffer, buffer_len) };
    rustdesk_core::harmony_bridge::copy_latest_video_frame(frame_id, target)
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_refresh_session_video(display: c_int) -> c_int {
    if rustdesk_core::harmony_bridge::refresh_session_video(display) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_harmony_next_rgba(display: c_int) {
    if display >= 0 {
        rustdesk_core::harmony_bridge::harmony_next_rgba(display as usize);
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_start_service(
    enabled: c_int,
    server: *const c_char,
    relay_server: *const c_char,
    api_server: *const c_char,
) -> *const c_char {
    let server = read_c_string(server);
    let relay_server = read_c_string(relay_server);
    let api_server = read_c_string(api_server);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_start_service(
        enabled != 0,
        &server,
        &relay_server,
        &api_server,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_bootstrap_core_snapshot(
    display_id: *const c_char,
    fingerprint: *const c_char,
    direct_address: *const c_char,
    server: *const c_char,
) -> *const c_char {
    let display_id = read_c_string(display_id);
    let fingerprint = read_c_string(fingerprint);
    let direct_address = read_c_string(direct_address);
    let server = read_c_string(server);
    to_owned_c_string(rustdesk_core::harmony_bridge::bootstrap_core_snapshot(
        &display_id,
        &fingerprint,
        &direct_address,
        &server,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_mouse(mask: c_int, x: c_int, y: c_int) -> c_int {
    if rustdesk_core::harmony_bridge::session_send_mouse(mask, x, y) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_input_key(
    key_code: c_int,
    is_pressed: c_int,
    modifiers: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::session_input_key(key_code, is_pressed != 0, modifiers) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_send_clipboard_data(
    content: *const c_char,
    timestamp: i64,
) -> c_int {
    let content = read_c_string(content);
    if rustdesk_core::harmony_bridge::send_clipboard_data(&content, timestamp) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_send_video_frame_metadata(
    codec: c_int,
    width: c_int,
    height: c_int,
    timestamp: i64,
    key_frame: c_int,
    data_length: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::send_video_frame_metadata(
        codec,
        width,
        height,
        timestamp,
        key_frame != 0,
        data_length,
    ) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_send_audio_frame_metadata(
    codec: c_int,
    sample_rate: c_int,
    channels: c_int,
    timestamp: i64,
    data_length: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::send_audio_frame_metadata(
        codec,
        sample_rate,
        channels,
        timestamp,
        data_length,
    ) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_chat(
    _peer_id: *const c_char,
    _message_type: *const c_char,
    content: *const c_char,
    _timestamp: i64,
) -> c_int {
    let content = read_c_string(content);
    if rustdesk_core::harmony_bridge::session_send_chat(&content) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_send_file_transfer_request(
    task_id: *const c_char,
    _peer_id: *const c_char,
    file_name: *const c_char,
    total_bytes: i64,
    direction: *const c_char,
) -> c_int {
    let task_id = read_c_string(task_id);
    let file_name = read_c_string(file_name);
    let direction = read_c_string(direction);
    if rustdesk_core::harmony_bridge::send_file_transfer_request(
        &task_id,
        &file_name,
        total_bytes,
        &direction,
    ) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_start(
    peer_id: *const c_char,
    password: *const c_char,
    server: *const c_char,
    relay_server: *const c_char,
    api_server: *const c_char,
) {
    let peer_id = read_c_string(peer_id);
    let password = read_c_string(password);
    let server = read_c_string(server);
    let relay_server = read_c_string(relay_server);
    let api_server = read_c_string(api_server);
    rustdesk_core::harmony_bridge::session_start(
        &peer_id,
        &password,
        &server,
        &relay_server,
        &api_server,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_account_auth(
    op: *const c_char,
    remember_me: c_int,
    server: *const c_char,
    relay_server: *const c_char,
    api_server: *const c_char,
) {
    let op = read_c_string(op);
    let server = read_c_string(server);
    let relay_server = read_c_string(relay_server);
    let api_server = read_c_string(api_server);
    rustdesk_core::harmony_bridge::main_account_auth(
        &op,
        remember_me != 0,
        &server,
        &relay_server,
        &api_server,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_account_auth_cancel() {
    rustdesk_core::harmony_bridge::main_account_auth_cancel();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_account_auth_result() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_account_auth_result())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_local_option(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_local_option(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_toggle_option(key: *const c_char) -> c_int {
    let key = read_c_string(key);
    if rustdesk_core::harmony_bridge::session_get_toggle_option(&key) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_local_option(key: *const c_char, value: *const c_char) {
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::main_set_local_option(&key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_peer_option(
    peer_id: *const c_char,
    key: *const c_char,
) -> *const c_char {
    let peer_id = read_c_string(peer_id);
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_peer_option(
        &peer_id, &key,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_peer_info(peer_id: *const c_char) -> *const c_char {
    let peer_id = read_c_string(peer_id);
    to_owned_c_string(rustdesk_core::harmony_bridge::get_peer_info(&peer_id))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_apply_session_option(
    key: *const c_char,
    value: *const c_char,
) -> c_int {
    let key = read_c_string(key);
    let value = read_c_string(value);
    if rustdesk_core::harmony_bridge::apply_session_option(&key, &value) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_mark_session_connected(peer_id: *const c_char) {
    let peer_id = read_c_string(peer_id);
    rustdesk_core::harmony_bridge::mark_session_connected(&peer_id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_mark_session_error(message: *const c_char) {
    let message = read_c_string(message);
    rustdesk_core::harmony_bridge::mark_session_error(&message);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_close() {
    rustdesk_core::harmony_bridge::session_close();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_restart_remote_device() -> c_int {
    if rustdesk_core::harmony_bridge::session_restart_remote_device() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_lock_screen() -> c_int {
    if rustdesk_core::harmony_bridge::session_lock_screen() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_login(password: *const c_char, remember: c_int) -> c_int {
    let password = read_c_string(password);
    if rustdesk_core::harmony_bridge::session_login(&password, remember != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_open_terminal(
    terminal_id: c_int,
    rows: c_int,
    cols: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::session_open_terminal(terminal_id, rows, cols) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_terminal_input(
    terminal_id: c_int,
    data: *const c_char,
) -> c_int {
    let data = read_c_string(data);
    if rustdesk_core::harmony_bridge::session_send_terminal_input(terminal_id, &data) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_resize_terminal(
    terminal_id: c_int,
    rows: c_int,
    cols: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::session_resize_terminal(terminal_id, rows, cols) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_close_terminal(terminal_id: c_int) -> c_int {
    if rustdesk_core::harmony_bridge::session_close_terminal(terminal_id) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_read_remote_dir(
    path: *const c_char,
    include_hidden: c_int,
) -> c_int {
    let path = read_c_string(path);
    if rustdesk_core::harmony_bridge::session_read_remote_dir(&path, include_hidden != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_create_dir(path: *const c_char) -> c_int {
    let path = read_c_string(path);
    if rustdesk_core::harmony_bridge::session_create_dir(&path) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_delete_remote_path(
    path: *const c_char,
    is_directory: c_int,
) -> c_int {
    let path = read_c_string(path);
    if rustdesk_core::harmony_bridge::delete_remote_path(&path, is_directory != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_files(
    path: *const c_char,
    to: *const c_char,
    is_remote: c_int,
) -> c_int {
    let path = read_c_string(path);
    let to = read_c_string(to);
    if rustdesk_core::harmony_bridge::session_send_files(&path, &to, is_remote != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_string_free(value: *const c_char) {
    if value.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(value as *mut c_char);
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_query_onlines(ids_json: *const c_char) -> c_int {
    let ids_json = read_c_string(ids_json);
    if rustdesk_core::harmony_bridge::query_onlines(&ids_json) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_discover() {
    rustdesk_core::harmony_bridge::main_discover();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_load_lan_peers() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_load_lan_peers())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_remove_discovered(peer_id: *const c_char) -> c_int {
    let peer_id = read_c_string(peer_id);
    if rustdesk_core::harmony_bridge::main_remove_discovered(&peer_id) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_ctrl_alt_del() -> c_int {
    if rustdesk_core::harmony_bridge::session_ctrl_alt_del() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_reconnect(force_relay: c_int) -> c_int {
    if rustdesk_core::harmony_bridge::session_reconnect(force_relay != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_session_stage() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::get_session_stage())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_active_peer_id() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::get_active_peer_id())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_connect_status_summary() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::get_connect_status_summary())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_connect_detail_message() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::get_connect_detail_message())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_connect_last_error() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::get_connect_last_error())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_drain_connect_events() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::drain_connect_events_json())
}

// ---- Extended session functions ----

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send2fa(
    code: *const c_char,
    trust_this_device: c_int,
) -> c_int {
    let code = read_c_string(code);
    if rustdesk_core::harmony_bridge::session_send2fa(&code, trust_this_device != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_toggle_option(name: *const c_char) {
    let name = read_c_string(name);
    rustdesk_core::harmony_bridge::session_toggle_option(&name);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_toggle_privacy_mode(impl_key: *const c_char, on: c_int) {
    let impl_key = read_c_string(impl_key);
    rustdesk_core::harmony_bridge::session_toggle_privacy_mode(&impl_key, on != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_switch_display(display: c_int) {
    rustdesk_core::harmony_bridge::session_switch_display(display);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_enter_or_leave() {
    rustdesk_core::harmony_bridge::session_enter_or_leave();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_leave() {
    rustdesk_core::harmony_bridge::session_leave();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_size(display: usize, width: usize, height: usize) {
    rustdesk_core::harmony_bridge::session_set_size(display, width, height);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_change_resolution(
    display: c_int,
    width: c_int,
    height: c_int,
) {
    rustdesk_core::harmony_bridge::session_change_resolution(display, width, height);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_elevate_direct() {
    rustdesk_core::harmony_bridge::session_elevate_direct();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_elevate_with_logon(
    username: *const c_char,
    password: *const c_char,
) {
    let username = read_c_string(username);
    let password = read_c_string(password);
    rustdesk_core::harmony_bridge::session_elevate_with_logon(&username, &password);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_switch_sides() {
    rustdesk_core::harmony_bridge::session_switch_sides();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_take_screenshot(display: usize) -> c_int {
    if rustdesk_core::harmony_bridge::session_take_screenshot(display) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_record_screen(start: c_int) {
    rustdesk_core::harmony_bridge::session_record_screen(start != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_is_recording() -> c_int {
    if rustdesk_core::harmony_bridge::session_get_is_recording() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_request_voice_call() {
    rustdesk_core::harmony_bridge::session_request_voice_call();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_close_voice_call() {
    rustdesk_core::harmony_bridge::session_close_voice_call();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_add_port_forward(
    local_port: c_int,
    remote_host: *const c_char,
    remote_port: c_int,
) {
    let remote_host = read_c_string(remote_host);
    rustdesk_core::harmony_bridge::session_add_port_forward(local_port, &remote_host, remote_port);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_remove_port_forward(local_port: c_int) {
    rustdesk_core::harmony_bridge::session_remove_port_forward(local_port);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_new_rdp() {
    rustdesk_core::harmony_bridge::session_new_rdp();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_remove_file(
    act_id: i32,
    path: *const c_char,
    file_num: i32,
    is_remote: c_int,
) {
    let path = read_c_string(path);
    rustdesk_core::harmony_bridge::session_remove_file(act_id, &path, file_num, is_remote != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_rename_file(
    act_id: i32,
    path: *const c_char,
    new_name: *const c_char,
    is_remote: c_int,
) {
    let path = read_c_string(path);
    let new_name = read_c_string(new_name);
    rustdesk_core::harmony_bridge::session_rename_file(act_id, &path, &new_name, is_remote != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_cancel_job(act_id: i32) {
    rustdesk_core::harmony_bridge::session_cancel_job(act_id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_resume_job(act_id: i32, is_remote: c_int) {
    rustdesk_core::harmony_bridge::session_resume_job(act_id, is_remote != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_confirm_override_file(
    act_id: i32,
    file_num: i32,
    need_override: c_int,
    remember: c_int,
    is_upload: c_int,
) {
    rustdesk_core::harmony_bridge::session_set_confirm_override_file(
        act_id,
        file_num,
        need_override != 0,
        remember != 0,
        is_upload != 0,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_note(note: *const c_char) {
    let note = read_c_string(note);
    rustdesk_core::harmony_bridge::session_send_note(&note);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_input_string(value: *const c_char) {
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::session_input_string(&value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_input_os_password(pass: *const c_char) {
    let pass = read_c_string(pass);
    rustdesk_core::harmony_bridge::session_input_os_password(&pass);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_load_last_transfer_jobs() {
    rustdesk_core::harmony_bridge::session_load_last_transfer_jobs();
}

// ---- Session get/set option functions ----

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_view_style() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_view_style())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_view_style(value: *const c_char) {
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::session_set_view_style(&value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_scroll_style() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_scroll_style())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_scroll_style(value: *const c_char) {
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::session_set_scroll_style(&value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_image_quality() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_image_quality())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_image_quality(value: *const c_char) {
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::session_set_image_quality(&value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_keyboard_mode() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_keyboard_mode())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_keyboard_mode(value: *const c_char) {
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::session_set_keyboard_mode(&value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_custom_image_quality() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_custom_image_quality())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_custom_image_quality(value: c_int) {
    rustdesk_core::harmony_bridge::session_set_custom_image_quality(value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_custom_fps(fps: c_int) {
    rustdesk_core::harmony_bridge::session_set_custom_fps(fps);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_trackpad_speed() -> c_int {
    rustdesk_core::harmony_bridge::session_get_trackpad_speed()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_trackpad_speed(value: c_int) {
    rustdesk_core::harmony_bridge::session_set_trackpad_speed(value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_flutter_option(k: *const c_char) -> *const c_char {
    let k = read_c_string(k);
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_flutter_option(
        &k,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_flutter_option(k: *const c_char, v: *const c_char) {
    let k = read_c_string(k);
    let v = read_c_string(v);
    rustdesk_core::harmony_bridge::session_set_flutter_option(&k, &v);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_reverse_mouse_wheel_sync() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_reverse_mouse_wheel_sync())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_reverse_mouse_wheel(value: *const c_char) {
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::session_set_reverse_mouse_wheel(&value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_option(k: *const c_char) -> *const c_char {
    let k = read_c_string(k);
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_option(&k))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_option(k: *const c_char, v: *const c_char) {
    let k = read_c_string(k);
    let v = read_c_string(v);
    rustdesk_core::harmony_bridge::session_set_option(&k, &v);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_peer_option(name: *const c_char) -> *const c_char {
    let name = read_c_string(name);
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_peer_option(
        &name,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_peer_option(name: *const c_char, value: *const c_char) {
    let name = read_c_string(name);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::session_peer_option(&name, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_keyboard_mode_supported(mode: *const c_char) -> c_int {
    let mode = read_c_string(mode);
    if rustdesk_core::harmony_bridge::session_is_keyboard_mode_supported(&mode) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_platform(is_remote: c_int) -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_platform(
        is_remote != 0,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_remember() -> c_int {
    if rustdesk_core::harmony_bridge::session_get_remember() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_enable_trusted_devices() -> c_int {
    if rustdesk_core::harmony_bridge::session_get_enable_trusted_devices() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_alternative_codecs() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_alternative_codecs())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_change_prefer_codec() {
    rustdesk_core::harmony_bridge::session_change_prefer_codec();
}

// ---- main_ global functions ----

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_option(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_option(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_option(key: *const c_char, value: *const c_char) {
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::main_set_option(&key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_options() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_options())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_my_id() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_my_id())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_uuid() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_uuid())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_version() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_version())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_fingerprint() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_fingerprint())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_api_server() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_api_server())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_temporary_password() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_temporary_password())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_permanent_password_with_result(
    password: *const c_char,
) -> c_int {
    let password = read_c_string(password);
    if rustdesk_core::harmony_bridge::main_set_permanent_password_with_result(&password) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_update_temporary_password() {
    rustdesk_core::harmony_bridge::main_update_temporary_password();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_test_if_valid_server(
    server: *const c_char,
) -> *const c_char {
    let server = read_c_string(server);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_test_if_valid_server(
        &server,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_connect_status() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_connect_status())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_using_public_server() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_using_public_server() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_forget_password(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::main_forget_password(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_peer_has_password(id: *const c_char) -> c_int {
    let id = read_c_string(id);
    if rustdesk_core::harmony_bridge::main_peer_has_password(&id) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_peer_exists(id: *const c_char) -> c_int {
    let id = read_c_string(id);
    if rustdesk_core::harmony_bridge::main_peer_exists(&id) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_peer_alias(id: *const c_char, alias: *const c_char) {
    let id = read_c_string(id);
    let alias = read_c_string(alias);
    rustdesk_core::harmony_bridge::main_set_peer_alias(&id, &alias);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_peer_option(
    id: *const c_char,
    key: *const c_char,
    value: *const c_char,
) {
    let id = read_c_string(id);
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::main_set_peer_option(&id, &key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_remove_peer(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::main_remove_peer(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_new_stored_peers() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_new_stored_peers())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_load_recent_peers() {
    rustdesk_core::harmony_bridge::main_load_recent_peers();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_langs() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_langs())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_error() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_error())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_build_date() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_build_date())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_license() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_license())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_app_name() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_app_name())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_has_hwcodec() -> c_int {
    if rustdesk_core::harmony_bridge::main_has_hwcodec() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_generate2fa() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_generate2fa())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_verify2fa(code: *const c_char) -> c_int {
    let code = read_c_string(code);
    if rustdesk_core::harmony_bridge::main_verify2fa(&code) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_trusted_devices() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_trusted_devices())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_clear_trusted_devices() {
    rustdesk_core::harmony_bridge::main_clear_trusted_devices();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_user_default_option(
    key: *const c_char,
    value: *const c_char,
) {
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::main_set_user_default_option(&key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_user_default_option(
    key: *const c_char,
) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_user_default_option(
        &key,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_resolve_avatar_url(avatar: *const c_char) -> *const c_char {
    let avatar = read_c_string(avatar);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_resolve_avatar_url(
        &avatar,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_login_device_info() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_login_device_info())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_hard_option(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_hard_option(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_buildin_option(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_buildin_option(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_common(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_common(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_common(key: *const c_char, value: *const c_char) {
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::main_set_common(&key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_check_connect_status() {
    rustdesk_core::harmony_bridge::main_check_connect_status();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_stop_service() {
    rustdesk_core::harmony_bridge::main_stop_service();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_on_main_window_close() {
    rustdesk_core::harmony_bridge::main_on_main_window_close();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_wol(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::main_wol(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_http_request(
    url: *const c_char,
    method: *const c_char,
    body: *const c_char,
    header: *const c_char,
) {
    let url = read_c_string(url);
    let method = read_c_string(method);
    let body = read_c_string(body);
    let header = read_c_string(header);
    rustdesk_core::harmony_bridge::main_http_request(&url, &method, &body, &header);
}

// ---- extended functions (auto-generated) ----

#[no_mangle]
pub extern "C" fn rustdesk_bridge_drain_connect_events_json() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::drain_connect_events_json())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_core_snapshot_json(server: *const c_char) -> *const c_char {
    let server = read_c_string(server);
    to_owned_c_string(rustdesk_core::harmony_bridge::get_core_snapshot_json(
        &server,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_pull_session_events_json() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::pull_session_events_json())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_pull_audio_frames_json() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::pull_audio_frames_json())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_latest_video_frame_metadata_json(
    since_frame_id: u64,
) -> *const c_char {
    to_owned_c_string(
        rustdesk_core::harmony_bridge::get_latest_video_frame_metadata_json(since_frame_id),
    )
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_file_transfer() -> c_int {
    if rustdesk_core::harmony_bridge::session_is_file_transfer() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_terminal() -> c_int {
    if rustdesk_core::harmony_bridge::session_is_terminal() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_port_forward() -> c_int {
    if rustdesk_core::harmony_bridge::session_is_port_forward() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_rdp() -> c_int {
    if rustdesk_core::harmony_bridge::session_is_rdp() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_view_camera() -> c_int {
    if rustdesk_core::harmony_bridge::session_is_view_camera() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_toggle_virtual_display(index: c_int, on: c_int) {
    rustdesk_core::harmony_bridge::session_toggle_virtual_display(index, on != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_audit_server(typ: *const c_char) -> *const c_char {
    let typ = read_c_string(typ);
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_audit_server(
        &typ,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_selected_session_id(sid: *const c_char) {
    let sid = read_c_string(sid);
    rustdesk_core::harmony_bridge::session_send_selected_session_id(&sid);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_conn_token() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_conn_token())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_handle_flutter_key_event(
    keyboard_mode: *const c_char,
    character: *const c_char,
    usb_hid: c_int,
    lock_modes: c_int,
    down_or_up: c_int,
) {
    let keyboard_mode = read_c_string(keyboard_mode);
    let character = read_c_string(character);
    rustdesk_core::harmony_bridge::session_handle_flutter_key_event(
        &keyboard_mode,
        &character,
        usb_hid,
        lock_modes,
        down_or_up != 0,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_handle_flutter_raw_key_event(
    keyboard_mode: *const c_char,
    name: *const c_char,
    platform_code: c_int,
    position_code: c_int,
    lock_modes: c_int,
    down_or_up: c_int,
) {
    let keyboard_mode = read_c_string(keyboard_mode);
    let name = read_c_string(name);
    rustdesk_core::harmony_bridge::session_handle_flutter_raw_key_event(
        &keyboard_mode,
        &name,
        platform_code,
        position_code,
        lock_modes,
        down_or_up != 0,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_touch_scale(
    scale: c_int,
    alt: c_int,
    ctrl: c_int,
    shift: c_int,
    command: c_int,
) {
    rustdesk_core::harmony_bridge::session_send_touch_scale(
        scale,
        alt != 0,
        ctrl != 0,
        shift != 0,
        command != 0,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_touch_pan_event(
    event: *const c_char,
    x: c_int,
    y: c_int,
    alt: c_int,
    ctrl: c_int,
    shift: c_int,
    command: c_int,
) {
    let event = read_c_string(event);
    rustdesk_core::harmony_bridge::session_send_touch_pan_event(
        &event,
        x,
        y,
        alt != 0,
        ctrl != 0,
        shift != 0,
        command != 0,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_refresh() {
    rustdesk_core::harmony_bridge::session_refresh();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_peer_version() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_peer_version())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_path_sep() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_path_sep())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_restarting_remote_device() -> c_int {
    if rustdesk_core::harmony_bridge::session_is_restarting_remote_device() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_init() {
    rustdesk_core::harmony_bridge::cm_init();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_get_clients_state() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::cm_get_clients_state())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_check_clients_length(length: usize) -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::cm_check_clients_length(
        length,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_get_clients_length() -> usize {
    rustdesk_core::harmony_bridge::cm_get_clients_length()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_send_chat(conn_id: c_int, msg: *const c_char) {
    let msg = read_c_string(msg);
    rustdesk_core::harmony_bridge::cm_send_chat(conn_id, &msg);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_login_res(conn_id: c_int, res: c_int) {
    rustdesk_core::harmony_bridge::cm_login_res(conn_id, res != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_close_connection(conn_id: c_int) {
    rustdesk_core::harmony_bridge::cm_close_connection(conn_id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_remove_disconnected_connection(conn_id: c_int) {
    rustdesk_core::harmony_bridge::cm_remove_disconnected_connection(conn_id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_check_click_time(conn_id: c_int) {
    rustdesk_core::harmony_bridge::cm_check_click_time(conn_id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_get_click_time() -> f64 {
    rustdesk_core::harmony_bridge::cm_get_click_time()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_switch_permission(
    conn_id: c_int,
    name: *const c_char,
    enabled: c_int,
) {
    let name = read_c_string(name);
    rustdesk_core::harmony_bridge::cm_switch_permission(conn_id, &name, enabled != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_can_elevate() -> c_int {
    if rustdesk_core::harmony_bridge::cm_can_elevate() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_elevate_portable(conn_id: c_int) {
    rustdesk_core::harmony_bridge::cm_elevate_portable(conn_id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_switch_back(conn_id: c_int) {
    rustdesk_core::harmony_bridge::cm_switch_back(conn_id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_get_config(name: *const c_char) -> *const c_char {
    let name = read_c_string(name);
    to_owned_c_string(rustdesk_core::harmony_bridge::cm_get_config(&name))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_handle_incoming_voice_call(id: c_int, accept: c_int) {
    rustdesk_core::harmony_bridge::cm_handle_incoming_voice_call(id, accept != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_cm_close_voice_call(id: c_int) {
    rustdesk_core::harmony_bridge::cm_close_voice_call(id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_event(
    id: *const c_char,
    peer: *const c_char,
    msg: *const c_char,
) {
    let id = read_c_string(id);
    let peer = read_c_string(peer);
    let msg = read_c_string(msg);
    rustdesk_core::harmony_bridge::plugin_event(&id, &peer, &msg);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_register_event_stream(
    id: *const c_char,
    peer: *const c_char,
) {
    let id = read_c_string(id);
    let peer = read_c_string(peer);
    rustdesk_core::harmony_bridge::plugin_register_event_stream(&id, &peer);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_get_session_option(
    id: *const c_char,
    key: *const c_char,
) -> *const c_char {
    let id = read_c_string(id);
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::plugin_get_session_option(
        &id, &key,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_set_session_option(
    id: *const c_char,
    key: *const c_char,
    value: *const c_char,
) {
    let id = read_c_string(id);
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::plugin_set_session_option(&id, &key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_get_shared_option(
    id: *const c_char,
    key: *const c_char,
) -> *const c_char {
    let id = read_c_string(id);
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::plugin_get_shared_option(
        &id, &key,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_set_shared_option(
    id: *const c_char,
    key: *const c_char,
    value: *const c_char,
) {
    let id = read_c_string(id);
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::plugin_set_shared_option(&id, &key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_reload(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::plugin_reload(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_enable(id: *const c_char, enable: c_int) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::plugin_enable(&id, enable != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_is_enabled(id: *const c_char) -> c_int {
    let id = read_c_string(id);
    if rustdesk_core::harmony_bridge::plugin_is_enabled(&id) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_feature_is_enabled(id: *const c_char) -> c_int {
    let id = read_c_string(id);
    if rustdesk_core::harmony_bridge::plugin_feature_is_enabled(&id) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_sync_ui(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::plugin_sync_ui(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_list_reload() {
    rustdesk_core::harmony_bridge::plugin_list_reload();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_plugin_install(id: *const c_char, b: c_int) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::plugin_install(&id, b != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_install_install_me(
    path: *const c_char,
    options: *const c_char,
    exe: *const c_char,
) {
    let path = read_c_string(path);
    let options = read_c_string(options);
    let exe = read_c_string(exe);
    rustdesk_core::harmony_bridge::install_install_me(&path, &options, &exe);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_install_install_options() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::install_install_options())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_install_install_path() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::install_install_path())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_install_run_without_install() -> c_int {
    if rustdesk_core::harmony_bridge::install_run_without_install() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_install_show_run_without_install() -> c_int {
    if rustdesk_core::harmony_bridge::install_show_run_without_install() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_custom_client() -> c_int {
    if rustdesk_core::harmony_bridge::is_custom_client() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_disable_ab() -> c_int {
    if rustdesk_core::harmony_bridge::is_disable_ab() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_disable_account() -> c_int {
    if rustdesk_core::harmony_bridge::is_disable_account() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_disable_group_panel() -> c_int {
    if rustdesk_core::harmony_bridge::is_disable_group_panel() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_disable_installation() -> c_int {
    if rustdesk_core::harmony_bridge::is_disable_installation() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_disable_settings() -> c_int {
    if rustdesk_core::harmony_bridge::is_disable_settings() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_incoming_only() -> c_int {
    if rustdesk_core::harmony_bridge::is_incoming_only() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_outgoing_only() -> c_int {
    if rustdesk_core::harmony_bridge::is_outgoing_only() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_preset_password() -> c_int {
    if rustdesk_core::harmony_bridge::is_preset_password() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_preset_password_mobile_only() -> c_int {
    if rustdesk_core::harmony_bridge::is_preset_password_mobile_only() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_selinux_enforcing() -> c_int {
    if rustdesk_core::harmony_bridge::is_selinux_enforcing() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_is_support_multi_ui_session() -> c_int {
    if rustdesk_core::harmony_bridge::is_support_multi_ui_session() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_change_id(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::main_change_id(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_change_language(lang: *const c_char) {
    let lang = read_c_string(lang);
    rustdesk_core::harmony_bridge::main_change_language(&lang);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_change_theme(dark: *const c_char) {
    let dark = read_c_string(dark);
    rustdesk_core::harmony_bridge::main_change_theme(&dark);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_displays() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_displays())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_printer_names() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_printer_names())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_socks() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_socks())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_socks(
    proxy: *const c_char,
    username: *const c_char,
    password: *const c_char,
) {
    let proxy = read_c_string(proxy);
    let username = read_c_string(username);
    let password = read_c_string(password);
    rustdesk_core::harmony_bridge::main_set_socks(&proxy, &username, &password);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_proxy_status() -> c_int {
    if rustdesk_core::harmony_bridge::main_get_proxy_status() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_app_name_sync() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_app_name_sync())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_new_version() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_new_version())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_home_dir() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_home_dir())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_init(
    app_dir: *const c_char,
    custom_client_config: *const c_char,
) {
    rustdesk_core::harmony_bridge::main_init(
        read_c_string(app_dir),
        read_c_string(custom_client_config),
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_device_id() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_device_id())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_device_name() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_device_name())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_installed() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_installed() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_installed_daemon() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_installed_daemon() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_root() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_root() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_process_trusted() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_process_trusted() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_can_screen_recording() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_can_screen_recording() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_can_input_monitoring() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_can_input_monitoring() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_current_is_wayland() -> c_int {
    if rustdesk_core::harmony_bridge::main_current_is_wayland() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_login_wayland() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_login_wayland() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_has_vram() -> c_int {
    if rustdesk_core::harmony_bridge::main_has_vram() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_supported_hwdecodings() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_supported_hwdecodings())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_check_hwcodec() {
    rustdesk_core::harmony_bridge::main_check_hwcodec();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_create_shortcut() -> c_int {
    if rustdesk_core::harmony_bridge::main_create_shortcut() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_mouse_time() -> i64 {
    rustdesk_core::harmony_bridge::main_get_mouse_time()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_check_mouse_time() -> c_int {
    if rustdesk_core::harmony_bridge::main_check_mouse_time() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_async_status() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_async_status())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_lan_peers() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_lan_peers())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_last_remote_id() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_last_remote_id())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_fav() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_fav())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_store_fav(fav: *const c_char) {
    let fav = read_c_string(fav);
    rustdesk_core::harmony_bridge::main_store_fav(&fav);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_peer_sync(id: *const c_char) -> *const c_char {
    let id = read_c_string(id);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_peer_sync(&id))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_peer_flutter_option_sync(
    id: *const c_char,
    k: *const c_char,
) -> *const c_char {
    let id = read_c_string(id);
    let k = read_c_string(k);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_peer_flutter_option_sync(&id, &k))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_peer_flutter_option_sync(
    id: *const c_char,
    k: *const c_char,
    v: *const c_char,
) {
    let id = read_c_string(id);
    let k = read_c_string(k);
    let v = read_c_string(v);
    rustdesk_core::harmony_bridge::main_set_peer_flutter_option_sync(&id, &k, &v);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_peer_option_sync(
    id: *const c_char,
    k: *const c_char,
) -> *const c_char {
    let id = read_c_string(id);
    let k = read_c_string(k);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_peer_option_sync(
        &id, &k,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_peer_option_sync(
    id: *const c_char,
    k: *const c_char,
    v: *const c_char,
) {
    let id = read_c_string(id);
    let k = read_c_string(k);
    let v = read_c_string(v);
    rustdesk_core::harmony_bridge::main_set_peer_option_sync(&id, &k, &v);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_remove_trusted_devices(json: *const c_char) {
    let json = read_c_string(json);
    rustdesk_core::harmony_bridge::main_remove_trusted_devices(&json);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_has_valid_2fa_sync() -> c_int {
    if rustdesk_core::harmony_bridge::main_has_valid_2fa_sync() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_has_valid_bot_sync() -> c_int {
    if rustdesk_core::harmony_bridge::main_has_valid_bot_sync() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_verify_bot(token: *const c_char) -> c_int {
    let token = read_c_string(token);
    if rustdesk_core::harmony_bridge::main_verify_bot(&token) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_max_encrypt_len() -> usize {
    rustdesk_core::harmony_bridge::main_max_encrypt_len()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_unlock_pin() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_unlock_pin())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_unlock_pin(pin: *const c_char) {
    let pin = read_c_string(pin);
    rustdesk_core::harmony_bridge::main_set_unlock_pin(&pin);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_option_synced() -> c_int {
    if rustdesk_core::harmony_bridge::main_option_synced() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_support_remove_wallpaper() -> c_int {
    if rustdesk_core::harmony_bridge::main_support_remove_wallpaper() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_test_wallpaper() -> c_int {
    if rustdesk_core::harmony_bridge::main_test_wallpaper() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_supported_privacy_mode_impls() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_supported_privacy_mode_impls())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_default_privacy_mode_impl() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_default_privacy_mode_impl())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_option_fixed(key: *const c_char) -> c_int {
    let key = read_c_string(key);
    if rustdesk_core::harmony_bridge::main_is_option_fixed(&key) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_use_texture_render() -> c_int {
    if rustdesk_core::harmony_bridge::main_get_use_texture_render() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_has_file_clipboard() -> c_int {
    if rustdesk_core::harmony_bridge::main_has_file_clipboard() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_has_gpu_texture_render() -> c_int {
    if rustdesk_core::harmony_bridge::main_has_gpu_texture_render() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_audio_support_loopback() -> c_int {
    if rustdesk_core::harmony_bridge::main_audio_support_loopback() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_share_rdp() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_share_rdp() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_share_rdp(v: c_int) {
    rustdesk_core::harmony_bridge::main_set_share_rdp(v != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_is_installed_lower_version() -> c_int {
    if rustdesk_core::harmony_bridge::main_is_installed_lower_version() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_software_update_url() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_software_update_url())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_handle_relay_id(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::main_handle_relay_id(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_hide_dock() {
    rustdesk_core::harmony_bridge::main_hide_dock();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_cursor_position(x: c_int, y: c_int) {
    rustdesk_core::harmony_bridge::main_set_cursor_position(x, y);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_clip_cursor() {
    rustdesk_core::harmony_bridge::main_clip_cursor();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_env(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_env(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_env(key: *const c_char, value: *const c_char) {
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::main_set_env(&key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_home_dir(home: *const c_char) {
    let home = read_c_string(home);
    rustdesk_core::harmony_bridge::main_set_home_dir(&home);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_start_dbus_server() {
    rustdesk_core::harmony_bridge::main_start_dbus_server();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_start_ipc_url_server() {
    rustdesk_core::harmony_bridge::main_start_ipc_url_server();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_check_super_user_permission() -> c_int {
    if rustdesk_core::harmony_bridge::main_check_super_user_permission() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_goto_install() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_goto_install())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_update_me(path: *const c_char) {
    let path = read_c_string(path);
    rustdesk_core::harmony_bridge::main_update_me(&path);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_deploy_device() -> c_int {
    if rustdesk_core::harmony_bridge::main_deploy_device() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_main_display() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_main_display())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_input_source() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_input_source())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_input_source(source: *const c_char) {
    let source = read_c_string(source);
    rustdesk_core::harmony_bridge::main_set_input_source(&source);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_init_input_source() {
    rustdesk_core::harmony_bridge::main_init_input_source();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_supported_input_source() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_supported_input_source())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_video_save_directory() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_video_save_directory())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_data_dir_ios() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_data_dir_ios())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_show_option(key: *const c_char) -> c_int {
    let key = read_c_string(key);
    if rustdesk_core::harmony_bridge::main_show_option(&key) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_set_options(options: *const c_char) {
    let options = read_c_string(options);
    rustdesk_core::harmony_bridge::main_set_options(&options);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_options_sync() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_options_sync())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_option_sync(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_option_sync(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_common_sync(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_common_sync(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_get_http_status() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_get_http_status())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_uri_prefix_sync() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_uri_prefix_sync())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_load_ab() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_load_ab())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_save_ab(ab: *const c_char) {
    let ab = read_c_string(ab);
    rustdesk_core::harmony_bridge::main_save_ab(&ab);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_clear_ab() {
    rustdesk_core::harmony_bridge::main_clear_ab();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_load_group() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_load_group())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_save_group(group: *const c_char) {
    let group = read_c_string(group);
    rustdesk_core::harmony_bridge::main_save_group(&group);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_clear_group() {
    rustdesk_core::harmony_bridge::main_clear_group();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_load_fav_peers() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_load_fav_peers())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_load_recent_peers_for_ab() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::main_load_recent_peers_for_ab())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_main_handle_wayland_screencast_restore_token(
    token: *const c_char,
) {
    let token = read_c_string(token);
    rustdesk_core::harmony_bridge::main_handle_wayland_screencast_restore_token(&token);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_double_click_time() -> f64 {
    rustdesk_core::harmony_bridge::get_double_click_time()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_local_flutter_option(k: *const c_char) -> *const c_char {
    let k = read_c_string(k);
    to_owned_c_string(rustdesk_core::harmony_bridge::get_local_flutter_option(&k))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_set_local_flutter_option(k: *const c_char, v: *const c_char) {
    let k = read_c_string(k);
    let v = read_c_string(v);
    rustdesk_core::harmony_bridge::set_local_flutter_option(&k, &v);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_local_kb_layout_type() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::get_local_kb_layout_type())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_set_local_kb_layout_type(v: *const c_char) {
    let v = read_c_string(v);
    rustdesk_core::harmony_bridge::set_local_kb_layout_type(&v);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_voice_call_input_device() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::get_voice_call_input_device())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_set_voice_call_input_device(device: *const c_char) {
    let device = read_c_string(device);
    rustdesk_core::harmony_bridge::set_voice_call_input_device(&device);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_host_stop_system_key_propagate(stop: c_int) {
    rustdesk_core::harmony_bridge::host_stop_system_key_propagate(stop != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_option_synced() -> c_int {
    if rustdesk_core::harmony_bridge::option_synced() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_peer_get_sessions_count() -> usize {
    rustdesk_core::harmony_bridge::peer_get_sessions_count()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_send_url_scheme(url: *const c_char) {
    let url = read_c_string(url);
    rustdesk_core::harmony_bridge::send_url_scheme(&url);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_set_cur_session_id(id: *const c_char) {
    let id = read_c_string(id);
    rustdesk_core::harmony_bridge::set_cur_session_id(&id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_start_global_event_stream() {
    rustdesk_core::harmony_bridge::start_global_event_stream();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_stop_global_event_stream() {
    rustdesk_core::harmony_bridge::stop_global_event_stream();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_translate(name: *const c_char) -> *const c_char {
    let name = read_c_string(name);
    to_owned_c_string(rustdesk_core::harmony_bridge::translate(&name))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_version_to_number(v: *const c_char) -> i64 {
    let v = read_c_string(v);
    rustdesk_core::harmony_bridge::version_to_number(&v)
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_will_session_close_close_session() -> c_int {
    if rustdesk_core::harmony_bridge::will_session_close_close_session() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_next_texture_key() -> c_int {
    rustdesk_core::harmony_bridge::get_next_texture_key()
}

// ---- extended functions (auto-generated) ----

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_add_existed_sync(is_sync: c_int) -> c_int {
    if rustdesk_core::harmony_bridge::session_add_existed_sync(is_sync != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_add_job(
    id: c_int,
    path: *const c_char,
    to: *const c_char,
    file_num: c_int,
    include_hidden: c_int,
    is_remote: c_int,
) {
    rustdesk_core::harmony_bridge::session_add_job(
        id,
        read_c_string(path),
        read_c_string(to),
        file_num,
        include_hidden != 0,
        is_remote != 0,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_add_sync(is_sync: c_int) {
    rustdesk_core::harmony_bridge::session_add_sync(is_sync != 0);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_audit_guid() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_audit_guid())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_audit_server_sync(
    typ: *const c_char,
) -> *const c_char {
    to_owned_c_string(
        rustdesk_core::harmony_bridge::session_get_audit_server_sync(read_c_string(typ)),
    )
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_common(key: *const c_char) -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_common(
        read_c_string(key),
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_common_sync(key: *const c_char) -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_common_sync(
        read_c_string(key),
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_conn_session_id() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_conn_session_id())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_displays_as_individual_windows() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_displays_as_individual_windows())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_edge_scroll_edge_thickness() -> c_int {
    rustdesk_core::harmony_bridge::session_get_edge_scroll_edge_thickness()
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_last_audit_note() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_get_last_audit_note())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_rgba_size(display: c_int) -> c_int {
    rustdesk_core::harmony_bridge::session_get_rgba_size(display)
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_toggle_option_sync(arg: *const c_char) -> c_int {
    if rustdesk_core::harmony_bridge::session_get_toggle_option_sync(read_c_string(arg)) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_get_use_all_my_displays_for_the_remote_session(
) -> *const c_char {
    to_owned_c_string(
        rustdesk_core::harmony_bridge::session_get_use_all_my_displays_for_the_remote_session(),
    )
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_handle_screenshot(
    action: *const c_char,
) -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_handle_screenshot(
        read_c_string(action),
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_is_multi_ui_session() -> c_int {
    if rustdesk_core::harmony_bridge::session_is_multi_ui_session() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_next_rgba(display: c_int) {
    rustdesk_core::harmony_bridge::session_next_rgba(display);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_on_waiting_for_image_dialog_show() {
    rustdesk_core::harmony_bridge::session_on_waiting_for_image_dialog_show();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_printer_response(
    id: c_int,
    path: *const c_char,
    printer_name: *const c_char,
) {
    rustdesk_core::harmony_bridge::session_printer_response(
        id,
        read_c_string(path),
        read_c_string(printer_name),
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_read_dir_to_remove_recursive(
    id: c_int,
    path: *const c_char,
    include_hidden: c_int,
) {
    rustdesk_core::harmony_bridge::session_read_dir_to_remove_recursive(
        id,
        read_c_string(path),
        include_hidden != 0,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_read_local_dir_sync(
    path: *const c_char,
    include_hidden: c_int,
    id: c_int,
) -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::session_read_local_dir_sync(
        read_c_string(path),
        include_hidden != 0,
        id,
    ))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_read_local_empty_dirs_recursive_sync(
    id: c_int,
    path: *const c_char,
) -> *const c_char {
    to_owned_c_string(
        rustdesk_core::harmony_bridge::session_read_local_empty_dirs_recursive_sync(
            id,
            read_c_string(path),
        ),
    )
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_read_remote_empty_dirs_recursive_sync(
    id: c_int,
    path: *const c_char,
) -> *const c_char {
    to_owned_c_string(
        rustdesk_core::harmony_bridge::session_read_remote_empty_dirs_recursive_sync(
            id,
            read_c_string(path),
        ),
    )
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_register_gpu_texture(display: c_int) -> c_int {
    rustdesk_core::harmony_bridge::session_register_gpu_texture(display)
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_register_pixelbuffer_texture(display: c_int) -> c_int {
    rustdesk_core::harmony_bridge::session_register_pixelbuffer_texture(display)
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_remove_all_empty_dirs(id: c_int) {
    rustdesk_core::harmony_bridge::session_remove_all_empty_dirs(id);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_request_new_display_init_msgs(display: c_int) {
    rustdesk_core::harmony_bridge::session_request_new_display_init_msgs(display);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_send_pointer(msg: *const c_char) {
    rustdesk_core::harmony_bridge::session_send_pointer(read_c_string(msg));
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_audit_guid(guid: *const c_char) {
    rustdesk_core::harmony_bridge::session_set_audit_guid(read_c_string(guid));
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_displays_as_individual_windows(value: *const c_char) {
    rustdesk_core::harmony_bridge::session_set_displays_as_individual_windows(read_c_string(value));
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_edge_scroll_edge_thickness(value: c_int) {
    rustdesk_core::harmony_bridge::session_set_edge_scroll_edge_thickness(value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_set_use_all_my_displays_for_the_remote_session(
    value: *const c_char,
) {
    rustdesk_core::harmony_bridge::session_set_use_all_my_displays_for_the_remote_session(
        read_c_string(value),
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_session_start_with_displays(displays: *const c_char) -> c_int {
    if rustdesk_core::harmony_bridge::session_start_with_displays(read_c_string(displays)) {
        1
    } else {
        0
    }
}
