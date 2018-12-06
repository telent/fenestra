-- this is a cut-paste-translate job from
-- https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html

inspect = dofile(string.gsub(os.getenv("LUA_INSPECT"), '/.lua$/', '')).inspect

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
void wl_display_destroy(struct wl_display *display);
int wlr_backend_start(struct wlr_backend *backend);
struct wl_list {
        struct wl_list *prev;
        struct wl_list *next;
}; 

void wl_list_insert(struct wl_list *list, struct wl_list *elm );
bool wl_list_empty (const struct wl_list *list);

struct wl_signal {
         struct wl_list listener_list;
};
static inline void
wl_signal_add(struct wl_signal *signal, struct wl_listener *listener)
{
         wl_list_insert(signal->listener_list.prev, &listener->link);
}
typedef void(* wl_notify_func_t) (struct wl_listener *listener, void *data);
struct wl_listener {
        struct wl_list link;
        wl_notify_func_t notify;
};

struct wlr_backend {
	const struct wlr_backend_impl *impl;

	struct {
		/** Raised when destroyed, passed the wlr_backend reference */
		struct wl_signal destroy;
		/** Raised when new inputs are added, passed the wlr_input_device */
		struct wl_signal new_input;
		/** Raised when new outputs are added, passed the wlr_output */
		struct wl_signal new_output;
	} events;
};

typedef struct pixman_region32_data     pixman_region32_data_t;
typedef struct pixman_box32             pixman_box32_t;
typedef struct pixman_rectangle32       pixman_rectangle32_t;
typedef struct pixman_region32          pixman_region32_t;

struct pixman_region32_data {
    long                size;
    long                numRects;
/*  pixman_box32_t      rects[size];   in memory but not explicitly declared */
};

struct pixman_rectangle32
{
    int32_t x, y;
    uint32_t width, height;
};

struct pixman_box32
{
    int32_t x1, y1, x2, y2;
};

struct pixman_region32
{
    pixman_box32_t          extents;
    pixman_region32_data_t  *data;
};

typedef int int32_t;

enum wl_output_subpixel {
  WL_OUTPUT_SUBPIXEL_UNKNOWN = 0, WL_OUTPUT_SUBPIXEL_NONE = 1, WL_OUTPUT_SUBPIXEL_HORIZONTAL_RGB = 2, WL_OUTPUT_SUBPIXEL_HORIZONTAL_BGR = 3,
  WL_OUTPUT_SUBPIXEL_VERTICAL_RGB = 4, WL_OUTPUT_SUBPIXEL_VERTICAL_BGR = 5
};

enum wl_output_transform {
  WL_OUTPUT_TRANSFORM_NORMAL = 0, WL_OUTPUT_TRANSFORM_90 = 1, WL_OUTPUT_TRANSFORM_180 = 2, WL_OUTPUT_TRANSFORM_270 = 3,
  WL_OUTPUT_TRANSFORM_FLIPPED = 4, WL_OUTPUT_TRANSFORM_FLIPPED_90 = 5, WL_OUTPUT_TRANSFORM_FLIPPED_180 = 6, WL_OUTPUT_TRANSFORM_FLIPPED_270 = 7
};

struct wlr_output {
	const struct wlr_output_impl *impl;
	struct wlr_backend *backend;
	struct wl_display *display;

	struct wl_global *global;
	struct wl_list resources;

	char name[24];
	char make[56];
	char model[16];
	char serial[16];
	int32_t phys_width, phys_height; // mm

	// Note: some backends may have zero modes
	struct wl_list modes;
	struct wlr_output_mode *current_mode;
	int32_t width, height;
	int32_t refresh; // mHz, may be zero

	bool enabled;
	float scale;
	enum wl_output_subpixel subpixel;
	enum wl_output_transform transform;

	bool needs_swap;
	// damage for cursors and fullscreen surface, in output-local coordinates
	pixman_region32_t damage;
	bool frame_pending;
	float transform_matrix[9];

	struct {
		// Request to render a frame
		struct wl_signal frame;
		// Emitted when buffers need to be swapped (because software cursors or
		// fullscreen damage or because of backend-specific logic)
		struct wl_signal needs_swap;
		// Emitted right before buffer swap
		struct wl_signal swap_buffers; // wlr_output_event_swap_buffers
		// Emitted right after the buffer has been presented to the user
		struct wl_signal present; // wlr_output_event_present
		struct wl_signal enable;
		struct wl_signal mode;
		struct wl_signal scale;
		struct wl_signal transform;
		struct wl_signal destroy;
	} events;

	struct wl_event_source *idle_frame;

	struct wl_list cursors; // wlr_output_cursor::link
	struct wlr_output_cursor *hardware_cursor;
	int software_cursor_locks; // number of locks forcing software cursors

	// the output position in layout space reported to clients
//	int32_t lx, ly;

	struct wl_listener display_destroy;

	void *data;

};

]]

local wlroots = ffi.load('../build/libwlroots.so')
local wayland = ffi.load(package.searchpath('wayland-server',package.cpath))

local display = wayland.wl_display_create()
local event_loop = wayland.wl_display_get_event_loop(display)
local backend = wlroots.wlr_backend_autocreate(display, nil)

local outputs = {}

function wl_signal_add(signal, listener)
   wayland.wl_list_insert(signal.listener_list.prev, listener.link)
end

function listen(signal, fn)
   local listener = ffi.new("struct wl_listener")
   listener.notify = fn
   wl_signal_add(signal, listener)
   return listener
end

new_output_listener = listen(backend.events.new_output,
			     function(listener, data)
   output = ffi.cast("struct wlr_output *", data)
   print("new output", listener, output,
	 wayland.wl_list_empty(output.modes))
   if not wayland.wl_list_empty(output.modes) then
      -- required for drm and other fullscreen backends
      print("XXX should set mode")
   end
   op = 
      { last_frame = os.clock(),
	destroy_listener = listen(
	   output.events.destroy, function(l, data)
	      print("must clean up output", data)
	end),
	output = output }
   outputs[#outputs + 1] = op
   print(inspect(outputs))
end)

wlroots.wlr_backend_start(backend)
wayland.wl_display_run(display);
wayland.wl_display_destroy(display);
return 0

