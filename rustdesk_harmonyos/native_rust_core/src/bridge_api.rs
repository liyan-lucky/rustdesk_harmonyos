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
pub extern "C" fn rustdesk_bridge_set_incoming_service_enabled(
    enabled: c_int,
    server: *const c_char,
    relay_server: *const c_char,
    api_server: *const c_char,
) -> *const c_char {
    let server = read_c_string(server);
    let relay_server = read_c_string(relay_server);
    let api_server = read_c_string(api_server);
    to_owned_c_string(rustdesk_core::harmony_bridge::set_incoming_service_enabled(
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
pub extern "C" fn rustdesk_bridge_send_mouse_input(mask: c_int, x: c_int, y: c_int) -> c_int {
    if rustdesk_core::harmony_bridge::send_mouse_input(mask, x, y) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_send_keyboard_input(
    key_code: c_int,
    is_pressed: c_int,
    modifiers: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::send_keyboard_input(key_code, is_pressed != 0, modifiers) {
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
pub extern "C" fn rustdesk_bridge_send_chat_message(
    _peer_id: *const c_char,
    _message_type: *const c_char,
    content: *const c_char,
    _timestamp: i64,
) -> c_int {
    let content = read_c_string(content);
    if rustdesk_core::harmony_bridge::send_chat_message(&content) {
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
pub extern "C" fn rustdesk_bridge_connect_to_peer(
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
    rustdesk_core::harmony_bridge::connect_to_peer(
        &peer_id,
        &password,
        &server,
        &relay_server,
        &api_server,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_account_auth(
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
    rustdesk_core::harmony_bridge::account_auth(
        &op,
        remember_me != 0,
        &server,
        &relay_server,
        &api_server,
    );
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_account_auth_cancel() {
    rustdesk_core::harmony_bridge::account_auth_cancel();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_account_auth_result() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::account_auth_result_json())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_local_option(key: *const c_char) -> *const c_char {
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::get_local_option(&key))
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_session_toggle_option(key: *const c_char) -> c_int {
    let key = read_c_string(key);
    if rustdesk_core::harmony_bridge::get_session_toggle_option(&key) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_set_local_option(key: *const c_char, value: *const c_char) {
    let key = read_c_string(key);
    let value = read_c_string(value);
    rustdesk_core::harmony_bridge::set_local_option(&key, &value);
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_get_peer_option(
    peer_id: *const c_char,
    key: *const c_char,
) -> *const c_char {
    let peer_id = read_c_string(peer_id);
    let key = read_c_string(key);
    to_owned_c_string(rustdesk_core::harmony_bridge::get_peer_option(
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
pub extern "C" fn rustdesk_bridge_close_session() {
    rustdesk_core::harmony_bridge::close_session();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_restart_remote_device() -> c_int {
    if rustdesk_core::harmony_bridge::restart_remote_device() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_lock_remote_screen() -> c_int {
    if rustdesk_core::harmony_bridge::lock_remote_screen() {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_submit_session_password(
    password: *const c_char,
    remember: c_int,
) -> c_int {
    let password = read_c_string(password);
    if rustdesk_core::harmony_bridge::submit_session_password(&password, remember != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_open_terminal(
    terminal_id: c_int,
    rows: c_int,
    cols: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::open_terminal(terminal_id, rows, cols) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_send_terminal_input(
    terminal_id: c_int,
    data: *const c_char,
) -> c_int {
    let data = read_c_string(data);
    if rustdesk_core::harmony_bridge::send_terminal_input(terminal_id, &data) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_resize_terminal(
    terminal_id: c_int,
    rows: c_int,
    cols: c_int,
) -> c_int {
    if rustdesk_core::harmony_bridge::resize_terminal(terminal_id, rows, cols) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_close_terminal(terminal_id: c_int) -> c_int {
    if rustdesk_core::harmony_bridge::close_terminal(terminal_id) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_read_remote_directory(
    path: *const c_char,
    include_hidden: c_int,
) -> c_int {
    let path = read_c_string(path);
    if rustdesk_core::harmony_bridge::read_remote_directory(&path, include_hidden != 0) {
        1
    } else {
        0
    }
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_create_remote_directory(path: *const c_char) -> c_int {
    let path = read_c_string(path);
    if rustdesk_core::harmony_bridge::create_remote_directory(&path) {
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
pub extern "C" fn rustdesk_bridge_start_file_transfer(
    path: *const c_char,
    to: *const c_char,
    is_remote: c_int,
) -> c_int {
    let path = read_c_string(path);
    let to = read_c_string(to);
    if rustdesk_core::harmony_bridge::start_file_transfer(&path, &to, is_remote != 0) {
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
pub extern "C" fn rustdesk_bridge_discover_lan_peers() {
    rustdesk_core::harmony_bridge::discover_lan_peers();
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_load_lan_peers() -> *const c_char {
    to_owned_c_string(rustdesk_core::harmony_bridge::load_lan_peers())
}

#[no_mangle]
pub extern "C" fn rustdesk_bridge_remove_discovered_peer(peer_id: *const c_char) -> c_int {
    let peer_id = read_c_string(peer_id);
    if rustdesk_core::harmony_bridge::remove_discovered_peer(&peer_id) {
        1
    } else {
        0
    }
}
