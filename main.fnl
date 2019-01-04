;; -*- fennel -*- mode

(local ffi (require "ffi"))
(local io  (require "io"))
(local math (require "math"))

(let [f (io.open "defs.h.out" "r")]
  (ffi.cdef (f.read f "*all")))

(lambda from-cpath [name]
  (package.searchpath name package.cpath))

(local wlroots (ffi.load (from-cpath "wlroots")))
(local wayland (ffi.load (from-cpath "wayland-server")))
(local fennelview (require "fennelview"))
(global pp (lambda [x] (print (fennelview x))))

(lambda now []
  (let [ts (ffi.new "struct timespec")]
    (ffi.C.clock_gettime ffi.C.clock_monotonic ts)
    ts))


(wlroots.wlr_log_init 3 nil)

(lambda write-pid []
  (let [f (io.open "/tmp/fenestra.pid" "w")
        pid (ffi.C.getpid)]
    (f.write f pid)))

;; (write-pid)

(lambda wl-add-listener [signal func]
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

;; this happens to be destructive but the caller should not depend on it
(lambda merge [old-value new-value]
  (each [k v (pairs new-value)]
    (tset old-value k v))
  old-value)

;; this happens to be destructive but the caller should not depend on it
(lambda conj [coll v]
  (table.insert coll v)
  coll)

(lambda filter [f arr]
  (let [found []]
    (each [_ v (ipairs arr)]
      (if (f v)
          (table.insert found  v)))
    found))

(lambda first [c] (. c 1))

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
          ;; 1. probably we are going to change the handler signature to
          ;; return attribute paths (a la clojure's update-in) instead
          ;; of just top-level attribute keys, which will make it much
          ;; easier for handlers to update deeply nested bits of the
          ;; state without accidentally blatting large sections of
          ;; unrelated state.

          ;; 2. again, this happens to be destructive but the caller
          ;; should not depend on it
          (set app-state (merge app-state new-value))
          (pp app-state)
          app-state
          )))))


(lambda new-backend [display]
  (let [be (wlroots.wlr_backend_autocreate display nil)]
    (wl-add-listener
     be.events.new_output
     (lambda [_ data]
       (dispatch :new-output (ffi.cast "struct wlr_output *" data))))
    be))

(lambda new-compositor [display renderer]
  (let [compositor (wlroots.wlr_compositor_create display renderer)]
    (wl-add-listener
     compositor.events.new_surface
     (lambda [l d]
       (let [wlr_surface (ffi.cast "struct wlr_surface *", d)]
         (dispatch :new-surface wlr_surface))))
    compositor))

(lambda new-xdg-shell [display]
  (let [s (wlroots.wlr_xdg_shell_create display)
        s6 (wlroots.wlr_xdg_shell_v6_create display)]
    (wl-add-listener s.events.new_surface
                     (lambda [l d]
	               (let [xs (ffi.cast "struct wlr_xdg_surface *" d)]
                         (wl-add-listener xs.events.map
                                          (lambda [l d]
                                            (dispatch :map-shell
                                                      xs.surface))))))
    (wl-add-listener s6.events.new_surface
                     (lambda [l d]
	               (let [xs (ffi.cast "struct wlr_xdg_surface_v6 *" d)]
                         (wl-add-listener xs.events.map
                                          (lambda [l d]
                                            (dispatch :map-shell
                                                      xs.surface))))))
    [s s6]))
    


(lambda initial-state []
  (let [display (wayland.wl_display_create)
        backend (new-backend display)]
    {
     :backend backend
     :compositor (new-compositor display (wlroots.wlr_backend_get_renderer backend))
     :display display
     :layout (wlroots.wlr_output_layout_create)
     :socket (ffi.string (wayland.wl_display_add_socket_auto display))
     }))



(listen :light-blue-touchpaper
        (lambda [event state]
          (let [d state.display]
            ;; there is a little more (read: any) side-effecting code
            ;; being called here than I'd like in what is supposed to
            ;; be a purely functional event handler.  We will push it
            ;; into some kind of effect handler just as soon as it
            ;; becomes more obvious *what* kind of effect handler
            (wayland.wl_display_init_shm d)
            ;;(wlroots.wlr_gamma_control_manager_create d)
            ;; wlroots.wlr_screenshooter_create(display);
            ;;- wlroots.wlr_primary_selection_device_manager_create(display);
            (wlroots.wlr_idle_create d)
            {:xdg-shell (new-xdg-shell d)
             :seats {:hotseat (wlroots.wlr_seat_create d "hotseat")}})))

(global colors
        {:red (ffi.new "float[4]", [1.0 0.0 0.0 1.0])
         :black (ffi.new "float[4]", [0.0 0.0 0.0 1.0])})

(lambda render-surface [s output renderer]
  (let [x s.x
        y s.y
        surface s.wlr-surface]
    (when (wlroots.wlr_surface_has_buffer surface)
      (let [box (ffi.new "struct wlr_box"
                         {
		          :x x
                          :y y
		          :width  surface.current.width
		          :height surface.current.height})
            texture (wlroots.wlr_surface_get_texture surface)]
        (wlroots.wlr_matrix_project_box
         s.matrix
         box
	 surface.current.transform
	 s.rotation
	 output.transform_matrix)
        (wlroots.wlr_render_texture_with_matrix
         renderer texture s.matrix 1.0)
        (wlroots.wlr_surface_send_frame_done surface (now))))))

(lambda render-frame [output]
  ;; ideally this wouldn't refer to the global app-state
  (let [backend app-state.backend
        compositor app-state.compositor
        renderer (wlroots.wlr_backend_get_renderer backend)]
    (wlroots.wlr_output_make_current output, nil)
    (wlroots.wlr_renderer_begin renderer, output.width, output.height)
    (wlroots.wlr_renderer_clear renderer colors.black)

    (when app-state.surfaces
      (each [_ s (ipairs app-state.surfaces)]
        (if (and s.x s.y)
            ;; not every surface is a shell, not every shell is mapped
            (render-surface s output renderer))))
    
    (wlroots.wlr_output_swap_buffers output  nil nil)
    (wlroots.wlr_renderer_end renderer)))

(listen :new-output
        (lambda [output state]
          (let [l
                (wl-add-listener
                 output.events.frame
                 (lambda [_ _] (render-frame output)))]
            (wlroots.wlr_output_create_global output)
            {:outputs (conj (or state.outputs [])
                            {:wl-output output :frame-listener l})})))

(listen :new-surface
        (lambda [surface state]
          (print "new surface")
          (let [s {:wlr-surface surface
                   :matrix (ffi.new "float[16]")
                   ;; a new surface may not be a shell, and even if it is we
                   ;; don't know how big to render it (and perhaps therefore
                   ;; where to put it) until it's mapped.
                   :x nil
                   :y nil}]
            {:surfaces (conj (or state.surfaces []) s)})))

(listen :map-shell
        (lambda [wl-surface state]
          (let [shell-surface
                (first (filter (fn [x] (= x.wlr-surface wl-surface))
                               state.surfaces))]
            (print "map " wl-surface)
            ;; cheating. we should return the new leaves, not
            ;; change the tree in-place
            (tset shell-surface :rotation (- (/ (math.random) 10.0) 0.05))
            (tset shell-surface :x (math.random 200))
            (tset shell-surface :y (math.random 100)))
          {}))

(set app-state (initial-state))
(dispatch :light-blue-touchpaper {})
(wlroots.wlr_backend_start app-state.backend)
(wayland.wl_display_run app-state.display)
