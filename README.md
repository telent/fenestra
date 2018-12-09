
# What is Fenestra

(Some day)

* An extensible Wayland compositor leveraging [Fennel](https://fennel-lang.org/)
* Finally, a way to use my laptop that doesn't leave me longing for sawfish

(Today)

* A Lua program that uses Luajit FFI to create a wayland compositor
that can display (though not actually interact with)
weston-terminal.  Thus far, heavily based on 

  * https://drewdevault.com/2018/02/17/Writing-a-Wayland-compositor-1.html
  * https://drewdevault.com/2018/02/22/Writing-a-wayland-compositor-part-2.html
  * https://drewdevault.com/2018/02/28/Writing-a-wayland-compositor-part-3.html

  * https://drewdevault.com/2018/07/17/Input-handling-in-wlroots.html (not yet)

* some code, presently unused, that makes a Lua REPL attached to a Unix socket


# How to use it

If you're running Nixpkgs you can use `nix-shell` to get all the
dependencies.  If not, carefully study the contents of the curly
braces at the top of `package.nix` and figure out yourself how that
maps onto the packages in your preferred (GNU/)Linux variety
.
## Build wlroots

```
meson build && ninja -C build
```

## Build the ffi gubbins

```
make -C fenestra
```

## run the lua script

    ./fenestra/fenestra

or even

    (./fenestra/fenestra  |tee log 2>&1    &) ; sleep 2 ; ( nix-shell -p weston --run weston-terminal  & )  ;  sleep 10; sh -c 'kill `cat /tmp/fenestra.pid`' 



## Hack all the things

```
$EDITOR init.lua fenestra/defs.h
```
