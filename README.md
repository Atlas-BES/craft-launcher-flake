# craft-launcher-flake

NixOS flake that installs [ArtCraft Launcher](https://github.com/storytold/craft-launcher)
declaratively — from the official prebuilt `.tar.gz` releases, with all
runtime dependencies pinned in the store.

## Features

Installs the official prebuilt `.tar.gz` release with verified SHA256 hashes
for `x86_64-linux` and `aarch64-linux`. Every runtime dependency is declared
and supplied by the package (glibc/libgcc via `autoPatchelfHook`; the wgpu
renderer's `mesa`/`vulkan-loader` and winit's `wayland`/`libx11`/`libxcursor`/
`libxi`/`libxrandr`/`libxkbcommon` via rpath and wrapper), plus
`appimage-run` for the AppImages the Craft apps ship as. Includes a proper
desktop entry and icon set.

## Why the launcher and not individual apps?

The Craft App Suite (PhotoCraft, FilmCraft, WordCraft, ...) is **rapidly
evolving** — versions move fast and packaging each app individually in Nix
would be a constant chase.

This flake makes the *launcher* the single declarative entry point:

- **One input, whole suite** — a single flake input gives you the ability to
  view, install, and update all new Craft Apps instead of adding a single package
  whenever a new app is released, and when an update is released you can instantly
  update from the launcher.
- **Commit-pinning for security** — launcher does not have to be constantly
- updated, so flake inputs can lock to a commit and hash, and what lands 
  in your system is exactly what you reviewed. Nothing updates
  behind your back.

## The apps are not declarative?
The launcher pulls the appimages of the applications and puts them in your $USER folder, some people may not like this approach.
As of right now, individual apps can not be configured or declaratively installed from your configuration, this is subject to change.

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
