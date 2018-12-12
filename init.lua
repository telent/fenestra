-- this is a cut-paste-translate job from
-- https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html

inspect = dofile(string.gsub(os.getenv("LUA_INSPECT"), '/.lua$/', '')).inspect

local ffi = require("ffi")
local io = require("io")
ffi.cdef(io.open("fenestra/defs.h.out","r"):read("a*"))

io.open("/tmp/fenestra.pid","w"):write(ffi.C.getpid())

local wlroots = ffi.load('build/libwlroots.so')
local wayland = ffi.load(package.searchpath('wayland-server',package.cpath))
local xkbcommon = ffi.load(package.searchpath('xkbcommon',package.cpath))

local display = wayland.wl_display_create()
local event_loop = wayland.wl_display_get_event_loop(display)
local backend = wlroots.wlr_backend_autocreate(display, nil)

local compositor = wlroots.wlr_compositor_create(
   display,
   wlroots.wlr_backend_get_renderer(backend));

wlroots.wlr_log_init(3, nil)

function listen(signal, fn)
   local listener = ffi.new("struct wl_listener")
   listener.notify = fn
   wayland.wl_list_insert(signal.listener_list.prev, listener.link)
   return listener
end

function render_surface(renderer, surface, output)
   if wlroots.wlr_surface_has_buffer(surface) then
      box=ffi.new("struct wlr_box", {
		     x = 20, y = 20,
		     width = surface.current.width,
		     height = surface.current.height
      })
      matrix = ffi.new("float[16]");
      wlroots.wlr_matrix_project_box(matrix, box,
				     surface.current.transform,
				     0,
				     output.transform_matrix)
      local texture = wlroots.wlr_surface_get_texture(surface)
      wlroots.wlr_render_texture_with_matrix(renderer,
					     texture,
					     matrix,
					     1.0);
      local now = ffi.new("struct timespec")
      ffi.C.clock_gettime(ffi.C.clock_monotonic, now)
      wlroots.wlr_surface_send_frame_done(surface, now);
   end
end

function render_frame(renderer, compositor, output)
   wlroots.wlr_output_make_current(output, nil)
   wlroots.wlr_renderer_begin(renderer, output.width, output.height)

   local head = compositor.surface_resources
   local el = head.next
   while el ~= head do
      local resource =  wayland.wl_resource_from_link(el)
      render_surface(renderer,
		     wlroots.wlr_surface_from_resource(resource),
		     output)
      el = el.next
   end

   wlroots.wlr_output_swap_buffers(output, nil, nil)
   wlroots.wlr_renderer_end(renderer)

end

function new_output(output)
   print("new output", output.width,  output.height)
   if not wayland.wl_list_empty(output.modes) then
      -- required for drm and (presumably) other fullscreen backends
      local link_p = ffi.cast('unsigned char *', output.modes.prev)
      local offset = ffi.offsetof("struct wlr_output_mode","link")
      mode = ffi.cast('struct wlr_output_mode *', (link_p - offset))
      print("setting mode ",mode.width, mode.height)
      wlroots.wlr_output_set_mode(output, mode);
   end

   wlroots.wlr_output_create_global(output)
   local ts = ffi.new("struct timespec");
   ffi.C.clock_gettime(ffi.C.clock_monotonic, ts)
   return {
      last_frame = ts,
      destroy_listener = listen(
	 output.events.destroy, function(l, data)
	    print("must clean up output", data)
      end),
      frame_listener =
	 listen(output.events.frame, function(l, data)
		   local renderer =
		      wlroots.wlr_backend_get_renderer(backend)
		   render_frame(renderer, compositor, output)
	 end),
      output = output
   }
end

local outputs = {}

local new_output_listener = listen(
   backend.events.new_output,
   function(listener, data)
      local o = new_output(ffi.cast("struct wlr_output *", data))
      outputs[#outputs + 1] = o
      print(inspect(outputs))
end)

function handle_key(listener, data)
   local event = ffi.cast("struct wlr_event_keyboard_key *", data);
   print("key", event.time_msec, event.keycode,
	 event.state, event.update_state);
end
function handle_keymap(listener, data)
   print("keymap")
end

function set_default_keymap(keyboard)
   rules = ffi.new("struct xkb_rule_names", {})
   -- rules.rules = getenv("XKB_DEFAULT_RULES");
   -- rules.model = getenv("XKB_DEFAULT_MODEL");
   -- rules.layout = getenv("XKB_DEFAULT_LAYOUT");
   -- rules.variant = getenv("XKB_DEFAULT_VARIANT");
   -- rules.options = getenv("XKB_DEFAULT_OPTIONS");

   local context = xkbcommon.xkb_context_new(0);
   if not context then
      print("Failed to create XKB context")
      return false
   end

   local keymap = xkbcommon.xkb_keymap_new_from_names(context, rules, 0)

   if not keymap then
      print("Failed to create XKB keymap")
      return false
   end

   wlroots.wlr_keyboard_set_keymap(keyboard, keymap);
   xkbcommon.xkb_keymap_unref(keymap);
   xkbcommon.xkb_context_unref(context);
end


function new_keyboard(device)
   local keyboard = device.keyboard
   print("keyboard", keyboard,
	 keyboard.keymap_string,
	 keyboard.keymap_size,
	 keyboard.num_keycodes   )
   local key_listener = listen(keyboard.events.key, handle_key)
   local keymap_listener = listen(keyboard.events.keymap, handle_keymap)
   set_default_keymap(keyboard)
   return {
      type = 'keyboard',
      key_listener = key_listener,
      keymap_listener =  keymap_listener,
   }
end
function new_pointer(d)
   print("pointer", d)
   return {
      type = 'pointer'
   }
end

input_types = {
   [ffi.C.WLR_INPUT_DEVICE_KEYBOARD] = new_keyboard,
   [ffi.C.WLR_INPUT_DEVICE_POINTER] = new_pointer,
};

function new_input(input)
   print("new input", input)
   local f = input_types[tonumber(input.type)]
   local p = f(input)
   return p
end

local inputs = {}

local new_input_listener = listen(
   backend.events.new_input,
   function(listener, data)
      local device = new_input(ffi.cast("struct wlr_input_device *", data))
      inputs[device.type] = device
      print(inspect(inputs))
end)

local socket = ffi.string(wayland.wl_display_add_socket_auto(display))

print("Running compositor on wayland display ", socket);
ffi.C.putenv("WAYLAND_DISPLAY=".. socket)

wayland.wl_display_init_shm(display);
wlroots.wlr_gamma_control_manager_create(display);
-- wlroots.wlr_screenshooter_create(display);
-- wlroots.wlr_primary_selection_device_manager_create(display);
wlroots.wlr_idle_create(display);

wlroots.wlr_xdg_shell_v6_create(display);

wlroots.wlr_backend_start(backend)
wayland.wl_display_run(display);

wayland.wl_display_destroy(display);
return 0

