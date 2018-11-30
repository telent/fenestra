
# Fenestra

(Some day) An extensible Wayland compositor leveraging [Fennel](https://fennel-lang.org/)

(Today) A fork of wlroots with a hackily grafted-on Lua REPL in a unix socket


## Building

```
nix-shell --run "meson build && ninja -C build"
```
