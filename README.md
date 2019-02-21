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

## Thu Jan 17 07:09:07 GMT 2019

proposal: we do push-based updates but only through the parts of the
graph that are required by sinks that have effect handlers attached.
we have to push through updates at least as far as the nodes that record
them and accumulate historical state

define the graph
define the sources and how they're updated (by events)
sort the graph
(optimization) figure out which bits of the graph to update
figure out how to actually run the code.


(we might say that each node is updated by a process akin to a
`reduce`: the function accepts the current value and the values of its
antecedents, and returns an updated value.  This is true, but is it
useful? Dunno)

## Fri Jan 18 22:58:51 GMT 2019

In fennel 0.2.0 we have kv destructuring, so I imagine something like

{:focused-surface {
  :inputs [:pointer-position :thingy]
  :fn (fn [value {:pointer-position pos :thingy thingy}]
        (let [s (find-surface-for-at-x-y pos.x pos.y)]
	  (assoc value :surface s)))
}}

which is to say, a node recalculation function is invoked with the
previous value and a table consisting of values of all its declared inputs

(fn evaluate-node [graph label]
  (let [node (. graph label)
        {:value value :inputs inputs :fn fn :v version} node
        input-table (filter (fn [label node] (member? label inputs))
		            graph)
	new-value ((fn node) value (map (fn [x] x.value) input-table))]
    (if (= value new-value)
        node
        (assoc node
               :value new-value
   	       :version (max (inc v) (map (fn [_ x] x.version) input-table))))))

this function makes no kind of check that its inputs are up to date,
so it's important to run the fucntions for each node in the right
(topo-sorted) order

Also, I think the logic for version is wrong.

Also also, still need:

* a syntax/function/convention for updating values of source nodes
  (in response to events, most lkely)
* something to subscribe to the value from a sink node.

## Sat Jan 19 23:17:44 GMT 2019

Applying some rigour to how source nodes get set

- If the node has no inputs in the graph, and it is not a constant,
  its value must be updated by some kind of command from outside the
  graph

- The node is responsible for defining the valid commands and their
  effect on the node value

- where multiple nodes are interested in accepting commands for the
  same external event, does the event handler need to know what they
  all are?  Would we be better modelling this as an event subscripton
  (wich can be 1:n) instead of requiring the event handler to know
  about all the nodes that need updating?


## Tue Jan 22 22:10:59 GMT 2019

Am wondering if we could have events passed through the graph instead
of being swallowed by input nodes.

Under this model: a node has

- some message sources it subscribes to
- a state (stored externally, for visibility, but for this node's exclusive use)
- some downstreams it pushes new messages to

on receipt of an input message it may
- update its state
- send further messages to its subscribers
- reconfigure the graph, by adding/deleting subscriptions (or subscribers?)

Should note that this is the same structure and set of operations as
giraphe and pregel permit, although they are distributed and
facebook-scale and all that stuff, and we are clearly not.

 https://web.mit.edu/6.976/www/handout/valiant2.pdf is the paper that
 everyone cites.

 https://www.researchgate.net/publication/279189639_Towards_Distributed_Processing_on_Event-sourced_Graphs looks relevant also, may or may not be influential

on new input: get details, determine seat, add to that seat's relevant
composite input channel

on new output: get details, add output scene graph, maybe move
some windows over to it? maybe trigger birds-eye view so user can move
windows themself?

on new surface: determine placement, add to master scene graph, add to
appropriate output scene graphs, determine whether target of any seat
focus, arrange for focus

on move or resize surface: determine placement, see which
output scene graphs it appears on, determine whether target
of any seat focus, arrange for focus

on key event: determine if should send to surface.  if part of
compositor gesture, remember.  update master scene graph with any
speculative or final gestures 


nodes that seem to spring from this list
- master scene graph
- output scene graph, for each output
- gesture recogniser, for each seat
- composite input controllers (pointer, key source, etc) for each seat

consumers of node data: 
- focusser, for each seat
- renderer, for each output
- the thing that adds outputs to a layout
- the thing that adds input devices to a composite seat input
- thing to send key events to focused surface?

the renderer is a special case here, it's the only one that needs node
value (of the output scene graph) and couldn't be written as a message
handler.  Actually that might not even be true.  Maybe the renderer
could get messages when the scene graph changes and use that to cue up
the back buffer for the next vblank - it would just Do Nothing if
nothing had changed.

Thinking that a node function is invoked with [ old value, message
received] and returns [ new value, any messages to publish ] - but
this doesn't permit graph rewiring,  need to find a way to express that.
Ideally as data, without side-effects

graph reconfig may involve whole subtrees, not just nodes


## Mon Jan 28 21:56:54 GMT 2019

It may be a lot simpler if we take graph rewiring out of scope, and
implement it as an effect.  I haven't written a lot recently about
effect handlers, but I propose that they are "message sinks" which can
subscribe to nodes and do side-effects but which do not have
downstream nodes.

When a node is created it needs to be able to find the nodes it wishes
to subscribe to.  If there are multiple nodes of the same "type" - for
example, per-output scene graph nodes - then we need something a bit
more complicated here than find-by-name

## Wed Jan 30 15:30:07 GMT 2019 

Taking a leaf from REST, maybe: the node should declare its output
event type (c.f. "media type") and then new nodes can find existing
nodes by name (if singleton) or by type (if one of a set).  

Maybe we just have "find nodes matching these attributes" where name
and output-media-type are two of the available attributes


what do we need?

(find-nodes attributes)
(add-node {:attributes {...} :inputs attributes :fn (fn [] ....) :events [] ...})
(add-effect {:inputs attributes :fn (fn [] ....)})
(remove-nodes attributes)

must a node attribute set be unique?  otherwise there's no way to
unambigously identify which it is, except for its actual identity

;; and something to run the nodes

(send-event event node-graph)
- for each node n1 in the collection N1 that subscribe to the event
  - invoke n1 with its last known values and the event payload as message
  - return value is (new-value message): capture the value and store it
  - for each node n2 in the collection N2 whose input attributes include N1,
     invoke it with its value and the message returned by n1
    - repeat until we run out of nodes

where do we keep the node values?  in a table, presumably: can we use
the node spec as key? or even the node itself?

## Sun Feb  3 23:31:24 GMT 2019

Let's write some code, and just for fun let's write some tests first

Given that I have a graph which counts input events
When I send it 7 different events
Then the sink node receives an event whose payload is 7

Thu Feb 14 15:51:00 GMT 2019

`dispatch` finds nodes which subscribe to the specified event, but
these are (by definition) source nodes: interior nodes are linked with
:inputs not :events, so we need some other way fo finding downstreams


