#ifndef RUSTDESK_BRIDGE_ABI_H
#define RUSTDESK_BRIDGE_ABI_H

#ifdef __cplusplus
extern "C" {
#endif

const char *rustdesk_bridge_get_core_snapshot(const char *server);
const char *rustdesk_bridge_initialize_runtime(
    const char *app_dir,
    const char *custom_client_config);
const char *rustdesk_bridge_pull_session_events(void);
const char *rustdesk_bridge_get_latest_video_frame_metadata(unsigned long long since_frame_id);
int rustdesk_bridge_copy_latest_video_frame(
    unsigned long long frame_id,
    unsigned char *buffer,
    unsigned long long buffer_len);
const char *rustdesk_bridge_get_incoming_screen_frame_metadata(unsigned long long since_frame_id);
int rustdesk_bridge_copy_incoming_screen_frame(
    unsigned long long frame_id,
    unsigned char *buffer,
    unsigned long long buffer_len);
int rustdesk_bridge_update_incoming_screen_frame(
    int width,
    int height,
    int stride,
    long long timestamp,
    const char *format,
    const unsigned char *data,
    unsigned long long data_len);
void rustdesk_bridge_clear_incoming_screen_frame(void);
int rustdesk_bridge_refresh_session_video(int display);
void rustdesk_bridge_harmony_next_rgba(int display);
const char *rustdesk_bridge_bootstrap_core_snapshot(
    const char *display_id,
    const char *fingerprint,
    const char *direct_address,
    const char *server);
int rustdesk_bridge_send_clipboard_data(const char *content, long long timestamp);
int rustdesk_bridge_send_video_frame_metadata(
    int codec,
    int width,
    int height,
    long long timestamp,
    int key_frame,
    int data_length);
int rustdesk_bridge_send_audio_frame_metadata(
    int codec,
    int sample_rate,
    int channels,
    long long timestamp,
    int data_length);
int rustdesk_bridge_send_file_transfer_request(
    const char *task_id,
    const char *peer_id,
    const char *file_name,
    long long total_bytes,
    const char *direction);
void rustdesk_bridge_mark_session_connected(const char *peer_id);
void rustdesk_bridge_mark_session_error(const char *message);
int rustdesk_bridge_query_onlines(const char *ids_json);
const char *rustdesk_bridge_get_peer_info(const char *peer_id);
int rustdesk_bridge_apply_session_option(const char *key, const char *value);
int rustdesk_bridge_delete_remote_path(const char *path, int is_directory);
const char *rustdesk_bridge_pull_audio_frames(void);
void rustdesk_bridge_string_free(const char *value);

// ---- extended session & main functions ----
const char * rustdesk_bridge_get_session_stage(void);
const char * rustdesk_bridge_get_active_peer_id(void);
const char * rustdesk_bridge_get_connect_status_summary(void);
const char * rustdesk_bridge_get_connect_detail_message(void);
const char * rustdesk_bridge_get_connect_last_error(void);
const char * rustdesk_bridge_drain_connect_events_json(void);
const char * rustdesk_bridge_drain_connect_events(void);
const char * rustdesk_bridge_get_core_snapshot_json(const char * server);
const char * rustdesk_bridge_pull_session_events_json(void);
const char * rustdesk_bridge_pull_audio_frames_json(void);
const char * rustdesk_bridge_get_latest_video_frame_metadata_json(unsigned long long since_frame_id);
const char * rustdesk_bridge_get_incoming_screen_frame_metadata_json(unsigned long long since_frame_id);
const char * rustdesk_bridge_main_start_service(int enabled, const char * server, const char * relay_server, const char * api_server, const char * key);
int rustdesk_bridge_session_send_mouse(int mask, int x, int y);
int rustdesk_bridge_session_input_key(int key_code, int is_pressed, int modifiers);
int rustdesk_bridge_session_ctrl_alt_del(void);
int rustdesk_bridge_session_send_chat(const char * peer_id, const char * message_type, const char * content, long long timestamp);
void rustdesk_bridge_session_start(const char * peer_id, const char * password, const char * server, const char * relay_server, const char * api_server, const char * key);
void rustdesk_bridge_main_account_auth(const char * op, int remember_me, const char * server, const char * relay_server, const char * api_server);
void rustdesk_bridge_main_account_auth_cancel(void);
const char * rustdesk_bridge_main_account_auth_result(void);
const char * rustdesk_bridge_main_get_local_option(const char * key);
const char * rustdesk_bridge_main_get_peer_option(const char * peer_id, const char * key);
int rustdesk_bridge_session_get_toggle_option(const char * key);
void rustdesk_bridge_main_set_local_option(const char * key, const char * value);
int rustdesk_bridge_session_reconnect(int force_relay);
void rustdesk_bridge_session_close(void);
int rustdesk_bridge_session_login(const char * password, int remember);
int rustdesk_bridge_session_restart_remote_device(void);
int rustdesk_bridge_session_lock_screen(void);
int rustdesk_bridge_session_open_terminal(int terminal_id, int rows, int cols);
int rustdesk_bridge_session_send_terminal_input(int terminal_id, const char * data);
int rustdesk_bridge_session_resize_terminal(int terminal_id, int rows, int cols);
int rustdesk_bridge_session_close_terminal(int terminal_id);
int rustdesk_bridge_session_read_remote_dir(const char * path, int include_hidden);
int rustdesk_bridge_session_create_dir(const char * path);
int rustdesk_bridge_session_send_files(const char * path, const char * to, int is_remote);
void rustdesk_bridge_main_discover(void);
const char * rustdesk_bridge_main_load_lan_peers(void);
int rustdesk_bridge_main_remove_discovered(const char * peer_id);
int rustdesk_bridge_session_send2fa(const char * code, int trust_this_device);
void rustdesk_bridge_session_toggle_option(const char * name);
int rustdesk_bridge_session_toggle_privacy_mode(const char * impl_key, int on);
int rustdesk_bridge_session_switch_display(int display);
int rustdesk_bridge_session_enter_or_leave(void);
int rustdesk_bridge_session_leave(void);
void rustdesk_bridge_session_set_size(unsigned long long display, unsigned long long width, unsigned long long height);
void rustdesk_bridge_session_change_resolution(int display, int width, int height);
void rustdesk_bridge_session_elevate_direct(void);
void rustdesk_bridge_session_elevate_with_logon(const char * username, const char * password);
int rustdesk_bridge_session_switch_sides(void);
int rustdesk_bridge_session_take_screenshot(unsigned long long display);
int rustdesk_bridge_session_record_screen(int start);
int rustdesk_bridge_session_get_is_recording(void);
int rustdesk_bridge_session_request_voice_call(void);
int rustdesk_bridge_session_close_voice_call(void);
void rustdesk_bridge_session_add_port_forward(int local_port, const char * remote_host, int remote_port);
void rustdesk_bridge_session_remove_port_forward(int local_port);
void rustdesk_bridge_session_new_rdp(void);
void rustdesk_bridge_session_remove_file(int act_id, const char * path, int file_num, int is_remote);
void rustdesk_bridge_session_rename_file(int act_id, const char * path, const char * new_name, int is_remote);
void rustdesk_bridge_session_cancel_job(int act_id);
void rustdesk_bridge_session_resume_job(int act_id, int is_remote);
void rustdesk_bridge_session_set_confirm_override_file(int act_id, int file_num, int need_override, int remember, int is_upload);
void rustdesk_bridge_session_send_note(const char * note);
void rustdesk_bridge_session_input_string(const char * value);
void rustdesk_bridge_session_input_os_password(const char * pass);
void rustdesk_bridge_session_load_last_transfer_jobs(void);
const char * rustdesk_bridge_session_get_view_style(void);
void rustdesk_bridge_session_set_view_style(const char * value);
const char * rustdesk_bridge_session_get_scroll_style(void);
void rustdesk_bridge_session_set_scroll_style(const char * value);
const char * rustdesk_bridge_session_get_image_quality(void);
void rustdesk_bridge_session_set_image_quality(const char * value);
const char * rustdesk_bridge_session_get_keyboard_mode(void);
void rustdesk_bridge_session_set_keyboard_mode(const char * value);
const char * rustdesk_bridge_session_get_custom_image_quality(void);
void rustdesk_bridge_session_set_custom_image_quality(int value);
void rustdesk_bridge_session_set_custom_fps(int fps);
int rustdesk_bridge_session_get_trackpad_speed(void);
void rustdesk_bridge_session_set_trackpad_speed(int value);
const char * rustdesk_bridge_session_get_flutter_option(const char * k);
void rustdesk_bridge_session_set_flutter_option(const char * k, const char * v);
const char * rustdesk_bridge_session_get_reverse_mouse_wheel_sync(void);
void rustdesk_bridge_session_set_reverse_mouse_wheel(const char * value);
const char * rustdesk_bridge_session_get_option(const char * k);
void rustdesk_bridge_session_set_option(const char * k, const char * v);
const char * rustdesk_bridge_session_get_peer_option(const char * name);
void rustdesk_bridge_session_peer_option(const char * name, const char * value);
int rustdesk_bridge_session_is_keyboard_mode_supported(const char * mode);
const char * rustdesk_bridge_session_get_platform(int is_remote);
int rustdesk_bridge_session_get_remember(void);
int rustdesk_bridge_session_get_enable_trusted_devices(void);
const char * rustdesk_bridge_session_get_alternative_codecs(void);
void rustdesk_bridge_session_change_prefer_codec(void);
const char * rustdesk_bridge_main_get_option(const char * key);
void rustdesk_bridge_main_set_option(const char * key, const char * value);
const char * rustdesk_bridge_main_get_options(void);
const char * rustdesk_bridge_main_get_my_id(void);
const char * rustdesk_bridge_main_get_uuid(void);
const char * rustdesk_bridge_main_get_version(void);
const char * rustdesk_bridge_main_get_fingerprint(void);
const char * rustdesk_bridge_main_get_api_server(void);
const char * rustdesk_bridge_main_get_temporary_password(void);
int rustdesk_bridge_main_set_permanent_password_with_result(const char * password);
void rustdesk_bridge_main_update_temporary_password(void);
const char * rustdesk_bridge_main_test_if_valid_server(const char * server);
const char * rustdesk_bridge_main_get_connect_status(void);
int rustdesk_bridge_main_is_using_public_server(void);
void rustdesk_bridge_main_forget_password(const char * id);
int rustdesk_bridge_main_peer_has_password(const char * id);
int rustdesk_bridge_main_peer_exists(const char * id);
void rustdesk_bridge_main_set_peer_alias(const char * id, const char * alias);
void rustdesk_bridge_main_set_peer_option(const char * id, const char * key, const char * value);
void rustdesk_bridge_main_remove_peer(const char * id);
const char * rustdesk_bridge_main_get_new_stored_peers(void);
void rustdesk_bridge_main_load_recent_peers(void);
const char * rustdesk_bridge_main_get_langs(void);
const char * rustdesk_bridge_main_get_error(void);
const char * rustdesk_bridge_main_get_build_date(void);
const char * rustdesk_bridge_main_get_license(void);
const char * rustdesk_bridge_main_get_app_name(void);
int rustdesk_bridge_main_has_hwcodec(void);
const char * rustdesk_bridge_main_generate2fa(void);
int rustdesk_bridge_main_verify2fa(const char * code);
const char * rustdesk_bridge_main_get_trusted_devices(void);
void rustdesk_bridge_main_clear_trusted_devices(void);
void rustdesk_bridge_main_set_user_default_option(const char * key, const char * value);
const char * rustdesk_bridge_main_get_user_default_option(const char * key);
const char * rustdesk_bridge_main_resolve_avatar_url(const char * avatar);
const char * rustdesk_bridge_main_get_login_device_info(void);
const char * rustdesk_bridge_main_get_hard_option(const char * key);
const char * rustdesk_bridge_main_get_buildin_option(const char * key);
const char * rustdesk_bridge_main_get_common(const char * key);
void rustdesk_bridge_main_set_common(const char * key, const char * value);
void rustdesk_bridge_main_check_connect_status(void);
void rustdesk_bridge_main_stop_service(void);
void rustdesk_bridge_main_on_main_window_close(void);
void rustdesk_bridge_main_wol(const char * id);
void rustdesk_bridge_main_http_request(const char * url, const char * method, const char * body, const char * header);
int rustdesk_bridge_session_is_file_transfer(void);
int rustdesk_bridge_session_is_terminal(void);
int rustdesk_bridge_session_is_port_forward(void);
int rustdesk_bridge_session_is_rdp(void);
int rustdesk_bridge_session_is_view_camera(void);
void rustdesk_bridge_session_toggle_virtual_display(int index, int on);
const char * rustdesk_bridge_session_get_audit_server(const char * typ);
void rustdesk_bridge_session_send_selected_session_id(const char * sid);
const char * rustdesk_bridge_session_get_conn_token(void);
void rustdesk_bridge_session_handle_flutter_key_event(const char * keyboard_mode, const char * character, int usb_hid, int lock_modes, int down_or_up);
void rustdesk_bridge_session_handle_flutter_raw_key_event(const char * keyboard_mode, const char * name, int platform_code, int position_code, int lock_modes, int down_or_up);
void rustdesk_bridge_session_send_touch_scale(int scale, int alt, int ctrl, int shift, int command);
void rustdesk_bridge_session_send_touch_pan_event(const char * event, int x, int y, int alt, int ctrl, int shift, int command);
void rustdesk_bridge_session_refresh(void);
const char * rustdesk_bridge_session_get_peer_version(void);
const char * rustdesk_bridge_session_get_path_sep(void);
int rustdesk_bridge_session_is_restarting_remote_device(void);
void rustdesk_bridge_cm_init(void);
const char * rustdesk_bridge_cm_get_clients_state(void);
const char * rustdesk_bridge_cm_check_clients_length(unsigned long long length);
unsigned long long rustdesk_bridge_cm_get_clients_length(void);
void rustdesk_bridge_cm_send_chat(int conn_id, const char * msg);
void rustdesk_bridge_cm_login_res(int conn_id, int res);
void rustdesk_bridge_cm_close_connection(int conn_id);
void rustdesk_bridge_cm_remove_disconnected_connection(int conn_id);
void rustdesk_bridge_cm_check_click_time(int conn_id);
double rustdesk_bridge_cm_get_click_time(void);
void rustdesk_bridge_cm_switch_permission(int conn_id, const char * name, int enabled);
int rustdesk_bridge_cm_can_elevate(void);
void rustdesk_bridge_cm_elevate_portable(int conn_id);
void rustdesk_bridge_cm_switch_back(int conn_id);
const char * rustdesk_bridge_cm_get_config(const char * name);
void rustdesk_bridge_cm_handle_incoming_voice_call(int id, int accept);
void rustdesk_bridge_cm_close_voice_call(int id);
void rustdesk_bridge_plugin_event(const char * id, const char * peer, const char * msg);
void rustdesk_bridge_plugin_register_event_stream(const char * id, const char * peer);
const char * rustdesk_bridge_plugin_get_session_option(const char * id, const char * key);
void rustdesk_bridge_plugin_set_session_option(const char * id, const char * key, const char * value);
const char * rustdesk_bridge_plugin_get_shared_option(const char * id, const char * key);
void rustdesk_bridge_plugin_set_shared_option(const char * id, const char * key, const char * value);
void rustdesk_bridge_plugin_reload(const char * id);
void rustdesk_bridge_plugin_enable(const char * id, int enable);
int rustdesk_bridge_plugin_is_enabled(const char * id);
int rustdesk_bridge_plugin_feature_is_enabled(const char * id);
void rustdesk_bridge_plugin_sync_ui(const char * id);
void rustdesk_bridge_plugin_list_reload(void);
void rustdesk_bridge_plugin_install(const char * id, int b);
void rustdesk_bridge_install_install_me(const char * path, const char * options, const char * exe);
const char * rustdesk_bridge_install_install_options(void);
const char * rustdesk_bridge_install_install_path(void);
int rustdesk_bridge_install_run_without_install(void);
int rustdesk_bridge_install_show_run_without_install(void);
int rustdesk_bridge_is_custom_client(void);
int rustdesk_bridge_is_disable_ab(void);
int rustdesk_bridge_is_disable_account(void);
int rustdesk_bridge_is_disable_group_panel(void);
int rustdesk_bridge_is_disable_installation(void);
int rustdesk_bridge_is_disable_settings(void);
int rustdesk_bridge_is_incoming_only(void);
int rustdesk_bridge_is_outgoing_only(void);
int rustdesk_bridge_is_preset_password(void);
int rustdesk_bridge_is_preset_password_mobile_only(void);
int rustdesk_bridge_is_selinux_enforcing(void);
int rustdesk_bridge_is_support_multi_ui_session(void);
void rustdesk_bridge_main_change_id(const char * id);
void rustdesk_bridge_main_change_language(const char * lang);
void rustdesk_bridge_main_change_theme(const char * dark);
const char * rustdesk_bridge_main_get_displays(void);
const char * rustdesk_bridge_main_get_printer_names(void);
const char * rustdesk_bridge_main_get_socks(void);
void rustdesk_bridge_main_set_socks(const char * proxy, const char * username, const char * password);
int rustdesk_bridge_main_get_proxy_status(void);
const char * rustdesk_bridge_main_get_app_name_sync(void);
const char * rustdesk_bridge_main_get_new_version(void);
const char * rustdesk_bridge_main_get_home_dir(void);
const char * rustdesk_bridge_main_device_id(void);
const char * rustdesk_bridge_main_device_name(void);
int rustdesk_bridge_main_is_installed(void);
int rustdesk_bridge_main_is_installed_daemon(void);
int rustdesk_bridge_main_is_root(void);
int rustdesk_bridge_main_is_process_trusted(void);
int rustdesk_bridge_main_is_can_screen_recording(void);
int rustdesk_bridge_main_is_can_input_monitoring(void);
int rustdesk_bridge_main_current_is_wayland(void);
int rustdesk_bridge_main_is_login_wayland(void);
int rustdesk_bridge_main_has_vram(void);
const char * rustdesk_bridge_main_supported_hwdecodings(void);
void rustdesk_bridge_main_check_hwcodec(void);
int rustdesk_bridge_main_create_shortcut(void);
long long rustdesk_bridge_main_get_mouse_time(void);
int rustdesk_bridge_main_check_mouse_time(void);
const char * rustdesk_bridge_main_get_async_status(void);
const char * rustdesk_bridge_main_get_lan_peers(void);
const char * rustdesk_bridge_main_get_last_remote_id(void);
const char * rustdesk_bridge_main_get_fav(void);
void rustdesk_bridge_main_store_fav(const char * fav);
const char * rustdesk_bridge_main_get_peer_sync(const char * id);
const char * rustdesk_bridge_main_get_peer_flutter_option_sync(const char * id, const char * k);
void rustdesk_bridge_main_set_peer_flutter_option_sync(const char * id, const char * k, const char * v);
const char * rustdesk_bridge_main_get_peer_option_sync(const char * id, const char * k);
void rustdesk_bridge_main_set_peer_option_sync(const char * id, const char * k, const char * v);
void rustdesk_bridge_main_remove_trusted_devices(const char * json);
int rustdesk_bridge_main_has_valid_2fa_sync(void);
int rustdesk_bridge_main_has_valid_bot_sync(void);
int rustdesk_bridge_main_verify_bot(const char * token);
unsigned long long rustdesk_bridge_main_max_encrypt_len(void);
const char * rustdesk_bridge_main_get_unlock_pin(void);
void rustdesk_bridge_main_set_unlock_pin(const char * pin);
int rustdesk_bridge_main_option_synced(void);
int rustdesk_bridge_main_support_remove_wallpaper(void);
int rustdesk_bridge_main_test_wallpaper(void);
const char * rustdesk_bridge_main_supported_privacy_mode_impls(void);
const char * rustdesk_bridge_main_default_privacy_mode_impl(void);
int rustdesk_bridge_main_is_option_fixed(const char * key);
int rustdesk_bridge_main_get_use_texture_render(void);
int rustdesk_bridge_main_has_file_clipboard(void);
int rustdesk_bridge_main_has_gpu_texture_render(void);
int rustdesk_bridge_main_audio_support_loopback(void);
int rustdesk_bridge_main_is_share_rdp(void);
void rustdesk_bridge_main_set_share_rdp(int v);
int rustdesk_bridge_main_is_installed_lower_version(void);
const char * rustdesk_bridge_main_get_software_update_url(void);
void rustdesk_bridge_main_handle_relay_id(const char * id);
void rustdesk_bridge_main_hide_dock(void);
void rustdesk_bridge_main_set_cursor_position(int x, int y);
void rustdesk_bridge_main_clip_cursor(void);
const char * rustdesk_bridge_main_get_env(const char * key);
void rustdesk_bridge_main_set_env(const char * key, const char * value);
void rustdesk_bridge_main_set_home_dir(const char * home);
void rustdesk_bridge_main_start_dbus_server(void);
void rustdesk_bridge_main_start_ipc_url_server(void);
int rustdesk_bridge_main_check_super_user_permission(void);
const char * rustdesk_bridge_main_goto_install(void);
void rustdesk_bridge_main_update_me(const char * path);
int rustdesk_bridge_main_deploy_device(void);
const char * rustdesk_bridge_main_get_main_display(void);
const char * rustdesk_bridge_main_get_input_source(void);
void rustdesk_bridge_main_set_input_source(const char * source);
void rustdesk_bridge_main_init_input_source(void);
const char * rustdesk_bridge_main_supported_input_source(void);
const char * rustdesk_bridge_main_video_save_directory(void);
const char * rustdesk_bridge_main_get_data_dir_ios(void);
int rustdesk_bridge_main_show_option(const char * key);
void rustdesk_bridge_main_set_options(const char * options);
const char * rustdesk_bridge_main_get_options_sync(void);
const char * rustdesk_bridge_main_get_option_sync(const char * key);
const char * rustdesk_bridge_main_get_common_sync(const char * key);
const char * rustdesk_bridge_main_get_http_status(void);
const char * rustdesk_bridge_main_uri_prefix_sync(void);
const char * rustdesk_bridge_main_load_ab(void);
void rustdesk_bridge_main_save_ab(const char * ab);
void rustdesk_bridge_main_clear_ab(void);
const char * rustdesk_bridge_main_load_group(void);
void rustdesk_bridge_main_save_group(const char * group);
void rustdesk_bridge_main_clear_group(void);
const char * rustdesk_bridge_main_load_fav_peers(void);
const char * rustdesk_bridge_main_load_recent_peers_for_ab(void);
void rustdesk_bridge_main_handle_wayland_screencast_restore_token(const char * token);
double rustdesk_bridge_get_double_click_time(void);
const char * rustdesk_bridge_get_local_flutter_option(const char * k);
void rustdesk_bridge_set_local_flutter_option(const char * k, const char * v);
const char * rustdesk_bridge_get_local_kb_layout_type(void);
void rustdesk_bridge_set_local_kb_layout_type(const char * v);
const char * rustdesk_bridge_get_voice_call_input_device(void);
void rustdesk_bridge_set_voice_call_input_device(const char * device);
void rustdesk_bridge_host_stop_system_key_propagate(int stop);
int rustdesk_bridge_option_synced(void);
unsigned long long rustdesk_bridge_peer_get_sessions_count(void);
void rustdesk_bridge_send_url_scheme(const char * url);
void rustdesk_bridge_set_cur_session_id(const char * id);
void rustdesk_bridge_start_global_event_stream(void);
void rustdesk_bridge_stop_global_event_stream(void);
const char * rustdesk_bridge_translate(const char * name);
long long rustdesk_bridge_version_to_number(const char * v);
int rustdesk_bridge_will_session_close_close_session(void);
int rustdesk_bridge_get_next_texture_key(void);

// ---- extended session & main functions ----
int rustdesk_bridge_session_add_existed_sync(int is_sync);
void rustdesk_bridge_session_add_job(int id, const char * path, const char * to, int file_num, int include_hidden, int is_remote);
void rustdesk_bridge_session_add_sync(int is_sync);
const char * rustdesk_bridge_session_get_audit_guid(void);
const char * rustdesk_bridge_session_get_audit_server_sync(const char * typ);
const char * rustdesk_bridge_session_get_common(const char * key);
const char * rustdesk_bridge_session_get_common_sync(const char * key);
const char * rustdesk_bridge_session_get_conn_session_id(void);
const char * rustdesk_bridge_session_get_displays_as_individual_windows(void);
int rustdesk_bridge_session_get_edge_scroll_edge_thickness(void);
const char * rustdesk_bridge_session_get_last_audit_note(void);
int rustdesk_bridge_session_get_rgba_size(int display);
int rustdesk_bridge_session_get_toggle_option_sync(const char * arg);
const char * rustdesk_bridge_session_get_use_all_my_displays_for_the_remote_session(void);
const char * rustdesk_bridge_session_handle_screenshot(const char * action);
int rustdesk_bridge_session_is_multi_ui_session(void);
void rustdesk_bridge_session_next_rgba(int display);
void rustdesk_bridge_session_on_waiting_for_image_dialog_show(void);
void rustdesk_bridge_session_printer_response(int id, const char * path, const char * printer_name);
void rustdesk_bridge_session_read_dir_to_remove_recursive(int id, const char * path, int include_hidden);
const char * rustdesk_bridge_session_read_local_dir_sync(const char * path, int include_hidden, int id);
const char * rustdesk_bridge_session_read_local_empty_dirs_recursive_sync(int id, const char * path);
const char * rustdesk_bridge_session_read_remote_empty_dirs_recursive_sync(int id, const char * path);
int rustdesk_bridge_session_register_gpu_texture(int display);
int rustdesk_bridge_session_register_pixelbuffer_texture(int display);
void rustdesk_bridge_session_remove_all_empty_dirs(int id);
void rustdesk_bridge_session_request_new_display_init_msgs(int display);
void rustdesk_bridge_session_send_pointer(const char * msg);
void rustdesk_bridge_session_set_audit_guid(const char * guid);
void rustdesk_bridge_session_set_displays_as_individual_windows(const char * value);
void rustdesk_bridge_session_set_edge_scroll_edge_thickness(int value);
void rustdesk_bridge_session_set_use_all_my_displays_for_the_remote_session(const char * value);
int rustdesk_bridge_session_start_with_displays(const char * displays);
void rustdesk_bridge_main_init(const char * app_dir, const char * custom_client_config);

#ifdef __cplusplus
}

#endif

#endif
