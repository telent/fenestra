;; -*- fennel -*- mode

(local ffi (require "ffi"))
(local io  (require "io"))

(let [f (io.open "defs.h.out" "r")]
  (ffi.cdef (f.read f "*all")))

(fn from-cpath [name]
  (package.searchpath name package.cpath))

(local wlroots (ffi.load (from-cpath "wlroots")))
(local wayland (ffi.load (from-cpath "wayland-server")))

(wlroots.wlr_log_init 3 nil)

(fn write-pid []
  (let [f (io.open "/tmp/fenestra.pid" "w")
        pid (ffi.C.getpid)]
    (f.write f pid)))

;; (write-pid)

(->  (wayland.wl_display_create)
     (wlroots.wlr_backend_autocreate nil))
