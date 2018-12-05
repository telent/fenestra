{ stdenv, fetchFromGitHub, fetchurl, fetchpatch, meson, ninja, pkgconfig
, wayland, libGL, wayland-protocols, libinput, libxkbcommon, pixman
, xcbutilwm, libX11, libcap, xcbutilimage, xcbutilerrors, mesa_noglu
, libpng, ffmpeg_4
, luajit
, python3Packages # TODO: Temporary
}:

let
  pname = "wlroots";
  version = "0.1";
  meson480 = meson.overrideAttrs (oldAttrs: rec {
    name = pname + "-" + version;
    pname = "meson";
    version = "0.48.0";

    src = python3Packages.fetchPypi {
      inherit pname version;
      sha256 = "0qawsm6px1vca3babnqwn0hmkzsxy4w0gi345apd2qk3v0cv7ipc";
    };
    patches = builtins.filter # Remove gir-fallback-path.patch
      (str: !((stdenv.lib.hasSuffix "gir-fallback-path.patch" str) ||
      	      (stdenv.lib.hasSuffix "a87496addd9160300837aa50193f4798c6f1d251.patch" str)))
      oldAttrs.patches;
  });
  inspect_lua = fetchurl {
    name = "inspect.lua";
    url = "https://raw.githubusercontent.com/kikito/inspect.lua/master/inspect.lua";
    sha256 = "1xk42w7vwnc6k5iiqbzlnnapas4fk879mkj36nws2p2w03nj5508";
  };
in stdenv.mkDerivation rec {
  name = "${pname}-${version}";

  # src = fetchFromGitHub {
  #   owner = "swaywm";
  #   repo = "wlroots";
  #   rev = version;
  #   sha256 = "0xfipgg2qh2xcf3a1pzx8pyh1aqpb9rijdyi0as4s6fhgy4w269c";
  # };
  src = ./fenestra;

  # patches = [ (fetchpatch { # TODO: Only required for version 0.1
  #   url = https://github.com/swaywm/wlroots/commit/be6210cf8216c08a91e085dac0ec11d0e34fb217.patch;
  #   sha256 = "0njv7mr4ark603w79cxcsln29galh87vpzsx2dzkrl1x5x4i6cj5";
  # }) ];

  # $out for the library, $bin for rootston, and $examples for the example
  # programs (in examples) AND rootston
  outputs = [ "out" "bin" "examples" ];

  nativeBuildInputs = [ meson480 ninja pkgconfig ];

  buildInputs = [
    wayland libGL wayland-protocols libinput libxkbcommon pixman
    xcbutilwm libX11 libcap xcbutilimage xcbutilerrors mesa_noglu
    libpng ffmpeg_4
    luajit
  ];

  LUA_INSPECT = [ inspect_lua ];

  # this only works if you are in the fenestra subdirectory.
  # really need to tidy this up some time when it's not 1am
  LUA_CPATH = "${wayland}/lib/lib?.so;../build/lib?.so;;";

  mesonFlags = [
    "-Dlibcap=enabled" "-Dlogind=enabled" "-Dxwayland=enabled" "-Dx11-backend=enabled"
    "-Dxcb-icccm=enabled" "-Dxcb-xkb=enabled" "-Dxcb-errors=enabled"
  ];

  postInstall = ''
    # Install rootston (the reference compositor) to $bin and $examples
    for output in "$bin" "$examples"; do
      mkdir -p $output/bin
      cp rootston/rootston $output/bin/
      mkdir $output/lib
      cp libwlroots* $output/lib/
      patchelf \
        --set-rpath "$output/lib:${stdenv.lib.makeLibraryPath buildInputs}" \
        $output/bin/rootston
      mkdir $output/etc
      cp ../rootston/rootston.ini.example $output/etc/rootston.ini
    done
    # Install ALL example programs to $examples:
    # screencopy dmabuf-capture input-inhibitor layer-shell idle-inhibit idle
    # screenshot output-layout multi-pointer rotation tablet touch pointer
    # simple
    mkdir -p $examples/bin
    cd ./examples
    for binary in $(find . -executable -type f -printf '%P\n' | grep -vE '\.so'); do
      patchelf \
        --set-rpath "$examples/lib:${stdenv.lib.makeLibraryPath buildInputs}" \
        "$binary"
      cp "$binary" "$examples/bin/wlroots-$binary"
    done
  '';

  meta = with stdenv.lib; {
    description = "A modular Wayland compositor library";
    inherit (src.meta) homepage;
    license     = licenses.mit;
    platforms   = platforms.linux;
    maintainers = with maintainers; [ primeos ];
  };
}
