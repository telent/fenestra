{ stdenv, fetchFromGitHub, fetchurl
, luajit
, pkgconfig
, pixman
, wayland
, wlroots
, libxkbcommon
} :
let
  inspect_lua = fetchurl {
    name = "inspect.lua";
    url = "https://raw.githubusercontent.com/kikito/inspect.lua/master/inspect.lua";
    sha256 = "1xk42w7vwnc6k5iiqbzlnnapas4fk879mkj36nws2p2w03nj5508";
  };
  fennel = fetchFromGitHub {
    owner = "bakpakin";
    repo = "Fennel";
    rev  = "b4d295c5822b70ae5d750938da1b487082eacabb";
    sha256 = "05bsi0396fbwk2i94a3g2m3rz06l60m5r4k33jqkaywbsghmn6wd";
  };
in stdenv.mkDerivation {
  name = "fenestra";
  version = "0.0.1";
  src = ./.;
  FENNEL = "${fennel}/fennel";
  WLROOTS = "${wlroots}";
  nativeBuildInputs = [
    libxkbcommon
    luajit
    pixman
    pkgconfig
    wayland
    wlroots
  ];
}
