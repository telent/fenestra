;; -*- fennel -*- mode

(local ffi (require "ffi"))
(local io  (require "io"))
(local math (require "math"))
;; each is syntax in fennel, I am defining it as something random
;; because otherwise luafun exports it, and I would rather break
;; it in a place I know than have a library break it in a place I
;; don't know
(global each {}) 
((require "fun"))

(let [f (io.open "defs.h.out" "r")]
  (ffi.cdef (f.read f "*all")))

(lambda from-cpath [name]
  (package.searchpath name package.cpath))

(local wlroots (ffi.load (from-cpath "wlroots")))
(local wayland (ffi.load (from-cpath "wayland-server")))
(local xkbcommon (ffi.load (from-cpath "xkbcommon")))

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

(lambda wl-add-listener [signal func]
  (let [listener (ffi.new "struct wl_listener")]
    (set listener.notify (lambda [l d]
                           ;; close over listener to stop it being GCed
                           (func listener d)))
    (wayland.wl_list_insert signal.listener_list.prev listener.link)
    listener))

;; I'm sure there are better and more efficient ways to make hash keys
;; from ffi cdata objects, and some day I will find out what they are
(lambda ffi-address [cdata]
  (tonumber (ffi.cast "intptr_t" (ffi.cast "void *" cdata))))




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

(lambda inc [x] (+ x 1))
(lambda dec [x] (- x 1))

(assert (= 6 (sum (filter (lambda [x] (< x 3)) [1 7 1 9 2 10 2 4]))))

;; these are probably not the fastest way of doing this as I suspect
;; it does a lot of copying and makes a lot of garbage

(lambda empty? [c] (is_null c))

(fn id [x] x)

(lambda first [xs] (if (is_null xs) nil (head xs)))

(lambda keys [tbl]
  (let [out []]
    (each [k _ (pairs tbl)]
      (table.insert out k))
    out))

(lambda equal? [a b]
  (if (= (type a) (type b))
      (if (= (type a) "table")
          (and (= (length a) (length b))
               (every (fn [k] (equal? (. a k) (. b k)))
                      (keys a)))
          (= a b))
      false))

(assert (not (= 1 nil)) "1 is not nil")
(assert (equal? [6 1 2 3] [6 1 2 3]))
(assert (not  (equal? [1 2 3] [1 2 3 4])) "different lengths")
(assert (not (equal? {:l 2} {:l 2 :a 9})))
(assert (not (equal? {:l 2 :a 9} {:l 2})))
(assert (equal? {:l 2} {:l 2 }))

(lambda assert-equal [expected actual]
  (assert (equal? expected actual)
          (.. "test failed: "
              (fennelview
               {:expected expected
                :actual actual}))))

(fn assoc [tbl k v ...]
  (tset tbl k v)
  (if ...
      (assoc tbl (unpack [...]))
      tbl))

(assert-equal {:foo 1 :bar 34}
              (assoc {:foo 1}
                     :bar 34))

(assert-equal {:foo 1 :bar 34 :baz 6}
              (assoc {:foo 1}
                     :bar 34
                     :baz 6))



(lambda assoc-in [tbl path value]
  (let [k (head path)
        r (tail path)]
    (if (empty? r)
        (assoc tbl k value)
        (assoc tbl k (assoc-in (or (. tbl k) {}) r value)))))

(assert-equal {:k 2}
              (assoc-in {} [:k] 2))

(assert-equal {:horse {:zebra 9} }
              (assoc-in {} [:horse :zebra] 9))

(assert-equal {:horse {:zebra 9} }
              (assoc-in {:horse {:zebra 11}} [:horse :zebra] 9))

(assert-equal {:k {:l 2 :z 9} }
              (assoc-in {:k {:z 9}} [:k :l] 2))

                                            
(var handlers {})

(lambda listen [name handler] 
  (tset handlers
        name
        (conj (or (. handlers name) []) handler)))

(var app-state {})

(var effect-handlers
     {
      :state
      (lambda [new-paths]
        ;; again, this happens to be destructive but the caller
        ;; should not depend on it
        (set app-state
             (reduce (lambda [m path]
                       (assoc-in m path (. new-paths path)))
                     app-state
                     new-paths)))
      })

(lambda dispatch [name ...]
  (print "dispatch " name)
  (let [fns (. handlers name)]
    (when fns
      (each [_ f (ipairs fns)]
        (let [effects (f app-state (unpack [...]))]
          (each [name value (pairs effects)]
            ((. effect-handlers name) value)))))))

(lambda new-backend [display]
  (let [be (wlroots.wlr_backend_autocreate display nil)]
    (wl-add-listener
     be.events.new_output
     (lambda [_ data]
       (dispatch :new-output (ffi.cast "struct wlr_output *" data))))
    (wl-add-listener
     be.events.new_input
     (lambda [_ data]
       (dispatch :new-input (ffi.cast "struct wlr_input_device *" data))))
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
        (lambda [state event]
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
            {:state
             {[:xdg-shell] (new-xdg-shell d)
              [:seats :hotseat]
              {:wlr-seat (wlroots.wlr_seat_create d "hotseat")}}})))

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
      (each [_ s (pairs app-state.surfaces)]
        (if (and s.x s.y)
            ;; not every surface is a shell, not every shell is mapped
            (render-surface s output renderer))))
    
    (wlroots.wlr_output_swap_buffers output  nil nil)
    (wlroots.wlr_renderer_end renderer)))

