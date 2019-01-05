# Fenestra

Some day this will be a Wayland compositor written in Fennel.  Right now
it doesn't do a lot.

Github thinks it's a fork of wlroots. This is an accident of history and
will stop being the case some time soon.


![Screenshot](https://files.mastodon.social/media_attachments/files/009/688/595/original/c93cbe0521f4407c.png)

## Architecture

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

## See also

* https://fennel-lang.org/    - the language
* https://github.com/Day8/re-frame#it-is-a-6-domino-cascade - architectural inspiration
* https://github.com/swaywm/wlroots/ - lowlevel wayland heavy lifting
* https://ww.telent.net/2018/12/18/moon_on_a_stick - first of probably some number of blog entries on the subject, by me
