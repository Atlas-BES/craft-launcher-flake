# Overlay making `pkgs.artcraft-launcher` available.
#
# Apply via:
#   nixpkgs.overlays = [ inputs.<name>.overlays.default ];
{ self }:
final: prev: {
  artcraft-launcher =
    if self.packages ? ${final.system} then
      self.packages.${final.system}.default
    else
      throw "artcraft-launcher is not available for ${final.system}";
}
