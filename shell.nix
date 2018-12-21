with import <nixpkgs> {};
let p = pkgs.callPackage ./package.nix {};
reflect = pkgs.fetchFromGitHub {
  name = "lua-ffi_reflect";
  owner = "luapower";
  repo = "ffi_reflect";
  rev = "9eeeb18a474656c917cc28812d667637cc2896b8";
  sha1 = "bs30k4b1nz03ysc1xqlfdh9nd08f75kv";
};
debugger = pkgs.fetchFromGitHub {
  name = "lua-debugger";
  owner = "slembcke";
  repo = "debugger.lua";
  rev = "867284deebf12b2da912b37e5f5200078f8c514f";
  sha1 = "yf8hv0wqgzrm4986q2ci51anh6lgsqxw";
};
in p.overrideAttrs (o: {
  LUA_PATH = "${reflect}/?.lua;${debugger}/?.lua";
  shellHook = ''
    eval "$(luarocks path)"
  '';
  })
  
