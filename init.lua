-- this started as a cut-paste-translate job from
-- https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html

-- but it also cribs bits from rootston

local ffi = require("ffi")
local io = require("io")

-- helpful stuff for debugging [
inspect = dofile(string.gsub(os.getenv("LUA_INSPECT"), '/.lua$/', '')).inspect
local dbg = require("debugger")
reflect = require("ffi_reflect")

function tabulate(s) 
  local t = {}
  for refct in reflect.typeof(s).element_type:members() do
     if refct.name then
	t[refct.name] = s[refct.name]
     end
  end
  return t
end

function pp(o)
   print(inspect(tabulate(o)))
end
-- ] end of debug helper code


ffi.cdef(io.open("fenestra/defs.h.out","r"):read("a*"))

io.open("/tmp/fenestra.pid","w"):write(ffi.C.getpid())

local wlroots = ffi.load('build/libwlroots.so')
wlroots.wlr_log_init(3, nil)

local wayland = ffi.load(package.searchpath('wayland-server',package.cpath))
local xkbcommon = ffi.load(package.searchpath('xkbcommon',package.cpath))

local display = wayland.wl_display_create()

local THEME = 'default' -- 'breeze_cursors'

xcursor_manager = wlroots.wlr_xcursor_manager_create(THEME, 24) -- ROOTS_XCURSOR_SIZE==24

function listen(signal, fn)
   local listener = ffi.new("struct wl_listener")
   listener.notify = function (l, d)
      -- close over listener to stop it being GCed
      fn(listener, d)
   end
   wayland.wl_list_insert(signal.listener_list.prev, listener.link)
   return listener
end

function new_cursor(layout)
   local cursor = wlroots.wlr_cursor_create()
   wlroots.wlr_cursor_attach_output_layout(cursor, layout)
   listen(cursor.events.motion_absolute,
	  function(l,d)
	     local e = ffi.cast("struct wlr_event_pointer_motion_absolute *",d)
	     -- x & y range from 0.0 to 1.0, or thereabouts
	     wlroots.wlr_cursor_warp_absolute(cursor, e.device, e.x, e.y)
	     print("motion absolute", e.x, e.y)
   end)
   listen(cursor.events.motion,
	  function(l,d)
	     local e = ffi.cast("struct wlr_event_pointer_motion *",d)
	     wlroots.wlr_cursor_move(cursor, e.device, e.delta_x, e.delta_y)

	     print("motion", e.delta_x, e.delta_y)
   end)
   listen(cursor.events.button, function(l,d)
	     local e = ffi.cast("struct wlr_event_pointer_button *",d)
	     print("button", e.button, e.state)
   end)
   listen(cursor.events.axis, function(l,d)
	     local e = ffi.cast("struct wlr_event_pointer_axis *",d)
	     print("axis", e.orientation, e.delta, e.delta_discrete)
   end)
   return {
      wlr_cursor = cursor 
   }
end

local outputs = {
   wlr_output_layout = wlroots.wlr_output_layout_create()
}

-- for the moment we have one seat only
local comfy_chair = {
   inputs = {},
   cursor = new_cursor(outputs.wlr_output_layout),
}
local event_loop = wayland.wl_display_get_event_loop(display)
local backend = wlroots.wlr_backend_autocreate(display, nil)

local compositor = wlroots.wlr_compositor_create(
   display,
   wlroots.wlr_backend_get_renderer(backend));


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

local BLACK = ffi.new("float[4]", {0.0, 0, 0, 1.0})

function render_frame(renderer, compositor, output)
   wlroots.wlr_output_make_current(output, nil)
   wlroots.wlr_renderer_begin(renderer, output.width, output.height)
   wlroots.wlr_renderer_clear(renderer, BLACK)

   local head = compositor.surface_resources
   local el = head.next
   while el ~= head do
      local resource =  wayland.wl_resource_from_link(el)
      local surface = wlroots.wlr_surface_from_resource(resource)
      render_surface(renderer, surface, output)
      el = el.next
   end
   wlroots.wlr_output_render_software_cursors(output, nil);
   wlroots.wlr_output_swap_buffers(output, nil, nil)
   wlroots.wlr_renderer_end(renderer)

end

function new_output(layout, output)
   print("new output", output.width,  output.height, output.scale)
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

   wlroots.wlr_output_layout_add_auto(layout, output)
   
   -- xcursor manager is a per-scale thing not a per-output
   -- thing and doesn't really belong here
   if wlroots.wlr_xcursor_manager_load(xcursor_manager, output.scale) > 0 then
      print("can't load xcursor theme for scale", output.scale)
   end
   local cr = comfy_chair.cursor
   wlroots.wlr_xcursor_manager_set_cursor_image(xcursor_manager,
						"left_ptr",
						cr.wlr_cursor);

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


