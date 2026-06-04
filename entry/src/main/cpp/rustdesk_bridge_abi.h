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
int rustdesk_bridge_refresh_session_video(int display);
void rustdesk_bridge_harmony_next_rgba(int display);
const char *rustdesk_bridge_set_incoming_service_enabled(
    int enabled,
    const char *server,
    const char *relay_server,
    const char *api_server);
const char *rustdesk_bridge_bootstrap_core_snapshot(
    const char *display_id,
    const char *fingerprint,
    const char *direct_address,
    const char *server);
int rustdesk_bridge_send_mouse_input(int mask, int x, int y);
int rustdesk_bridge_send_keyboard_input(int key_code, int is_pressed, int modifiers);
int rustdesk_bridge_send_ctrl_alt_del(void);
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
int rustdesk_bridge_send_chat_message(
    const char *peer_id,
    const char *message_type,
    const char *content,
    long long timestamp);
int rustdesk_bridge_send_file_transfer_request(
    const char *task_id,
    const char *peer_id,
    const char *file_name,
    long long total_bytes,
    const char *direction);
void rustdesk_bridge_connect_to_peer(
    const char *peer_id,
    const char *password,
    const char *server,
    const char *relay_server,
    const char *api_server);
void rustdesk_bridge_account_auth(
    const char *op,
    int remember_me,
    const char *server,
    const char *relay_server,
    const char *api_server);
void rustdesk_bridge_account_auth_cancel(void);
const char *rustdesk_bridge_account_auth_result(void);
const char *rustdesk_bridge_get_local_option(const char *key);
void rustdesk_bridge_set_local_option(const char *key, const char *value);
void rustdesk_bridge_close_session(void);
int rustdesk_bridge_reconnect_session(int force_relay);
int rustdesk_bridge_submit_session_password(const char *password, int remember);
int rustdesk_bridge_open_terminal(int terminal_id, int rows, int cols);
int rustdesk_bridge_send_terminal_input(int terminal_id, const char *data);
int rustdesk_bridge_resize_terminal(int terminal_id, int rows, int cols);
int rustdesk_bridge_close_terminal(int terminal_id);
int rustdesk_bridge_read_remote_directory(const char *path, int include_hidden);
int rustdesk_bridge_create_remote_directory(const char *path);
int rustdesk_bridge_delete_remote_path(const char *path, int is_directory);
int rustdesk_bridge_start_file_transfer(const char *path, const char *to, int is_remote);
void rustdesk_bridge_mark_session_connected(const char *peer_id);
void rustdesk_bridge_mark_session_error(const char *message);
int rustdesk_bridge_query_onlines(const char *ids_json);
void rustdesk_bridge_discover_lan_peers(void);
const char *rustdesk_bridge_load_lan_peers(void);
int rustdesk_bridge_remove_discovered_peer(const char *peer_id);
const char *rustdesk_bridge_get_peer_option(const char *peer_id, const char *key);
const char *rustdesk_bridge_get_peer_info(const char *peer_id);
int rustdesk_bridge_get_session_toggle_option(const char *key);
int rustdesk_bridge_apply_session_option(const char *key, const char *value);
int rustdesk_bridge_restart_remote_device(void);
int rustdesk_bridge_lock_remote_screen(void);
const char *rustdesk_bridge_pull_audio_frames(void);
void rustdesk_bridge_string_free(const char *value);

#ifdef __cplusplus
}
#endif

#endif
