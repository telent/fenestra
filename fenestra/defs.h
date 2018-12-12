#include <time.h>

enum clocks {
	     clock_realtime = CLOCK_REALTIME,
	     clock_monotonic = CLOCK_MONOTONIC,
	     clock_process_cputime = CLOCK_PROCESS_CPUTIME_ID,
	     clock_thread_cputime = CLOCK_THREAD_CPUTIME_ID
};

struct wl_display { void *p; };
struct wl_event_loop * wl_display_get_event_loop(struct wl_display *);
struct wl_display *wl_display_create(void);
char * wl_display_add_socket_auto(struct wl_display *);
struct wlr_renderer { void *p; };
typedef struct wlr_renderer *(*wlr_renderer_create_func_t)();
struct wlr_backend *wlr_backend_autocreate(struct wl_display *display,
		wlr_renderer_create_func_t create_renderer_func);
void wl_display_run(struct wl_display *display);
void wl_display_destroy(struct wl_display *display);
int wlr_backend_start(struct wlr_backend *backend);
struct wlr_renderer *wlr_backend_get_renderer(struct wlr_backend *backend);
bool wlr_output_make_current(struct wlr_output *output, int *buffer_age) ;

void wlr_renderer_begin(struct wlr_renderer *r, int width, int height);
void wlr_renderer_end(struct wlr_renderer *r);
void wlr_renderer_clear(struct wlr_renderer *r,
			const float color[]);
struct wl_list {
        struct wl_list *prev;
        struct wl_list *next;
}; 

void wl_list_insert(struct wl_list *list, struct wl_list *elm );
bool wl_list_empty (const struct wl_list *list);

/* 
#include <stddef.h>
enum list_offsets { seventeen = offsetof(struct wl_list, next); };
*/

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

bool wlr_output_swap_buffers(struct wlr_output *output,
			     struct timespec *when,
			     pixman_region32_t *damage);


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

struct wlr_output_mode {
        uint32_t flags; // enum wl_output_mode
        int32_t width, height;
        int32_t refresh; // mHz
        struct wl_list link;
};

bool wlr_output_set_mode(struct wlr_output *output,
			 struct wlr_output_mode *mode) ;

int putenv(const char *);

struct wlr_gamma_control_manager *wlr_gamma_control_manager_create(struct wl_display *display) ;
struct wlr_idle *wlr_idle_create(struct wl_display *display) ;
int wl_display_init_shm(struct wl_display *display) ;

void wlr_output_create_global(struct wlr_output *output) ;

struct wlr_subcompositor {
	struct wl_global *global;
	struct wl_list resources;
	struct wl_list subsurface_resources;
};

struct wlr_compositor {
	struct wl_global *global;
	struct wl_list resources;
	struct wlr_renderer *renderer;
	struct wl_list surface_resources;
	struct wl_list region_resources;

	struct wlr_subcompositor subcompositor;

	struct wl_listener display_destroy;

	struct {
		struct wl_signal new_surface;
		struct wl_signal destroy;
	} events;
};

struct wlr_compositor *wlr_compositor_create(struct wl_display *display,
					     struct wlr_renderer *renderer);
struct wlr_renderer *wlr_backend_get_renderer(struct wlr_backend *backend);
struct wlr_xdg_shell_v6 *wlr_xdg_shell_v6_create(struct wl_display *display);

struct wlr_xdg_shell *wlr_xdg_shell_create(struct wl_display *display);

struct wl_resource* wl_resource_from_link(struct wl_list *);
struct wlr_surface *wlr_surface_from_resource(struct wl_resource *);

// << _DEBUGGING_USE_ONLY we only added these to help gdb
void sync(void *);
typedef void(* wl_resource_destroy_func_t) (struct wl_resource *resource);
struct wl_object {
  const struct wl_interface *interface;
  const void *implementation;
  uint32_t id;
};
struct wl_resource {
  struct wl_object object;
  wl_resource_destroy_func_t destroy;
  struct wl_list link;
  struct wl_signal destroy_signal;
  struct wl_client *client;
  void *data;
};

// _DEBUGGING_USE_ONLY

struct wlr_surface_state {
	uint32_t committed; // enum wlr_surface_state_field

	struct wl_resource *buffer_resource;
	int32_t dx, dy; // relative to previous position
	pixman_region32_t surface_damage, buffer_damage; // clipped to bounds
	pixman_region32_t opaque, input;
	enum wl_output_transform transform;
	int32_t scale;
	struct wl_list frame_callback_list; // wl_resource

	int width, height; // in surface-local coordinates
	int buffer_width, buffer_height;

	struct wl_listener buffer_destroy;
};