local new_output_listener = listen(
   backend.events.new_output,
   function(listener, data)
      local o = new_output(outputs.wlr_output_layout,
			   ffi.cast("struct wlr_output *", data))
      outputs[#outputs + 1] = o
end)

function focus_surface_for_keys(seat, surface)
   local k = seat.inputs.keyboard
   if k then
      local wk = k.wlr_keyboard
      print("notify enter")
      wlroots.wlr_seat_keyboard_notify_enter(seat.wlr_seat,
					     surface,
					     wk.keycodes,
					     wk.num_keycodes,
					     wk.modifiers);
   end
end


function handle_key(listener, data)
   local event = ffi.cast("struct wlr_event_keyboard_key *", data);
   print("key", event.time_msec, event.keycode,
	 event.state, event.update_state);
   if comfy_chair.wlr_seat then
      wlroots.wlr_seat_keyboard_notify_key(comfy_chair.wlr_seat,
					   event.time_msec,
					   event.keycode,
					   event.state);
   end
end

function handle_keymap(listener, data)
   print("keymap")
end

function send_key_modifiers(seat, keyboard)
   wlroots.wlr_seat_keyboard_notify_modifiers(seat, keyboard.modifiers)
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


function new_keyboard(seat, device)
   local keyboard = device.keyboard
   print("keyboard", keyboard,
	 keyboard.keymap_string,
	 keyboard.keymap_size,
	 keyboard.num_keycodes   )
   local key_listener = listen(keyboard.events.key, handle_key)
   local keymap_listener = listen(keyboard.events.keymap, handle_keymap)
   local modifiers_listener = listen(keyboard.events.modifiers,
				     function(l,d)
					send_key_modifiers(seat.wlr_seat, keyboard)
   end)
   set_default_keymap(keyboard)
   wlroots.wlr_seat_set_keyboard(seat.wlr_seat, device)
   wlroots.wlr_seat_set_capabilities(seat.wlr_seat, ffi.C.WL_SEAT_CAPABILITY_KEYBOARD);
 				     
   return {
      type = 'keyboard',
      wlr_keyboard = keyboard,
      key_listener = key_listener,
      keymap_listener =  keymap_listener,
      modifiers_listener = modifiers_listener
   }
end

function update_seat_capabilities(seat)
   local caps = 0
   if seat.inputs.pointer then
      caps = caps + ffi.C.WL_SEAT_CAPABILITY_POINTER
   end
   if seat.inputs.keyboard then
      caps = caps + ffi.C.WL_SEAT_CAPABILITY_KEYBOARD
   end
   print("seat capabilities", caps)
   wlroots.wlr_seat_set_capabilities(seat.wlr_seat, caps)
end

function new_pointer(seat, device)
   local pointer = device.pointer
   print("pointer", pointer)
   wlroots.wlr_cursor_attach_input_device(seat.cursor.wlr_cursor, device)
   return {
      type = 'pointer'
   }
end

input_types = {
   [ffi.C.WLR_INPUT_DEVICE_KEYBOARD] = new_keyboard,
   [ffi.C.WLR_INPUT_DEVICE_POINTER] = new_pointer,
};


function new_input(seat, input)
   print("new input", input)
   local f = input_types[tonumber(input.type)]
   local p = f(seat, input)
   return p
end

local new_input_listener = listen(
   backend.events.new_input,
   function(listener, data)
      local device = new_input(comfy_chair,
			       ffi.cast("struct wlr_input_device *", data))
      comfy_chair.inputs[device.type] = device
      update_seat_capabilities(comfy_chair)
      print(inspect(comfy_chair.inputs))
end)

local socket = ffi.string(wayland.wl_display_add_socket_auto(display))

print("Running compositor on wayland display ", socket);

ffi.C.putenv(ffi.cast("char *", "WAYLAND_DISPLAY=".. socket))

wayland.wl_display_init_shm(display);


wlroots.wlr_gamma_control_manager_create(display);
-- wlroots.wlr_screenshooter_create(display);
-- wlroots.wlr_primary_selection_device_manager_create(display);
wlroots.wlr_idle_create(display);

local xdg_shell = wlroots.wlr_xdg_shell_create(display);
local xdg_shell_v6 = wlroots.wlr_xdg_shell_v6_create(display);
--[[
listen(xdg_shell.events.new_surface, function(l, d)
	  local surface = ffi.cast("struct wlr_xdg_surface *", d)
	  print("new xdg surface", surface)
	  focus_surface_for_keys(comfy_chair, surface.surface)
end)
--]]
listen(xdg_shell_v6.events.new_surface, function(l, d)
	  local surface = ffi.cast("struct wlr_xdg_surface_v6 *", d)
	  print("new v6 surface", surface)
	  focus_surface_for_keys(comfy_chair, surface.surface)
end)


-- this can't be done when comfy_chair is created as it causes
-- weston-terminal to segfault at startup.  Don't ask me why
comfy_chair.wlr_seat = wlroots.wlr_seat_create(display, "comfy_chair")

wlroots.wlr_backend_start(backend)
wayland.wl_display_run(display);

wayland.wl_display_destroy(display);
return 0

