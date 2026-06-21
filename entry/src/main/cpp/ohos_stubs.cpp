#include <cstdlib>
#include <cstring>
#include <cstdint>

extern "C" {

// Huawei phone controlled-side input injection is currently shelved: tested
// devices return the platform boundary code 201 and do not expose a usable
// third-party authorization path. Keep these symbols so the Core staticlib can
// link, but do not package a real input-injection implementation.
int32_t rustdesk_ohos_request_input_authorization() { return 201; }
int32_t rustdesk_ohos_query_input_authorization() { return 201; }
void rustdesk_ohos_cancel_input_authorization() {}
void rustdesk_ohos_set_input_enabled(int32_t) {}
int32_t rustdesk_ohos_inject_mouse(int32_t, int32_t, int32_t) { return 201; }
int32_t rustdesk_ohos_inject_key(int32_t, uint32_t, int32_t, int32_t, uint32_t) { return 201; }

void *xcb_connect(const char *, int) { return nullptr; }
int xcb_connection_has_error(void *) { return 1; }
void xcb_disconnect(void *) {}
unsigned int xcb_generate_id(void *) { return 0; }

struct xcb_get_atom_name_reply_t {};
typedef struct xcb_get_atom_name_reply_t xcb_get_atom_name_reply_t;

void *xcb_get_atom_name(void *, unsigned int) { return nullptr; }
const char *xcb_get_atom_name_name(xcb_get_atom_name_reply_t *) { return ""; }
int xcb_get_atom_name_name_length(xcb_get_atom_name_reply_t *) { return 0; }
void *xcb_get_atom_name_reply(void *, void *, int *) { return nullptr; }

struct xcb_get_geometry_reply_t {};
void *xcb_get_geometry_reply(void *, void *, int *) { return nullptr; }
void *xcb_get_geometry_unchecked(void *, unsigned int) { return nullptr; }

struct xcb_setup_t {};
void *xcb_get_setup(void *) { return nullptr; }

struct xcb_randr_get_monitors_reply_t {};
struct xcb_randr_monitor_info_iterator_t {};
void *xcb_randr_get_monitors_reply(void *, void *, int *) { return nullptr; }
void *xcb_randr_get_monitors_unchecked(void *, unsigned int) { return nullptr; }
xcb_randr_monitor_info_iterator_t xcb_randr_get_monitors_monitors_iterator(void *) {
  xcb_randr_monitor_info_iterator_t it;
  memset(&it, 0, sizeof(it));
  return it;
}
void xcb_randr_monitor_info_next(xcb_randr_monitor_info_iterator_t *) {}

struct xcb_screen_iterator_t {};
xcb_screen_iterator_t xcb_screen_next(xcb_screen_iterator_t *) {
  xcb_screen_iterator_t it;
  memset(&it, 0, sizeof(it));
  return it;
}

struct xcb_setup_roots_iterator_t {};
xcb_setup_roots_iterator_t xcb_setup_roots_iterator(void *) {
  xcb_setup_roots_iterator_t it;
  memset(&it, 0, sizeof(it));
  return it;
}

void xcb_shm_attach(void *, unsigned int, int, unsigned int) {}
void xcb_shm_detach(void *, unsigned int) {}

struct xcb_shm_get_image_reply_t {};
void *xcb_shm_get_image_reply(void *, void *, int *) { return nullptr; }
void *xcb_shm_get_image_unchecked(void *, unsigned int, int, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int, unsigned int) { return nullptr; }

struct xcb_shm_query_version_reply_t {};
void *xcb_shm_query_version(void *) { return nullptr; }
void *xcb_shm_query_version_reply(void *, void *, int *) { return nullptr; }

int OH_TimeService_GetTimeZone(char *timeZone, uint32_t len) {
  static const char kFallbackTimeZone[] = "UTC";
  if (timeZone == nullptr || len <= sizeof(kFallbackTimeZone) - 1) {
    return 13000002;
  }
  std::memcpy(timeZone, kFallbackTimeZone, sizeof(kFallbackTimeZone));
  return 0;
}

}
