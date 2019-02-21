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

(local fennelview (require "fennelview"))
(global pp (lambda [x] (print (fennelview x))))

(local prelude (require "prelude"))
(each [name fun (pairs prelude)] (tset _G name fun))
  
(let [f (io.open "defs.h.out" "r")]
  (ffi.cdef (f.read f "*all")))

(lambda from-cpath [name]
  (package.searchpath name package.cpath))

(local wlroots (ffi.load (from-cpath "wlroots")))
(local wayland (ffi.load (from-cpath "wayland-server")))
(local xkbcommon (ffi.load (from-cpath "xkbcommon")))


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




                                            
(var handlers {})

(lambda listen [name handler] 
  (tset handlers
        name
        (conj (or (. handlers name) []) handler)))

(var app-state {})

(var seats {
            :hotseat {}
            })

(lambda seat-effect-handler [[command seat-name input-name attributes]]
  (let [seat (. seats seat-name)]
    (if (= command :attach)
        (set seats (assoc-in seats [seat-name :inputs input-name] attributes))
        (= command :detach)
        (print "detach " attributes)
        (= command :create)
        (set seats (assoc-in seats [seat-name :wlr-seat]
                             (wlroots.wlr_seat_create
                              input-name seat-name)))
        (error ["unrecognised command"  command]))
    (pp seats)
    (let [inputs (or seat.inputs [])
          keyboard? (any (fn [name attrs] attrs.keyboard) inputs)
          pointer? (any (fn [name attrs] attrs.pointer) inputs)
          caps 
          (+ (if keyboard? ffi.C.WL_SEAT_CAPABILITY_KEYBOARD 0)
             (if pointer? ffi.C.WL_SEAT_CAPABILITY_POINTER 0)
             )]
      (wlroots.wlr_seat_set_capabilities seat.wlr-seat caps))
    ))

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
      :seat seat-effect-handler
      })

(lambda dispatch [name ...]
  (print "dispatch " name)
  (let [fns (. handlers name)]
    (when fns
      (each [_ f (ipairs fns)]
        (let [effects (f app-state (unpack [...]))]
          (each [name value (pairs effects)]
            (let [h (. effect-handlers name)]
              (if h
                  (h value)
                  (error (.. "no effect handler for " name))))))))))

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
              }
             :seat
             [:create :hotseat d nil] })))


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
                
                {:seat
                 [:attach
                  :hotseat
                  (ffi.string input.name)
                  (merge i (ctor seats.hotseat input state))
                  ]}))))

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
                seat seats.hotseat
;                kbd-device (first (filter (fn [k v] v.keyboard) seat.inputs))
;                keyboard (and kbd-device
;                              (. seat.inputs kbd-device :keyboard :wlr-keyboard))
                ]
            ;; I *think* this function is expecting to get an array of
            ;; currently-pressed keys, not something about available
            ;; keys. So probably we don't need access to the keyboard
            ;; as such here, but should to talk to the gesture
            ;; recogniser such that any ongoing gesture involving held
            ;; keys is cancelled and the key state is sent to the
            ;; client instead.  For now we'll pretend nothing is ever
            ;; being typed at the moment the new window pops up
            (print "map " wl-surface)
            (wlroots.wlr_seat_keyboard_notify_enter
             seat.wlr-seat
             wl-surface
             nil ; keyboard.keycodes       
             0 ; keyboard.num_keycodes
             nil ; keyboard.modifiers
             )
            {:state
             {[:surfaces id] (assoc shell-surface
                                    :rotation (- (/ (math.random) 10.0) 0.05)
                                    :x (math.random 200)
                                    :y (math.random 100))}})))
        
(set app-state (initial-state))
(dispatch :light-blue-touchpaper {})
(wlroots.wlr_backend_start app-state.backend)
(wayland.wl_display_run app-state.display)