(listen :new-output
        (lambda [state output]
          (let [l
                (wl-add-listener
                 output.events.frame
                 (lambda [_ _] (render-frame output)))]
            (wlroots.wlr_output_create_global output)
            {:state
             {[:outputs (ffi-address output)]
              {:wl-output output :frame-listener l}}})))

(lambda set-default-keymap [keyboard]
  (let [rules (ffi.new "struct xkb_rule_names" {})
   ;; -- rules.rules = getenv("XKB_DEFAULT_RULES");
   ;; -- rules.model = getenv("XKB_DEFAULT_MODEL");
   ;; -- rules.layout = getenv("XKB_DEFAULT_LAYOUT");
   ;; -- rules.variant = getenv("XKB_DEFAULT_VARIANT");
   ;; -- rules.options = getenv("XKB_DEFAULT_OPTIONS");
        context (xkbcommon.xkb_context_new 0)
        keymap (and context
                    (xkbcommon.xkb_keymap_new_from_names context rules 0))
        ret (if keymap
                (wlroots.wlr_keyboard_set_keymap keyboard keymap)
                (values nil (if context
                                "Couldn't create keymap"
                                "Couldn't create xkb context")))]
    (and keymap (xkbcommon.xkb_keymap_unref keymap))
    (and context (xkbcommon.xkb_context_unref context))
    ret))


(listen :key
        (lambda [state seat key-event]
          (print "keypress" key-event.keycode)
          (wlroots.wlr_seat_keyboard_notify_key
           seat.wlr-seat
	   key-event.time_msec,
	   key-event.keycode,
	   key-event.state)
          {}))


(lambda new-keyboard [seat input state]
  (let [k input.keyboard]
    (set-default-keymap k)

    (wl-add-listener
     k.events.key
     (lambda [l d]
       (dispatch :key
                 seat
                 (ffi.cast "struct wlr_event_keyboard_key *" d))))

    (wlroots.wlr_seat_set_keyboard seat.wlr-seat input)
    (wlroots.wlr_seat_set_capabilities
     seat.wlr-seat ffi.C.WL_SEAT_CAPABILITY_KEYBOARD)

    {:keyboard
     {:wlr-keyboard k}}))

(lambda new-pointer [seat input state]
  (let [p input.pointer]
    ;(wlroots.wlr_cursor_attach_input_device seat.cursor.wlr_cursor input)
    {:pointer :tba}))

(local input-ctors
       {
        ffi.C.WLR_INPUT_DEVICE_KEYBOARD new-keyboard,
        ffi.C.WLR_INPUT_DEVICE_POINTER new-pointer
        })

(listen :new-input
        ;; the backend tells us what the connected input devices
        ;; are, but the choice of which seat to attach which device to
        ;; is ours as the compositor.  For the moment we have only one seat
        (lambda [state input]
          (let [i {:name (ffi.string input.name)
                   :vendor input.vendor
                   :wlr-input-device input
                   :product input.product}
                ctor (. input-ctors (tonumber input.type))]
            (if (= ctor nil)
                (do
                  (print "no support for input device " i.name
                         " of type " input.type)
                  {})
                {:state
                 {[:inputs (ffi.string input.name)]
                  (merge i (ctor state.seats.hotseat input state))}}))))

(listen :new-surface
        (lambda [state surface]
          (print "new surface")
          (let [s {:wlr-surface surface
                   :matrix (ffi.new "float[16]")
                   ;; a new surface may not be a shell, and even if it is we
                   ;; don't know how big to render it (and perhaps therefore
                   ;; where to put it) until it's mapped.
                   :x nil
                   :y nil}]
            {:state {[:surfaces (ffi-address surface)] s}})))

(listen :map-shell
        (lambda [state wl-surface]
          (let [id  (ffi-address wl-surface)
                shell-surface (. state.surfaces id)
                kbd-device (first (filter (fn [k v] v.keyboard) state.inputs))
                keyboard (and kbd-device
                              (. state.inputs kbd-device :keyboard :wlr-keyboard))
                ]
            (print "map " wl-surface)
            (wlroots.wlr_seat_keyboard_notify_enter
             state.seats.hotseat.wlr-seat
             wl-surface
             keyboard.keycodes
             keyboard.num_keycodes
             keyboard.modifiers)
            {:state
             {[:surfaces id] (assoc shell-surface
                                    :rotation (- (/ (math.random) 10.0) 0.05)
                                    :x (math.random 200)
                                    :y (math.random 100))}})))
        
(set app-state (initial-state))
(dispatch :light-blue-touchpaper {})
(wlroots.wlr_backend_start app-state.backend)
(wayland.wl_display_run app-state.display)
