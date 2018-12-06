-- this is a cut-paste-translate job from
-- https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html

inspect = dofile(string.gsub(os.getenv("LUA_INSPECT"), '/.lua$/', '')).inspect

local ffi = require("ffi")
local io = require("io")
ffi.cdef(io.open("fenestra/defs.c","r"):read("a*"))

local wlroots = ffi.load('build/libwlroots.so')
local wayland = ffi.load(package.searchpath('wayland-server',package.cpath))

local display = wayland.wl_display_create()
local event_loop = wayland.wl_display_get_event_loop(display)
local backend = wlroots.wlr_backend_autocreate(display, nil)

local outputs = {}

function listen(signal, fn)
   local listener = ffi.new("struct wl_listener")
   listener.notify = fn
   wayland.wl_list_insert(signal.listener_list.prev, listener.link)
   return listener
end

function render_frame(renderer, output)
   wlroots.wlr_output_make_current(output, nil)
   wlroots.wlr_renderer_begin(renderer, output.width, output.height)
   color = ffi.new("float[4]", {1.0, 0, 0, 1.0})
   wlroots.wlr_renderer_clear(renderer, color)
   wlroots.wlr_output_swap_buffers(output, nil, nil)
   wlroots.wlr_renderer_end(renderer)
end

function new_output(output)
   print("new output", output.width,  output.height)
   if not wayland.wl_list_empty(output.modes) then
      -- required for drm and other fullscreen backends
      print("XXX should set mode")
   end
   
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
		   render_frame(renderer, output)
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

wlroots.wlr_backend_start(backend)
wayland.wl_display_run(display);
wayland.wl_display_destroy(display);
return 0

