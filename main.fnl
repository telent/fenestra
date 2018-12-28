(print "hello world")

(local ffi (require "ffi"))
(local io  (require "io"))

(let [f (io.open "defs.h.out" "r")]
  (ffi.cdef (f.read f "*all")))

(print ffi.C.WL_SEAT_CAPABILITY_KEYBOARD)

(fn write-pid []
  (let [f (io.open "/tmp/fenestra.pid" "w")
        pid (ffi.C.getpid)]
    (f.write f pid)))

(write-pid)
