{ stdenv, fetchFromGitHub, fetchurl
, libX11
, libudev
, libxkbcommon
, luajit
, mesa_noglu
, pixman
, pkgconfig
, rlwrap
, wayland
, wayland-protocols
, wlroots
} :
let
  inspect_lua = fetchurl {
    name = "inspect.lua";
    url = "https://raw.githubusercontent.com/kikito/inspect.lua/master/inspect.lua";
    sha256 = "1xk42w7vwnc6k5iiqbzlnnapas4fk879mkj36nws2p2w03nj5508";
  };
  ffi_reflect = fetchFromGitHub {
    owner = "luapower";
    repo = "ffi_reflect";
    name = "ffi_reflect";
    rev  = "9eeeb18a474656c917cc28812d667637cc2896b8";
    sha256 = "17wyvb7qwvr8j07zrj8a4kspfisqds6zfif3v4p2448p4xywscqs";
  };
  fennel = fetchFromGitHub {
    owner = "bakpakin";
    name = "fennel";
    repo = "Fennel";
    rev  = "b4d295c5822b70ae5d750938da1b487082eacabb";
    sha256 = "05bsi0396fbwk2i94a3g2m3rz06l60m5r4k33jqkaywbsghmn6wd";
  };
in stdenv.mkDerivation {
  name = "fenestra";
  version = "0.0.1";
  src = ./.;
  FENNEL = "${fennel}/fennel";
  LUA_PATH = "${fennel}/?.fnl.lua;${fennel}/?.lua;${ffi_reflect}/?.lua;;";
  LUA_CPATH = "${wayland}/lib/lib?.so;${libxkbcommon}/lib/lib?.so;${wlroots}/lib/lib?.so;;";

  WLROOTS = "${wlroots}";
  nativeBuildInputs = [
    libudev
    libX11
    libxkbcommon
    luajit
    mesa_noglu
    pixman
    pkgconfig
    wayland
    wayland-protocols
    wlroots
  ];
}
