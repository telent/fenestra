-- this is a cut-paste-translate job from
-- https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html

inspect = dofile(string.gsub(os.getenv("LUA_INSPECT"), '/.lua$/', '')).inspect

local ffi = require("ffi")
local io = require("io")
ffi.cdef(io.open("fenestra/defs.h.out","r"):read("a*"))


local wlroots = ffi.load('build/libwlroots.so')
local wayland = ffi.load(package.searchpath('wayland-server',package.cpath))

local display = wayland.wl_display_create()
local event_loop = wayland.wl_display_get_event_loop(display)
local backend = wlroots.wlr_backend_autocreate(display, nil)


local compositor = wlroots.wlr_compositor_create(display,
						 wlroots.wlr_backend_get_renderer(backend));

local outputs = {}

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

--[[
   color = ffi.new("float[4]", {1.0, 0, 0, 1.0})
   wlroots.wlr_renderer_clear(renderer, color)
]]--

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
      -- required for drm and other fullscreen backends
      print("XXX should set mode")
   end
   wlroots.wlr_output_create_global(output)
   return {
      last_frame = os.clock(),
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

new_output_listener = listen(
   backend.events.new_output,
   function(listener, data)
      local o = new_output(ffi.cast("struct wlr_output *", data))
      outputs[#outputs + 1] = o
      print(inspect(outputs))
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