struct wlr_surface {
	struct wl_resource *resource;
	struct wlr_renderer *renderer;
	/**
	 * The surface's buffer, if any. A surface has an attached buffer when it
	 * commits with a non-null buffer in its pending state. A surface will not
	 * have a buffer if it has never committed one, has committed a null buffer,
	 * or something went wrong with uploading the buffer.
	 */
	struct wlr_buffer *buffer;
	/**
	 * The buffer position, in surface-local units.
	 */
	int sx, sy;
	/**
	 * The last commit's buffer damage, in buffer-local coordinates. This
	 * contains both the damage accumulated by the client via
	 * `wlr_surface_state.surface_damage` and `wlr_surface_state.buffer_damage`.
	 * If the buffer has been resized, the whole buffer is damaged.
	 *
	 * This region needs to be scaled and transformed into output coordinates,
	 * just like the buffer's texture. In addition, if the buffer has shrunk the
	 * old size needs to be damaged and if the buffer has moved the old and new
	 * positions need to be damaged.
	 */
	pixman_region32_t buffer_damage;
	/**
	 * The current opaque region, in surface-local coordinates. It is clipped to
	 * the surface bounds. If the surface's buffer is using a fully opaque
	 * format, this is set to the whole surface.
	 */
	pixman_region32_t opaque_region;
	/**
	 * The current input region, in surface-local coordinates. It is clipped to
	 * the surface bounds.
	 */
	pixman_region32_t input_region;
	/**
	 * `current` contains the current, committed surface state. `pending`
	 * accumulates state changes from the client between commits and shouldn't
	 * be accessed by the compositor directly. `previous` contains the state of
	 * the previous commit.
	 */
	struct wlr_surface_state current, pending, previous;

	const struct wlr_surface_role *role; // the lifetime-bound role or NULL
	void *role_data; // role-specific data

	struct {
		struct wl_signal commit;
		struct wl_signal new_subsurface;
		struct wl_signal destroy;
	} events;

	struct wl_list subsurfaces; // wlr_subsurface::parent_link

	// wlr_subsurface::parent_pending_link
	struct wl_list subsurface_pending_list;

	struct wl_listener renderer_destroy;

	void *data;
};

struct wlr_subsurface_state {
	int32_t x, y;
};
bool wlr_surface_has_buffer(struct wlr_surface *surface);

struct wlr_box {
	int x, y;
	int width, height;
};

void wlr_matrix_project_box(float mat[9], const struct wlr_box *box,
			    //enum wl_output_transform transform,
			    int transform,
			    float rotation,
			    const float projection[9]);

bool wlr_render_texture_with_matrix(struct wlr_renderer *r,
			    struct wlr_texture *texture,
			    const float *matrix, float alpha);

void wlr_surface_send_frame_done(struct wlr_surface *surface,
				 const struct timespec *when);
struct wlr_texture *wlr_surface_get_texture(struct wlr_surface *surface);

int clock_gettime(int clk_id, struct timespec *tp);

int getpid();

enum wlr_button_state {
	WLR_BUTTON_RELEASED,
	WLR_BUTTON_PRESSED,
};

enum wlr_input_device_type {
	WLR_INPUT_DEVICE_KEYBOARD,
	WLR_INPUT_DEVICE_POINTER,
	WLR_INPUT_DEVICE_TOUCH,
	WLR_INPUT_DEVICE_TABLET_TOOL,
	WLR_INPUT_DEVICE_TABLET_PAD,
};
typedef uint32_t 	xkb_led_index_t;
typedef uint32_t 	xkb_mod_index_t;
typedef uint32_t 	xkb_mod_mask_t;

#define WLR_LED_COUNT 3
#define WLR_MODIFIER_COUNT 8

#define WLR_KEYBOARD_KEYS_CAP 32

struct wlr_keyboard_modifiers {
	xkb_mod_mask_t depressed;
	xkb_mod_mask_t latched;
	xkb_mod_mask_t locked;
	xkb_mod_mask_t group;
};

struct wlr_keyboard {
	const struct wlr_keyboard_impl *impl;

	char *keymap_string;
	size_t keymap_size;
	struct xkb_keymap *keymap;
	struct xkb_state *xkb_state;
	xkb_led_index_t led_indexes[WLR_LED_COUNT];
	xkb_mod_index_t mod_indexes[WLR_MODIFIER_COUNT];
  
	uint32_t keycodes[WLR_KEYBOARD_KEYS_CAP];
	size_t num_keycodes;
	struct wlr_keyboard_modifiers modifiers;

	struct {
		int32_t rate;
		int32_t delay;
	} repeat_info;

	struct {
		/**
		 * The `key` event signals with a `wlr_event_keyboard_key` event that a
		 * key has been pressed or released on the keyboard. This event is
		 * emitted before the xkb state of the keyboard has been updated
		 * (including modifiers).
		 */
		struct wl_signal key;

		/**
		 * The `modifiers` event signals that the modifier state of the
		 * `wlr_keyboard` has been updated. At this time, you can read the
		 * modifier state of the `wlr_keyboard` and handle the updated state by
		 * sending it to clients.
		 */
		struct wl_signal modifiers;
		struct wl_signal keymap;
		struct wl_signal repeat_info;
	} events;

	void *data;
};

enum wlr_key_state {
	WLR_KEY_RELEASED,
	WLR_KEY_PRESSED,
};

