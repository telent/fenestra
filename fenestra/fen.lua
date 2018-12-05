local ffi = require("ffi")
ffi.cdef[[
struct wl_display { void *p; };
struct wl_event_loop * wl_display_get_event_loop(struct wl_display *);
struct wl_display *wl_display_create(void);
struct wlr_renderer { void *p; };
typedef struct wlr_renderer *(*wlr_renderer_create_func_t)();
struct wlr_backend *wlr_backend_autocreate(struct wl_display *display,
		wlr_renderer_create_func_t create_renderer_func);
void wl_display_run(struct wl_display *display);
int wlr_backend_start(struct wlr_backend *backend);

]]


local wlroots = ffi.load('../build/libwlroots.so')

local wayland = ffi.load(package.searchpath('wayland-server',package.cpath))

local display = wayland.wl_display_create()

print(display)
local event_loop = wayland.wl_display_get_event_loop(display)
local backend = wlroots.wlr_backend_autocreate(display, nil)
print(backend)

wlroots.wlr_backend_start(backend)
wayland.wl_display_run(display);

return 0
-- wl_display_destroy(display);
