#include "rustdesk_bridge_abi.h"
#include <cstring>
#include <cstdlib>

static char *alloc_empty_string() {
  char *s = (char *)malloc(1);
  s[0] = '\0';
  return s;
}

static char *alloc_json_string(const char *json) {
  size_t len = strlen(json);
  char *s = (char *)malloc(len + 1);
  memcpy(s, json, len + 1);
  return s;
}

const char *rustdesk_bridge_get_core_snapshot(const char *) { return alloc_json_string("{\"coreReady\":true,\"sessionStage\":\"idle\",\"activePeerId\":\"\",\"displayId\":\"\",\"fingerprint\":\"\",\"statusSummary\":\"Stub core ready\",\"detailMessage\":\"\",\"lastError\":\"\",\"incomingReady\":false,\"captureRequired\":false}"); }
const char *rustdesk_bridge_initialize_runtime(const char *, const char *) { return alloc_json_string("{\"coreReady\":true,\"sessionStage\":\"idle\",\"activePeerId\":\"\",\"displayId\":\"\",\"fingerprint\":\"\",\"statusSummary\":\"Stub core ready\",\"detailMessage\":\"\",\"lastError\":\"\",\"incomingReady\":false,\"captureRequired\":false}"); }
const char *rustdesk_bridge_pull_session_events(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_get_latest_video_frame_metadata(unsigned long long) { return alloc_empty_string(); }
int rustdesk_bridge_copy_latest_video_frame(unsigned long long, unsigned char *, unsigned long long) { return 0; }
const char *rustdesk_bridge_get_incoming_screen_frame_metadata(unsigned long long) { return alloc_empty_string(); }
int rustdesk_bridge_copy_incoming_screen_frame(unsigned long long, unsigned char *, unsigned long long) { return 0; }
int rustdesk_bridge_update_incoming_screen_frame(int, int, int, long long, const char *, const unsigned char *, unsigned long long) { return 0; }
void rustdesk_bridge_clear_incoming_screen_frame(void) {}
int rustdesk_bridge_refresh_session_video(int) { return 0; }
void rustdesk_bridge_harmony_next_rgba(int) {}
const char *rustdesk_bridge_bootstrap_core_snapshot(const char *, const char *, const char *, const char *) { return alloc_json_string("{\"coreReady\":true,\"sessionStage\":\"idle\",\"activePeerId\":\"\",\"displayId\":\"\",\"fingerprint\":\"\",\"statusSummary\":\"Stub core ready\",\"detailMessage\":\"\",\"lastError\":\"\",\"incomingReady\":false,\"captureRequired\":false}"); }
int rustdesk_bridge_send_clipboard_data(const char *, long long) { return 0; }
int rustdesk_bridge_send_video_frame_metadata(int, int, int, long long, int, int) { return 0; }
int rustdesk_bridge_send_audio_frame_metadata(int, int, int, long long, int) { return 0; }
int rustdesk_bridge_send_file_transfer_request(const char *, const char *, const char *, long long, const char *) { return 0; }
void rustdesk_bridge_mark_session_connected(const char *) {}
void rustdesk_bridge_mark_session_error(const char *) {}
int rustdesk_bridge_query_onlines(const char *) { return 0; }
const char *rustdesk_bridge_get_peer_info(const char *) { return alloc_empty_string(); }
int rustdesk_bridge_apply_session_option(const char *, const char *) { return 0; }
int rustdesk_bridge_delete_remote_path(const char *, int) { return 0; }
const char *rustdesk_bridge_pull_audio_frames(void) { return alloc_empty_string(); }
void rustdesk_bridge_string_free(const char *v) { free((void *)v); }
const char *rustdesk_bridge_get_session_stage(void) { return alloc_json_string("\"Disconnected\""); }
const char *rustdesk_bridge_get_active_peer_id(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_get_connect_status_summary(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_get_connect_detail_message(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_get_connect_last_error(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_drain_connect_events_json(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_drain_connect_events(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_get_core_snapshot_json(const char *) { return alloc_json_string("{\"coreReady\":true,\"sessionStage\":\"idle\",\"activePeerId\":\"\",\"displayId\":\"\",\"fingerprint\":\"\",\"statusSummary\":\"Stub core ready\",\"detailMessage\":\"\",\"lastError\":\"\",\"incomingReady\":false,\"captureRequired\":false}"); }
const char *rustdesk_bridge_pull_session_events_json(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_pull_audio_frames_json(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_get_latest_video_frame_metadata_json(unsigned long long) { return alloc_empty_string(); }
const char *rustdesk_bridge_get_incoming_screen_frame_metadata_json(unsigned long long) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_start_service(int, const char *, const char *, const char *, const char *) { return alloc_empty_string(); }
int rustdesk_bridge_session_send_mouse(int, int, int) { return 0; }
int rustdesk_bridge_session_input_key(int, int, int) { return 0; }
int rustdesk_bridge_session_ctrl_alt_del(void) { return 0; }
int rustdesk_bridge_session_send_chat(const char *, const char *, const char *, long long) { return 0; }
void rustdesk_bridge_session_start(const char *, const char *, const char *, const char *, const char *, const char *) {}
void rustdesk_bridge_main_account_auth(const char *, int, const char *, const char *, const char *) {}
void rustdesk_bridge_main_account_auth_cancel(void) {}
const char *rustdesk_bridge_main_account_auth_result(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_local_option(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_peer_option(const char *, const char *) { return alloc_empty_string(); }
int rustdesk_bridge_session_get_toggle_option(const char *) { return 0; }
void rustdesk_bridge_main_set_local_option(const char *, const char *) {}
int rustdesk_bridge_session_reconnect(int) { return 0; }
void rustdesk_bridge_session_close(void) {}
int rustdesk_bridge_session_login(const char *, int) { return 0; }
int rustdesk_bridge_session_restart_remote_device(void) { return 0; }
int rustdesk_bridge_session_lock_screen(void) { return 0; }
int rustdesk_bridge_session_open_terminal(int, int, int) { return 0; }
int rustdesk_bridge_session_send_terminal_input(int, const char *) { return 0; }
int rustdesk_bridge_session_resize_terminal(int, int, int) { return 0; }
int rustdesk_bridge_session_close_terminal(int) { return 0; }
int rustdesk_bridge_session_read_remote_dir(const char *, int) { return 0; }
int rustdesk_bridge_session_create_dir(const char *) { return 0; }
int rustdesk_bridge_session_send_files(const char *, const char *, int) { return 0; }
void rustdesk_bridge_main_discover(void) {}
const char *rustdesk_bridge_main_load_lan_peers(void) { return alloc_json_string("[]"); }
int rustdesk_bridge_main_remove_discovered(const char *) { return 0; }
int rustdesk_bridge_session_send2fa(const char *, int) { return 0; }
void rustdesk_bridge_session_toggle_option(const char *) {}
int rustdesk_bridge_session_toggle_privacy_mode(const char *, int) { return 0; }
int rustdesk_bridge_session_switch_display(int) { return 0; }
int rustdesk_bridge_session_enter_or_leave(void) { return 0; }
int rustdesk_bridge_session_leave(void) { return 0; }
void rustdesk_bridge_session_set_size(unsigned long long, unsigned long long, unsigned long long) {}
void rustdesk_bridge_session_change_resolution(int, int, int) {}
void rustdesk_bridge_session_elevate_direct(void) {}
void rustdesk_bridge_session_elevate_with_logon(const char *, const char *) {}
int rustdesk_bridge_session_switch_sides(void) { return 0; }
int rustdesk_bridge_session_take_screenshot(unsigned long long) { return 0; }
int rustdesk_bridge_session_record_screen(int) { return 0; }
int rustdesk_bridge_session_get_is_recording(void) { return 0; }
int rustdesk_bridge_session_request_voice_call(void) { return 0; }
int rustdesk_bridge_session_close_voice_call(void) { return 0; }
void rustdesk_bridge_session_add_port_forward(int, const char *, int) {}
void rustdesk_bridge_session_remove_port_forward(int) {}
void rustdesk_bridge_session_new_rdp(void) {}
void rustdesk_bridge_session_remove_file(int, const char *, int, int) {}
void rustdesk_bridge_session_rename_file(int, const char *, const char *, int) {}
void rustdesk_bridge_session_cancel_job(int) {}
void rustdesk_bridge_session_resume_job(int, int) {}
void rustdesk_bridge_session_set_confirm_override_file(int, int, int, int, int) {}
void rustdesk_bridge_session_send_note(const char *) {}
void rustdesk_bridge_session_input_string(const char *) {}
void rustdesk_bridge_session_input_os_password(const char *) {}
void rustdesk_bridge_session_load_last_transfer_jobs(void) {}
const char *rustdesk_bridge_session_get_view_style(void) { return alloc_empty_string(); }
void rustdesk_bridge_session_set_view_style(const char *) {}
const char *rustdesk_bridge_session_get_scroll_style(void) { return alloc_empty_string(); }
void rustdesk_bridge_session_set_scroll_style(const char *) {}
const char *rustdesk_bridge_session_get_image_quality(void) { return alloc_empty_string(); }
void rustdesk_bridge_session_set_image_quality(const char *) {}
const char *rustdesk_bridge_session_get_keyboard_mode(void) { return alloc_empty_string(); }
void rustdesk_bridge_session_set_keyboard_mode(const char *) {}
const char *rustdesk_bridge_session_get_custom_image_quality(void) { return alloc_empty_string(); }
void rustdesk_bridge_session_set_custom_image_quality(int) {}
void rustdesk_bridge_session_set_custom_fps(int) {}
int rustdesk_bridge_session_get_trackpad_speed(void) { return 50; }
void rustdesk_bridge_session_set_trackpad_speed(int) {}
const char *rustdesk_bridge_session_get_flutter_option(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_session_set_flutter_option(const char *, const char *) {}
const char *rustdesk_bridge_session_get_reverse_mouse_wheel_sync(void) { return alloc_json_string("false"); }
void rustdesk_bridge_session_set_reverse_mouse_wheel(const char *) {}
const char *rustdesk_bridge_session_get_option(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_session_set_option(const char *, const char *) {}
const char *rustdesk_bridge_session_get_peer_option(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_session_peer_option(const char *, const char *) {}
int rustdesk_bridge_session_is_keyboard_mode_supported(const char *) { return 0; }
const char *rustdesk_bridge_session_get_platform(int) { return alloc_empty_string(); }
int rustdesk_bridge_session_get_remember(void) { return 0; }
int rustdesk_bridge_session_get_enable_trusted_devices(void) { return 0; }
const char *rustdesk_bridge_session_get_alternative_codecs(void) { return alloc_empty_string(); }
void rustdesk_bridge_session_change_prefer_codec(void) {}
const char *rustdesk_bridge_main_get_option(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_option(const char *, const char *) {}
const char *rustdesk_bridge_main_get_options(void) { return alloc_json_string("{}"); }
const char *rustdesk_bridge_main_get_my_id(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_uuid(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_version(void) { return alloc_json_string("\"0.0.0-stub\""); }
const char *rustdesk_bridge_main_get_fingerprint(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_api_server(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_temporary_password(void) { return alloc_empty_string(); }
int rustdesk_bridge_main_set_permanent_password_with_result(const char *) { return 0; }
void rustdesk_bridge_main_update_temporary_password(void) {}
const char *rustdesk_bridge_main_test_if_valid_server(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_connect_status(void) { return alloc_json_string("{\"status\":\"Disconnected\"}"); }
int rustdesk_bridge_main_is_using_public_server(void) { return 0; }
void rustdesk_bridge_main_forget_password(const char *) {}
int rustdesk_bridge_main_peer_has_password(const char *) { return 0; }
int rustdesk_bridge_main_peer_exists(const char *) { return 0; }
void rustdesk_bridge_main_set_peer_alias(const char *, const char *) {}
void rustdesk_bridge_main_set_peer_option(const char *, const char *, const char *) {}
void rustdesk_bridge_main_remove_peer(const char *) {}
const char *rustdesk_bridge_main_get_new_stored_peers(void) { return alloc_json_string("[]"); }
void rustdesk_bridge_main_load_recent_peers(void) {}
const char *rustdesk_bridge_main_get_langs(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_main_get_error(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_build_date(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_license(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_app_name(void) { return alloc_json_string("\"RustDesk (stub)\""); }
int rustdesk_bridge_main_has_hwcodec(void) { return 0; }
const char *rustdesk_bridge_main_generate2fa(void) { return alloc_empty_string(); }
int rustdesk_bridge_main_verify2fa(const char *) { return 0; }
const char *rustdesk_bridge_main_get_trusted_devices(void) { return alloc_json_string("[]"); }
void rustdesk_bridge_main_clear_trusted_devices(void) {}
void rustdesk_bridge_main_set_user_default_option(const char *, const char *) {}
const char *rustdesk_bridge_main_get_user_default_option(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_resolve_avatar_url(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_login_device_info(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_hard_option(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_buildin_option(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_common(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_common(const char *, const char *) {}
void rustdesk_bridge_main_check_connect_status(void) {}
void rustdesk_bridge_main_stop_service(void) {}
void rustdesk_bridge_main_on_main_window_close(void) {}
void rustdesk_bridge_main_wol(const char *) {}
void rustdesk_bridge_main_http_request(const char *, const char *, const char *, const char *) {}
int rustdesk_bridge_session_is_file_transfer(void) { return 0; }
int rustdesk_bridge_session_is_terminal(void) { return 0; }
int rustdesk_bridge_session_is_port_forward(void) { return 0; }
int rustdesk_bridge_session_is_rdp(void) { return 0; }
int rustdesk_bridge_session_is_view_camera(void) { return 0; }
void rustdesk_bridge_session_toggle_virtual_display(int, int) {}
const char *rustdesk_bridge_session_get_audit_server(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_session_send_selected_session_id(const char *) {}
const char *rustdesk_bridge_session_get_conn_token(void) { return alloc_empty_string(); }
void rustdesk_bridge_session_handle_flutter_key_event(const char *, const char *, int, int, int) {}
void rustdesk_bridge_session_handle_flutter_raw_key_event(const char *, const char *, int, int, int, int) {}
void rustdesk_bridge_session_send_touch_scale(int, int, int, int, int) {}
void rustdesk_bridge_session_send_touch_pan_event(const char *, int, int, int, int, int, int) {}
void rustdesk_bridge_session_refresh(void) {}
const char *rustdesk_bridge_session_get_peer_version(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_session_get_path_sep(void) { return alloc_json_string("\"/\""); }
int rustdesk_bridge_session_is_restarting_remote_device(void) { return 0; }
void rustdesk_bridge_cm_init(void) {}
const char *rustdesk_bridge_cm_get_clients_state(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_cm_check_clients_length(unsigned long long) { return alloc_empty_string(); }
unsigned long long rustdesk_bridge_cm_get_clients_length(void) { return 0; }
void rustdesk_bridge_cm_send_chat(int, const char *) {}
void rustdesk_bridge_cm_login_res(int, int) {}
void rustdesk_bridge_cm_close_connection(int) {}
void rustdesk_bridge_cm_remove_disconnected_connection(int) {}
void rustdesk_bridge_cm_check_click_time(int) {}
double rustdesk_bridge_cm_get_click_time(void) { return 0.0; }
void rustdesk_bridge_cm_switch_permission(int, const char *, int) {}
int rustdesk_bridge_cm_can_elevate(void) { return 0; }
void rustdesk_bridge_cm_elevate_portable(int) {}
void rustdesk_bridge_cm_switch_back(int) {}
const char *rustdesk_bridge_cm_get_config(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_cm_handle_incoming_voice_call(int, int) {}
void rustdesk_bridge_cm_close_voice_call(int) {}
void rustdesk_bridge_plugin_event(const char *, const char *, const char *) {}
void rustdesk_bridge_plugin_register_event_stream(const char *, const char *) {}
const char *rustdesk_bridge_plugin_get_session_option(const char *, const char *) { return alloc_empty_string(); }
void rustdesk_bridge_plugin_set_session_option(const char *, const char *, const char *) {}
const char *rustdesk_bridge_plugin_get_shared_option(const char *, const char *) { return alloc_empty_string(); }
void rustdesk_bridge_plugin_set_shared_option(const char *, const char *, const char *) {}
void rustdesk_bridge_plugin_reload(const char *) {}
void rustdesk_bridge_plugin_enable(const char *, int) {}
int rustdesk_bridge_plugin_is_enabled(const char *) { return 0; }
int rustdesk_bridge_plugin_feature_is_enabled(const char *) { return 0; }
void rustdesk_bridge_plugin_sync_ui(const char *) {}
void rustdesk_bridge_plugin_list_reload(void) {}
void rustdesk_bridge_plugin_install(const char *, int) {}
void rustdesk_bridge_install_install_me(const char *, const char *, const char *) {}
const char *rustdesk_bridge_install_install_options(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_install_install_path(void) { return alloc_empty_string(); }
int rustdesk_bridge_install_run_without_install(void) { return 0; }
int rustdesk_bridge_install_show_run_without_install(void) { return 0; }
int rustdesk_bridge_is_custom_client(void) { return 0; }
int rustdesk_bridge_is_disable_ab(void) { return 0; }
int rustdesk_bridge_is_disable_account(void) { return 0; }
int rustdesk_bridge_is_disable_group_panel(void) { return 0; }
int rustdesk_bridge_is_disable_installation(void) { return 0; }
int rustdesk_bridge_is_disable_settings(void) { return 0; }
int rustdesk_bridge_is_incoming_only(void) { return 0; }
int rustdesk_bridge_is_outgoing_only(void) { return 0; }
int rustdesk_bridge_is_preset_password(void) { return 0; }
int rustdesk_bridge_is_preset_password_mobile_only(void) { return 0; }
int rustdesk_bridge_is_selinux_enforcing(void) { return 0; }
int rustdesk_bridge_is_support_multi_ui_session(void) { return 0; }
void rustdesk_bridge_main_change_id(const char *) {}
void rustdesk_bridge_main_change_language(const char *) {}
void rustdesk_bridge_main_change_theme(const char *) {}
const char *rustdesk_bridge_main_get_displays(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_main_get_printer_names(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_main_get_socks(void) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_socks(const char *, const char *, const char *) {}
int rustdesk_bridge_main_get_proxy_status(void) { return 0; }
const char *rustdesk_bridge_main_get_app_name_sync(void) { return alloc_json_string("\"RustDesk (stub)\""); }
const char *rustdesk_bridge_main_get_new_version(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_home_dir(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_device_id(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_device_name(void) { return alloc_empty_string(); }
int rustdesk_bridge_main_is_installed(void) { return 0; }
int rustdesk_bridge_main_is_installed_daemon(void) { return 0; }
int rustdesk_bridge_main_is_root(void) { return 0; }
int rustdesk_bridge_main_is_process_trusted(void) { return 0; }
int rustdesk_bridge_main_is_can_screen_recording(void) { return 0; }
int rustdesk_bridge_main_is_can_input_monitoring(void) { return 0; }
int rustdesk_bridge_main_current_is_wayland(void) { return 0; }
int rustdesk_bridge_main_is_login_wayland(void) { return 0; }
int rustdesk_bridge_main_has_vram(void) { return 0; }
const char *rustdesk_bridge_main_supported_hwdecodings(void) { return alloc_empty_string(); }
void rustdesk_bridge_main_check_hwcodec(void) {}
int rustdesk_bridge_main_create_shortcut(void) { return 0; }
long long rustdesk_bridge_main_get_mouse_time(void) { return 0; }
int rustdesk_bridge_main_check_mouse_time(void) { return 0; }
const char *rustdesk_bridge_main_get_async_status(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_lan_peers(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_main_get_last_remote_id(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_fav(void) { return alloc_json_string("[]"); }
void rustdesk_bridge_main_store_fav(const char *) {}
const char *rustdesk_bridge_main_get_peer_sync(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_peer_flutter_option_sync(const char *, const char *) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_peer_flutter_option_sync(const char *, const char *, const char *) {}
const char *rustdesk_bridge_main_get_peer_option_sync(const char *, const char *) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_peer_option_sync(const char *, const char *, const char *) {}
void rustdesk_bridge_main_remove_trusted_devices(const char *) {}
int rustdesk_bridge_main_has_valid_2fa_sync(void) { return 0; }
int rustdesk_bridge_main_has_valid_bot_sync(void) { return 0; }
int rustdesk_bridge_main_verify_bot(const char *) { return 0; }
unsigned long long rustdesk_bridge_main_max_encrypt_len(void) { return 0; }
const char *rustdesk_bridge_main_get_unlock_pin(void) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_unlock_pin(const char *) {}
int rustdesk_bridge_main_option_synced(void) { return 0; }
int rustdesk_bridge_main_support_remove_wallpaper(void) { return 0; }
int rustdesk_bridge_main_test_wallpaper(void) { return 0; }
const char *rustdesk_bridge_main_supported_privacy_mode_impls(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_default_privacy_mode_impl(void) { return alloc_empty_string(); }
int rustdesk_bridge_main_is_option_fixed(const char *) { return 0; }
int rustdesk_bridge_main_get_use_texture_render(void) { return 0; }
int rustdesk_bridge_main_has_file_clipboard(void) { return 0; }
int rustdesk_bridge_main_has_gpu_texture_render(void) { return 0; }
int rustdesk_bridge_main_audio_support_loopback(void) { return 0; }
int rustdesk_bridge_main_is_share_rdp(void) { return 0; }
void rustdesk_bridge_main_set_share_rdp(int) {}
int rustdesk_bridge_main_is_installed_lower_version(void) { return 0; }
const char *rustdesk_bridge_main_get_software_update_url(void) { return alloc_empty_string(); }
void rustdesk_bridge_main_handle_relay_id(const char *) {}
void rustdesk_bridge_main_hide_dock(void) {}
void rustdesk_bridge_main_set_cursor_position(int, int) {}
void rustdesk_bridge_main_clip_cursor(void) {}
const char *rustdesk_bridge_main_get_env(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_env(const char *, const char *) {}
void rustdesk_bridge_main_set_home_dir(const char *) {}
void rustdesk_bridge_main_start_dbus_server(void) {}
void rustdesk_bridge_main_start_ipc_url_server(void) {}
int rustdesk_bridge_main_check_super_user_permission(void) { return 0; }
const char *rustdesk_bridge_main_goto_install(void) { return alloc_empty_string(); }
void rustdesk_bridge_main_update_me(const char *) {}
int rustdesk_bridge_main_deploy_device(void) { return 0; }
const char *rustdesk_bridge_main_get_main_display(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_input_source(void) { return alloc_empty_string(); }
void rustdesk_bridge_main_set_input_source(const char *) {}
void rustdesk_bridge_main_init_input_source(void) {}
const char *rustdesk_bridge_main_supported_input_source(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_video_save_directory(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_data_dir_ios(void) { return alloc_empty_string(); }
int rustdesk_bridge_main_show_option(const char *) { return 0; }
void rustdesk_bridge_main_set_options(const char *) {}
const char *rustdesk_bridge_main_get_options_sync(void) { return alloc_json_string("{}"); }
const char *rustdesk_bridge_main_get_option_sync(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_common_sync(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_get_http_status(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_uri_prefix_sync(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_main_load_ab(void) { return alloc_json_string("[]"); }
void rustdesk_bridge_main_save_ab(const char *) {}
void rustdesk_bridge_main_clear_ab(void) {}
const char *rustdesk_bridge_main_load_group(void) { return alloc_json_string("[]"); }
void rustdesk_bridge_main_save_group(const char *) {}
void rustdesk_bridge_main_clear_group(void) {}
const char *rustdesk_bridge_main_load_fav_peers(void) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_main_load_recent_peers_for_ab(void) { return alloc_json_string("[]"); }
void rustdesk_bridge_main_handle_wayland_screencast_restore_token(const char *) {}
double rustdesk_bridge_get_double_click_time(void) { return 500.0; }
const char *rustdesk_bridge_get_local_flutter_option(const char *) { return alloc_empty_string(); }
void rustdesk_bridge_set_local_flutter_option(const char *, const char *) {}
const char *rustdesk_bridge_get_local_kb_layout_type(void) { return alloc_empty_string(); }
void rustdesk_bridge_set_local_kb_layout_type(const char *) {}
const char *rustdesk_bridge_get_voice_call_input_device(void) { return alloc_empty_string(); }
void rustdesk_bridge_set_voice_call_input_device(const char *) {}
void rustdesk_bridge_host_stop_system_key_propagate(int) {}
int rustdesk_bridge_option_synced(void) { return 0; }
unsigned long long rustdesk_bridge_peer_get_sessions_count(void) { return 0; }
void rustdesk_bridge_send_url_scheme(const char *) {}
void rustdesk_bridge_set_cur_session_id(const char *) {}
void rustdesk_bridge_start_global_event_stream(void) {}
void rustdesk_bridge_stop_global_event_stream(void) {}
const char *rustdesk_bridge_translate(const char *name) { return alloc_empty_string(); }
long long rustdesk_bridge_version_to_number(const char *) { return 0; }
int rustdesk_bridge_will_session_close_close_session(void) { return 0; }
int rustdesk_bridge_get_next_texture_key(void) { return 0; }
int rustdesk_bridge_session_add_existed_sync(int) { return 0; }
void rustdesk_bridge_session_add_job(int, const char *, const char *, int, int, int) {}
void rustdesk_bridge_session_add_sync(int) {}
const char *rustdesk_bridge_session_get_audit_guid(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_session_get_audit_server_sync(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_session_get_common(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_session_get_common_sync(const char *) { return alloc_empty_string(); }
const char *rustdesk_bridge_session_get_conn_session_id(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_session_get_displays_as_individual_windows(void) { return alloc_empty_string(); }
int rustdesk_bridge_session_get_edge_scroll_edge_thickness(void) { return 0; }
const char *rustdesk_bridge_session_get_last_audit_note(void) { return alloc_empty_string(); }
int rustdesk_bridge_session_get_rgba_size(int) { return 0; }
int rustdesk_bridge_session_get_toggle_option_sync(const char *) { return 0; }
const char *rustdesk_bridge_session_get_use_all_my_displays_for_the_remote_session(void) { return alloc_empty_string(); }
const char *rustdesk_bridge_session_handle_screenshot(const char *) { return alloc_empty_string(); }
int rustdesk_bridge_session_is_multi_ui_session(void) { return 0; }
void rustdesk_bridge_session_next_rgba(int) {}
void rustdesk_bridge_session_on_waiting_for_image_dialog_show(void) {}
void rustdesk_bridge_session_printer_response(int, const char *, const char *) {}
void rustdesk_bridge_session_read_dir_to_remove_recursive(int, const char *, int) {}
const char *rustdesk_bridge_session_read_local_dir_sync(const char *, int, int) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_session_read_local_empty_dirs_recursive_sync(int, const char *) { return alloc_json_string("[]"); }
const char *rustdesk_bridge_session_read_remote_empty_dirs_recursive_sync(int, const char *) { return alloc_json_string("[]"); }
int rustdesk_bridge_session_register_gpu_texture(int) { return 0; }
int rustdesk_bridge_session_register_pixelbuffer_texture(int) { return 0; }
void rustdesk_bridge_session_remove_all_empty_dirs(int) {}
void rustdesk_bridge_session_request_new_display_init_msgs(int) {}
void rustdesk_bridge_session_send_pointer(const char *) {}
void rustdesk_bridge_session_set_audit_guid(const char *) {}
void rustdesk_bridge_session_set_displays_as_individual_windows(const char *) {}
void rustdesk_bridge_session_set_edge_scroll_edge_thickness(int) {}
void rustdesk_bridge_session_set_use_all_my_displays_for_the_remote_session(const char *) {}
int rustdesk_bridge_session_start_with_displays(const char *) { return 0; }
void rustdesk_bridge_main_init(const char *, const char *) {}
