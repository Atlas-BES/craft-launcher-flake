# craft-launcher-flake

NixOS flake that installs [ArtCraft Launcher](https://github.com/storytold/craft-launcher)
declaratively — from the official prebuilt `.tar.gz` releases, with all
runtime dependencies pinned in the store.

## Features

- **Latest release, pinned** — pulls `artcraft-launcher-<version>-linux-<arch>.tar.gz`
  from upstream GitHub releases, with SHA256 hashes verified per architecture
  (`x86_64-linux`, `aarch64-linux`)
- **Dependencies declared** — the binary links `glibc` + `libgcc_s` directly
  and `dlopen`s the rest at runtime, all supplied by the package:
  - `mesa`, `vulkan-loader` — wgpu renderer (libEGL / libvulkan)
  - `wayland`, `libx11`, `libxcursor`, `libxi`, `libxrandr`,
    `libxkbcommon` — winit windowing (Wayland and X11)
- **Clean ELF patching** — `autoPatchelfHook` re-points the interpreter and
  rpath to Nix's glibc; no reliance on `/lib64`
- **Desktop integration** — ships a proper desktop entry (name without
  version, description, `PackageManager` category) plus the upstream hicolor
  icon set (16–512px PNG + SVG)
- **`appimage-run` included** — the Craft apps the launcher installs ship as
  AppImages, so `appimage-run` is treated as a required dependency: it is
  added to the launcher's PATH by the package wrapper and installed
  system-wide by the NixOS module

## Repository layout

```
flake.nix                          thin wiring: inputs -> outputs
sources.nix                        release metadata: version, URLs, hashes
packages/artcraft-launcher.nix     the package derivation
packages/artcraft-launcher.desktop desktop entry
                                   (requires appimage-run, see Features)
modules/artcraft-launcher.nix      NixOS module (programs.artcraft-launcher)
overlays/default.nix               overlay exposing pkgs.artcraft-launcher
```

## Usage

### Option A: overlay

```nix
# flake.nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  craftlauncher.url = "github:Atlas-BES/craft-launcher-flake";
};

outputs = { self, nixpkgs, craftlauncher, ... }: {
  nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [ ./configuration.nix ];
  };
};
```

```nix
# configuration.nix
{ inputs, ... }: {
  nixpkgs.overlays = [ inputs.craftlauncher.overlays.default ];
  environment.systemPackages = [ pkgs.artcraft-launcher ];
}
```

### Option B: module

```nix
# in nixosSystem modules:
craftlauncher.nixosModules.default
({ ... }: { programs.artcraft-launcher.enable = true; })
```

> **Note:** NixOS *modules* (`nixosModules.default`) go in the host's
> `modules` list (or in `imports`); *overlays* (`overlays.default`) go in
> `nixpkgs.overlays`. Mixing them up causes "infinite recursion" errors.

Then:

```sh
sudo nixos-rebuild switch --flake .#myhost
```

The launcher appears in your app menu as **ArtCraft Launcher** with its icon
and description, and is runnable as `artcraft-launcher`. `appimage-run` is
installed system-wide as well (required to run the Craft apps).

With the overlay approach (Option A), the wrapper inside the
`artcraft-launcher` package supplies `appimage-run` automatically; add
`pkgs.appimage-run` to `systemPackages` yourself if other tooling should see
it on the system PATH.

## Try without installing

```sh
nix run github:Atlas-BES/craft-launcher-flake
```

## Updating

1. Bump `version` and `tag` in [`sources.nix`](sources.nix)
2. Update the per-system hashes from the release's `SHA256SUMS.txt`:

   ```sh
   nix hash convert --to base64 --hash-algo sha256 <hex-digest>
   ```

3. `nix build && nix flake check`, commit and push

## Acknowledgements

- [ArtCraft Launcher](https://github.com/storytold/craft-launcher) by
  [Learning Machines LLC / storytold](https://github.com/storytold) —
  MIT OR Apache-2.0 (see the launcher's bundled licenses)
