;; -*- fennel -*- mode

(local ffi (require "ffi"))
(local io  (require "io"))

(let [f (io.open "defs.h.out" "r")]
  (ffi.cdef (f.read f "*all")))

(fn from-cpath [name]
  (package.searchpath name package.cpath))

(local wlroots (ffi.load (from-cpath "wlroots")))
(local wayland (ffi.load (from-cpath "wayland-server")))
(local view (require "fennelview"))
(global pp (fn [x] (print (view x))))

(wlroots.wlr_log_init 3 nil)

(fn write-pid []
  (let [f (io.open "/tmp/fenestra.pid" "w")
        pid (ffi.C.getpid)]
    (f.write f pid)))

;; (write-pid)

(fn wl-add-listener [signal func]
  (let [listener (ffi.new "struct wl_listener")]
    (set listener.notify (lambda [l d]
                           ;; close over listener to stop it being GCed
                           (func listener d)))
    (wayland.wl_list_insert signal.listener_list.prev listener.link)
    listener))



;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; we are going to do a "flowing data" architecture, loosely inspired
;;; by re-frame

;;; There is application state.  It is acted on by an effect handler
;;; which is told what to do by effects, which are data items conputed
;;; by event handlers.  Event handlers run when something dispatches
;;; the events they're registered to handle. "Something" is probably a
;;; callback registered with/by the platform code (i.e. wlroots or wayland)

;;; Every frame, the scene is rendered by looking at the application state
;;; to see which surfaces it needs to draw

;;; re-frame concepts that I might not yet need
;;; - effect handlers for any effect other than "change app state",
;;;   will add these when they torun out to be relevant
;;; - view functions: right now, the frame renderer will look at app state
;;;   directly

;;; other things I have not addressed in this design
;;; - recognising "commands" from low-level input events (e.g. where should
;;;   we put code to recognise that the user is doing a horizontal drag and
;;;   wants[*] to maximise the window

;;; [*] for the record, personally I hate this behaviour and do not
;;; want it on my computer.  But KDE is an existence proof that (more
;;; than zero) other people do like it, and fenestra should be able to
;;; encode it (and other less awful but equally complex gestures
;;; involving state machines) in a non-hacky way

(lambda merge [old-value new-value]
  (each [k v (pairs new-value)]
    (tset old-value k v))
  old-value)

(fn conj [coll v]
  (table.insert coll v)
  coll)

(var handlers {})

(lambda listen [name handler] 
  (tset handlers
        name
        (conj (or (. handlers name) []) handler)))

(var app-state {})

(lambda dispatch [name value]
  (let [fns (. handlers name)]
    (when fns
      (each [_ f (ipairs fns)]
        (let [new-value (f value app-state)]
          (pp new-value)
          (set app-state (merge app-state new-value)))))))


(fn new-backend [display]
  (let [be (wlroots.wlr_backend_autocreate display nil)]
    (wl-add-listener
     be.events.new_output
     (fn [_ data]
       (dispatch :new-output (ffi.cast "struct wlr_output *" data))))
    be))

(fn initial-state []
  (let [d (wayland.wl_display_create)]
    {:display d
     :layout (wlroots.wlr_output_layout_create)
     :socket (ffi.string (wayland.wl_display_add_socket_auto d))
     :backend (new-backend d)}))

(listen :light-blue-touchpaper
        (fn [event state]
          (pp state)
          (let [d state.display]
            (wayland.wl_display_init_shm d)
            ;;(wlroots.wlr_gamma_control_manager_create d)
            ;; wlroots.wlr_screenshooter_create(display);
            ;;- wlroots.wlr_primary_selection_device_manager_create(display);
            (wlroots.wlr_idle_create d)
            {:shell (wlroots.wlr_xdg_shell_create d)
             :seats {:hotseat (wlroots.wlr_seat_create d "hotseat")}})))

(listen :new-output
        (fn [event state]
          (print "new output")
          (pp state)
          (pp event)
          {:outputs (conj (or state.outputs []) event)}
          ))

(set app-state (initial-state))
(dispatch :light-blue-touchpaper {})
(wlroots.wlr_backend_start app-state.backend)
(wayland.wl_display_run app-state.display)
