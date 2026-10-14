# ArtCraft Launcher, installed from the upstream prebuilt .tar.gz.
#
# The binary is a Rust/winit/wgpu GUI app. It links glibc + libgcc_s directly;
# everything else is dlopen'd at runtime and must be reachable through the
# binary's RPATH / wrapper LD_LIBRARY_PATH:
#   - mesa, vulkan-loader: wgpu renderer (libEGL, libvulkan)
#   - wayland, xorg libs, libxkbcommon: winit windowing (Wayland and X11)
{
  system,
  sources,
  lib,
  stdenv,
  autoPatchelfHook,
  fetchurl,
  makeWrapper,
  gcc-unwrapped,
  mesa,
  vulkan-loader,
  wayland,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxkbcommon,
  appimage-run,
}:

let
  inherit (sources) version tag;
  tarballSystem = lib.removeSuffix "-linux" system;
in

stdenv.mkDerivation {
  pname = "artcraft-launcher";
  inherit version;

  src = fetchurl {
    url = sources.urlOf tarballSystem tag version;
    hash = sources.perSystem.${system}.hash;
  };

  # The tarball ships prebuilt binaries; autoPatchelfHook fixes the ELF
  # interpreter and rpath so they run against Nix's glibc.
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ gcc-unwrapped ];

  # dlopen'd at runtime; autoPatchelfHook adds these to the binary's RPATH,
  # which is also where dlopen looks them up.
  runtimeDependencies = [
    mesa
    vulkan-loader
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
    libxkbcommon
  ];

  sourceRoot = "artcraft-launcher-${version}-linux-${tarballSystem}";

  # The tarball layout mirrors a / prefix: bin/... and share/...
  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin share $out/

    # Replace the tarball's desktop entry with our own (no version in the
    # name, proper capitalization); icons come from the tarball's share/.
    install -Dm644 ${./artcraft-launcher.desktop} \
      $out/share/applications/ai.storyteller.artcraft-launcher.desktop

    # Belt and suspenders: also supply the dlopen'd libraries through the
    # wrapper in case the runtime environment lacks them.
    # appimage-run is required to launch the Craft apps the launcher
    # installs (they ship as AppImages).
    wrapProgram $out/bin/artcraft-launcher \
      --prefix PATH : "${lib.makeBinPath [ appimage-run ]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        mesa
        vulkan-loader
        wayland
        libx11
        libxcursor
        libxi
        libxrandr
        libxkbcommon
      ]}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Launcher for the Craft App Suite (PhotoCraft, FilmCraft, ...) (requires appimage-run)";
    longDescription = ''
      ArtCraft Launcher lists every app in the Craft App Suite,
      installs the right build for your computer, and keeps them up
      to date.
    '';
    homepage = "https://github.com/storytold/craft-launcher";
    license = with licenses; [
      asl20
      mit
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "artcraft-launcher";
  };
}
