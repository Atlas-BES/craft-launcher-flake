{
  description = "ArtCraft Launcher - install, update and launch the Craft App Suite";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      version = "0.4.0";
      tag = "v${version}";

      # Per-release asset hashes (from the release's SHA256SUMS.txt).
      # One tarball per supported Linux architecture.
      assets = {
        x86_64-linux = {
          url = "https://github.com/storytold/craft-launcher/releases/download/${tag}/artcraft-launcher-${version}-linux-x86_64.tar.gz";
          hash = "sha256-9cG5HhSZfQMYlEzf6INmzVBQYcO/OTVpkS/vd3YEFDI=";
        };
        aarch64-linux = {
          url = "https://github.com/storytold/craft-launcher/releases/download/${tag}/artcraft-launcher-${version}-linux-aarch64.tar.gz";
          hash = "sha256-21me8n5Cjl8qhHIJ0f8pe/HSXjqJi3QES45mRP0F6Xc=";
        };
      };

      forAllSystems = f: nixpkgs.lib.genAttrs (builtins.attrNames assets) f;

      artcraft-launcher =
        {
          system,
          lib,
          stdenv,
          autoPatchelfHook,
          fetchurl,
          gcc-unwrapped,
          mesa,
          vulkan-loader,
          makeWrapper,
        }:
        stdenv.mkDerivation {
          pname = "artcraft-launcher";
          inherit version;

          src = fetchurl {
            url = assets.${system}.url;
            hash = assets.${system}.hash;
          };

          # The tarball ships prebuilt binaries; autoPatchelfHook fixes the
          # ELF interpreter and rpath so they run against Nix's glibc.
          nativeBuildInputs = [
            autoPatchelfHook
            makeWrapper
          ];

          # glibc + libgcc_s are linked directly; libEGL/Vulkan are dlopen'd
          # at runtime (wgpu renderer), so they go on the wrapper path.
          buildInputs = [ gcc-unwrapped ];
          runtimeDependencies = [
            mesa # libEGL.so.1 / libGL.so.1
            vulkan-loader # libvulkan.so.1
          ];

          sourceRoot = "artcraft-launcher-${version}-linux-${lib.removeSuffix "-linux" system}";
          # The tarball layout mirrors a / prefix: bin/... and share/...
          installPhase = ''
            runHook preInstall

            mkdir -p $out
            cp -r bin share $out/

            # The wrapper supplies the dlopen'd graphics libraries and makes
            # sure EGL/Vulkan are found regardless of the user's setup.
            wrapProgram $out/bin/artcraft-launcher \
              --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
                mesa
                vulkan-loader
              ]}"

            runHook postInstall
          '';

          meta = with lib; {
            description = "Launcher for the Craft App Suite (PhotoCraft, FilmCraft, ...)";
            longDescription = ''
              ArtCraft Launcher lists every app in the Craft App Suite,
              installs the right build for your computer, and keeps them up
              to date.
            '';
            homepage = "https://github.com/storytold/craft-launcher";
            license = with licenses; [ asl20 mit ];
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = [ "x86_64-linux" "aarch64-linux" ];
            mainProgram = "artcraft-launcher";
          };
        };

      nixosModule =
        {
          lib,
          config,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.artcraft-launcher;
        in
        {
          options.programs.artcraft-launcher = {
            enable = lib.mkEnableOption "ArtCraft Launcher";
            package = lib.mkPackageOption self.packages.${pkgs.system} "artcraft-launcher" { };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          artcraft-launcher = pkgs.callPackage artcraft-launcher { inherit system; };
          default = self.packages.${system}.artcraft-launcher;
        }
      );

      nixosModules = {
        artcraft-launcher = nixosModule;
        default = nixosModule;
      };
    };
}
