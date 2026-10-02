# Helium browser (not in nixpkgs) – upstream AppImage from imputnet/helium-linux.
# To update: bump `version`, then run
#   nix-prefetch-url <url> | xargs nix hash convert --hash-algo sha256 --to sri
{ pkgs }:
let
  pname = "helium";
  version = "0.18.2.1";
  src = pkgs.fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-qm7EQA3TQT9d1eYzpRQI4HzT894GJlAc1OVc3RNk3iE=";
  };
  contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    mkdir -p $out/share
    cp -r ${contents}/usr/share/icons $out/share/ 2>/dev/null || true
    install -Dm444 ${contents}/*.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/*.desktop \
      --replace-quiet 'Exec=AppRun' 'Exec=${pname}' \
      --replace-quiet 'Exec=helium' 'Exec=${pname}'
  '';
  meta.mainProgram = "helium";
}
