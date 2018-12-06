
# Fenestra

(Some day) An extensible Wayland compositor leveraging [Fennel](https://fennel-lang.org/)

(Today)
* A Lua program that uses Luajit FFI to create a wayland server
that colours in the entire screen solid red.

  * https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html
  * https://drewdevault.com/2018/02/22/Writing-a-wayland-compositor-part-2.html

* a Lua REPL attached to a Unix socket


## How to use it

Build wlroots

```
nix-shell --run "meson build && ninja -C build"
```

Run the lua script

```
nix-shell --run ./fenestra/fenestra
```

Hack all the things

```
$EDITOR init.lua
```
