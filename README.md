# Fenestra

Some day this will be a Wayland compositor written in Fennel.  Right now
it doesn't do a lot.

Github thinks it's a fork of wlroots. This is an accident of history and
will stop being the case some time soon.


![Screenshot](https://files.mastodon.social/media_attachments/files/009/688/595/original/c93cbe0521f4407c.png)

# Architecture

This is tentative and exploratory and we're going to have to find out
how well it fits, but we're shooting for something FRP-ish a la
re-frame.

* There's a single value (a tree) with all the _application state_ in
  it. It's currenlty a global called `app-state` but that will probably change.

* When platorm code (wayland or wlroots) raises platform events, our
  _platform event handlers_ are very simple objects that do nothing more
  than transform them into application events using `dispatch`

* Our _application event handlers_ are introduced with `listen`, and
  are intended to be purely functions which return data structures
  that are passed into _effect handlers_ that do the ugly stuff.
  (Right now they do considerably more - most of it messing about with
  wlroots foreign code - but this is not to be taken as
  desirable. Once we have the thing basically working we will look at
  extracting that side-effecting code into instructions of some kind to
  one or more effect handlers)

* As of last time this readme was updated, the only extant _effect
  handler_ is the one that updates the app-state.  It expects a table
  (hash, map, dictionary, however you say it) in which each key is an
  array of a path through the app-state and the corresponding value is what
  the event handler wishes to have set there.

* something something _views_ mumble mumble - this is TBD.  Some
  day, if it turns out they're required, views will be computations
  over portions of the app-state which are cached and recomputed as
  needed when the values in their subscribed inputs change.

* the platform code also calls a handler we supply whenever a frame
  needs _rendering_ (like, 60 times a second, I'm guessing) at which
  time we use the data in the app-state (and some day, in the views)
  to decide what surfaces to render and where, and at what jaunty
  angles.

# See also

* https://fennel-lang.org/    - the language
* https://github.com/Day8/re-frame#it-is-a-6-domino-cascade - architectural inspiration
* https://github.com/swaywm/wlroots/ - lowlevel wayland heavy lifting
* https://ww.telent.net/2018/12/18/moon_on_a_stick - first of probably some number of blog entries on the subject, by me

----

# Pay no attention to the meandering behind this line

Some notes about likely or possible changes to direction that aren't
concrete enought to get written up yet.  For my benefit not yours

## Sat Jan  5 23:58:14 GMT 2019


* new-input needs to know which seat the device is part of

* (following from previous point) maybe event handlers should be
  passed state as *first* arg, then `dispatch` can pass through as
  many args as necessary.

## Mon Jan  7 15:40:34 GMT 2019

Did both of those (well, not exactly.  It is for us to *decide* which
seat to associate a new input with, but now we make the new-input
listener choose), and now having Feels about the return type of
`listen` and effect handlers.

Context: I would like some code that updates seat capabilities when
the input devices are plugged/unplugged.

Thing is, if input devices are not part of the app state (there's a
pretty good argument they shouldn't be, I think: they're updated by
the outside world, not by compositor policy) then it needs to maintain
(or have maintained for it) the collection of connected devices.  I
suppose it could just close over a private var.

Also thing I've been thinking about that I'm not sure how it fits in:
gesture recognition.  Need a reasonably clean way to recognise
gestures that may extend over time, and to allow the view to query
"in-progress" gestures so that it may e.g. render drag handles.

Perhaps these are both part of the same thing, given that gestures are
recognised by consuming input events.  Perhaps the gesture handler is
hooked up to the inputs and emits events when gestures are predicted/final

## Mon Jan  7 23:40:53 GMT 2019

proposal:

- existing listeners have to return {:state ...foo...} where currently
 they return bare foo
- the key in this map names an effect handler
- update-in app-state becomes the first effect handler
- input device plug/unplug goes through the same event handler logic, but
  the handlers return {:seat ...bar...}
- the :seat effect handler does all input device bookkeeping, and also
  gesture recognition (feeds back into events)
- some convention for in-progress vs completed gesture events
- when the same series of input events can be identified as potentially
  several different gestures ("is this going to be a tap or a drag? don't know
  yet") - something or other, don't know, but having this all dealt with in
  a single place will make it easier to see when we have a conflict

## Tue Jan  8 22:36:25 GMT 2019

- display is a global singleton
- input-devices and outputs are the only foreign objects that come and go dynamically

outputs need to be represented in state so that we can decide what to
render on each

Inputs are their own effect handler

## Sun Jan 13 00:27:19 GMT 2019

I am not convinced that this `shell` effect handler operating in
parallel and in isolation is the right thing, thinking that instead we
should have everything back into the one `state` table, and that
imperative code dealing with pointers, keyboards etc should do it by
defining views on that state such that they get triggered when bits of
state of interest to them are changed.  *Also*, though, try to keep native
structs out of the state as far as possible: domain event handlers
unpack the relevant fields in native structs and pass lua objects
to app event handlers

What does this mean?

- for example, the cursor should have wlr_cursor_attach_input_device
called every time there is a change in the available pointer devices
for the seat.

- we will need a place or places at the end of the data flow pipeline
which stores state pertinent to the outside world.  The analogous
thing in react/re-frame is whatever thing holds the previous/current
DOM representation so that we can compare changes against it and know
what needs updating

  - window positions, output placements
  - attached devices, per-seat

  in most respects these functions look like views, excepting their
  need for local state storage

  sometimes maybe they can just use a weak table to store native
  values indexed by the corresponding lua value.  e.g. keyboard=>wlr_keyboard, 


- not sure where to put the record of historic input events that gesture recognition will need.
  - inside input event handlers, somehow?
  - add a queue in the state, and then the recogniser is a view on this queue
  - add instanteous key/pointer/modifier values in the state, and then the recogniser is a view-with-local-state which updates a private queue containing historic input events whenever device state changes.

- I will not be surprised if we need to add lazy evaluation of the view functions sooner rather later

## Sun Jan 13 23:49:55 GMT 2019

As an aside: if we went with a more CSP-y approach, each node in the
dataflow graph would loop forever sucking new inputs, and could close
over any local state it likes. Currently I think I would like to avoid
doing that, because it means opaque local state in each node which
cannot possible make it easier to reason about what the node will do
for any given input.

Perhaps there could be a convention that nodes return a post-execution
state as well as their output value, and whatever it is that runs each
node could be tasked with remembering to call it with that state when
it next runs

## Mon Jan 14 23:45:07 GMT 2019

For example we could have something like

(defnode keyboard-focus [seat]
  (:subscribes surfaces)
  (first (filter (fn [k s] s.focused?) surfaces)))
  
which expands to something like

(tset nodes
      :keyboard-focus
      (fn [previous-local-state seat]
        (let [surfaces# (pull-node-value :surfaces)]
  	  (values previous-local-state ; no state changed
	  	  (first (filter (fn [k s] s.focused?) surfaces#))))))

(assuming we can figure out how to do macros with gensyms in fennel)

I haven't figured out how to have lots of nodes that combine to
contribute to the same intermediate value.  For example, there are
several events (create, map, unmap, destroy ...) on surfaces that
should all write into the same surfaces value.  There would need to be
some kind of `alts` construct to say that we accept values from n
different places

;; handle a new surface
(fn [prev-state attrs]
  (plet [new-surface# (pull-node-value :new-surface-event)
         dead-surface# (pull-node-value :destroy-surface-event)]
    ;; is this return value or next state?  both, probably
    (merge (dissoc attrs dead-surface#) new-surface#)))
  
## Tue Jan 15 12:13:15 GMT 2019

What if the local state *is* the output value?  Nodes have sight of
the values of their subscriptions, and their own previous output value,
and calculate a new output value based on that.

do we even still need "app event handlers"?  Platform event handlers
can set values as their actions.

still need to figure out updates

- the repaint runs every 50Hz with whatever values are in the graph at
  that time

- but the gesture handler needs to run whenever its upstreams change state,
  and only when they change state

=> The gesture handler is part of the dataflow network
   The repaint is external to it, but somehow has sight of the current
    value of the scene graph


In the interests of staying functional, can we decree/recommend that
it is not permitted to run imperative code in an interior node?
Either we have a convention that only sink nodes may do side-effects,
or we have some protocol for attaching effect handlers to sink nodes
such that they get run when the sink node value changes.


nodes = {
  name: {
    fn: function,
    inputs: [ other names, ... ], 
    value: {},
    version: 0
  }
}


* when the value is called for, check the versions of our inputs: if 
any is larger than the version of this node, we need to recompute this node

* when the value changes (by computation or by input event), set the
version to max(versions of inputs) if there are any; (inc version) if not.

* BUT: this lazy update doesn't help for signals that originate in
  external events, and I cannot see how to avoid pushing changes all
  the way through from input event to gesture recogniser.  otherwise
  what happens if multiple events happen on an input (button pressed
  then released) too quickly for it to be called