struct wlr_event_keyboard_key {
	uint32_t time_msec;
	uint32_t keycode;
	bool update_state; // if backend doesn't update modifiers on its own
	enum wlr_key_state state;
};

struct wlr_input_device {
	const struct wlr_input_device_impl *impl;

	enum wlr_input_device_type type;
	unsigned int vendor, product;
	char *name;
	// Or 0 if not applicable to this device
	double width_mm, height_mm;
	char *output_name;

	/* wlr_input_device.type determines which of these is valid */
	union {
		void *_device;
		struct wlr_keyboard *keyboard;
		struct wlr_pointer *pointer;
		struct wlr_touch *touch;
		struct wlr_tablet *tablet;
		struct wlr_tablet_pad *tablet_pad;
	};

	struct {
		struct wl_signal destroy;
	} events;

	void *data;

	struct wl_list link;
};


void wlr_log_init(int, void *);

#include <xkbcommon/xkbcommon.h>

void wlr_keyboard_set_keymap(struct wlr_keyboard *kb,
			     struct xkb_keymap *keymap);



struct wlr_seat *wlr_seat_create(struct wl_display *display, const char *name);

void wlr_seat_set_keyboard(struct wlr_seat *seat,
			   struct wlr_input_device *device);

struct wlr_xdg_shell_v6 {
	struct wl_global *global;
	struct wl_list clients;
	struct wl_list popup_grabs;
	uint32_t ping_timeout;

	struct wl_listener display_destroy;

	struct {
		/**
		 * The `new_surface` event signals that a client has requested to
		 * create a new shell surface. At this point, the surface is ready to
		 * be configured but is not mapped or ready receive input events. The
		 * surface will be ready to be managed on the `map` event.
		 */
		struct wl_signal new_surface;
		struct wl_signal destroy;
	} events;

	void *data;
};

void wlr_seat_keyboard_notify_enter(struct wlr_seat *seat,
				    struct wlr_surface *surface,
				    uint32_t keycodes[], size_t num_keycodes,
				    struct wlr_keyboard_modifiers *modifiers);

struct wlr_xdg_shell {
	struct wl_global *global;
	struct wl_list clients;
	struct wl_list popup_grabs;
	uint32_t ping_timeout;

	struct wl_listener display_destroy;

	struct {
		/**
		 * The `new_surface` event signals that a client has requested to
		 * create a new shell surface. At this point, the surface is ready to
		 * be configured but is not mapped or ready receive input events. The
		 * surface will be ready to be managed on the `map` event.
		 */
		struct wl_signal new_surface;
		struct wl_signal destroy;
	} events;

	void *data;
};

enum wlr_xdg_surface_v6_role {
	WLR_XDG_SURFACE_V6_ROLE_NONE,
	WLR_XDG_SURFACE_V6_ROLE_TOPLEVEL,
	WLR_XDG_SURFACE_V6_ROLE_POPUP,
};

struct wlr_xdg_surface_v6 {
	struct wlr_xdg_client_v6 *client;
	struct wl_resource *resource;
	struct wlr_surface *surface;
	struct wl_list link; // wlr_xdg_client_v6::surfaces
	enum wlr_xdg_surface_v6_role role;

	union {
		struct wlr_xdg_toplevel_v6 *toplevel;
		struct wlr_xdg_popup_v6 *popup;
	};

	struct wl_list popups; // wlr_xdg_popup_v6::link

	bool added, configured, mapped;
	uint32_t configure_serial;
	struct wl_event_source *configure_idle;
	uint32_t configure_next_serial;
	struct wl_list configure_list;

	bool has_next_geometry;
	struct wlr_box next_geometry;
	struct wlr_box geometry;

	struct wl_listener surface_destroy;
	struct wl_listener surface_commit;

	struct {
		struct wl_signal destroy;
		struct wl_signal ping_timeout;
		struct wl_signal new_popup;
		/**
		 * The `map` event signals that the shell surface is ready to be
		 * managed by the compositor and rendered on the screen. At this point,
		 * the surface has configured its properties, has had the opportunity
		 * to bind to the seat to receive input events, and has a buffer that
		 * is ready to be rendered. You can now safely add this surface to a
		 * list of views.
		 */
		struct wl_signal map;
		/**
		 * The `unmap` event signals that the surface is no longer in a state
		 * where it should be shown on the screen. This might happen if the
		 * surface no longer has a displayable buffer because either the
		 * surface has been hidden or is about to be destroyed.
		 */
		struct wl_signal unmap;
	} events;

	void *data;
};
void wlr_seat_keyboard_notify_key(struct wlr_seat *seat, uint32_t time,
				  uint32_t key, uint32_t state);

void wlr_seat_set_capabilities(struct wlr_seat *wlr_seat,
			       uint32_t capabilities);

enum wl_seat_capability {
			 WL_SEAT_CAPABILITY_POINTER = 1,
			 WL_SEAT_CAPABILITY_KEYBOARD = 2,
			 WL_SEAT_CAPABILITY_TOUCH = 4
};


