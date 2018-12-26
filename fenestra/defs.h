#define WLR_USE_UNSTABLE 1
#define __float128 long double
#define _Float128 long double
#include <time.h>
#include <quadmath.h>
#include <wlr/types/wlr_pointer.h>
#include <wlr/types/wlr_cursor.h>
#include <wlr/types/wlr_surface.h>
#include <wlr/types/wlr_xcursor_manager.h>
#include <wlr/xcursor.h>

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

void wl_list_insert(struct wl_list *list, struct wl_list *elm );
bool wl_list_empty (const struct wl_list *list);

static inline void
wl_signal_add(struct wl_signal *signal, struct wl_listener *listener)
{
         wl_list_insert(signal->listener_list.prev, &listener->link);
}
typedef void(* wl_notify_func_t) (struct wl_listener *listener, void *data);

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

typedef struct pixman_box32             pixman_box32_t;
typedef struct pixman_region32          pixman_region32_t;



bool wlr_output_swap_buffers(struct wlr_output *output,
			     struct timespec *when,
			     pixman_region32_t *damage);


typedef int int32_t;



bool wlr_output_set_mode(struct wlr_output *output,
			 struct wlr_output_mode *mode) ;

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


bool wlr_surface_has_buffer(struct wlr_surface *surface);


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

typedef uint32_t 	xkb_led_index_t;
typedef uint32_t 	xkb_mod_index_t;
typedef uint32_t 	xkb_mod_mask_t;

#define WLR_LED_COUNT 3
#define WLR_MODIFIER_COUNT 8

#define WLR_KEYBOARD_KEYS_CAP 32

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
void wlr_seat_keyboard_notify_modifiers(struct wlr_seat *,
					struct wlr_keyboard_modifiers *);
void wlr_seat_set_capabilities(struct wlr_seat *wlr_seat,
			       uint32_t capabilities);
