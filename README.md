
# What is Fenestra

(Some day) An extensible Wayland compositor leveraging [Fennel](https://fennel-lang.org/)

(Today)
* A Lua program that uses Luajit FFI to create a wayland server
that you can use to display (though not actually interact with)
weston-terminal

  * https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html
  * https://drewdevault.com/2018/02/22/Writing-a-wayland-compositor-part-2.html

* some code, presently unused, that makes a Lua REPL attached to a Unix socket


# How to use it

## Build wlroots

```
nix-shell --run "meson build && ninja -C build"
```

## Build the ffi gubbins and run the lua script

```
nix-shell --run "make -C fenestra && ./fenestra/fenestra"
```

or even

```
$ nix-shell
$ (./fenestra/fenestra  |tee log 2>&1    &) ; sleep 2 ; ( nix-shell -p weston --run weston-terminal  & )  ;  sleep 10; sh -c 'kill `cat /tmp/fenestra.pid`' 
```


## Hack all the things

```
$EDITOR init.lua fenestra/defs.h
```
