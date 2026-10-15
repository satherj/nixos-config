{ lib, stdenvNoCC, fetchurl }:

# Phosphor icon fonts (thin/light/regular/bold/fill/duotone) from the official @phosphor-icons/web npm package.
# Families: "Phosphor", "Phosphor-Thin", "Phosphor-Light", "Phosphor-Bold", "Phosphor-Fill", "Phosphor-Duotone".
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "phosphor-icons";
  version = "2.1.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@phosphor-icons/web/-/web-${finalAttrs.version}.tgz";
    hash = "sha256-QOMJYJnKgYwEeXnOzmo3ZJRNUgDGe2QJL3vNi80dKwg=";
  };

  sourceRoot = "package";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm444 src/*/*.ttf -t $out/share/fonts/truetype
    install -Dm444 LICENSE -t $out/share/doc/${finalAttrs.pname}
    runHook postInstall
  '';

  meta = {
    description = "Phosphor icon family as TrueType fonts";
    homepage = "https://phosphoricons.com";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
