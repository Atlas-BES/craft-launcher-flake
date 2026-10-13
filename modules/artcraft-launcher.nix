# NixOS module exposing `programs.artcraft-launcher.enable`.
#
# Only resolves the default package lazily inside `config` — forcing the
# `pkgs` module argument in the options block causes infinite recursion when
# merged into a NixOS configuration.
{
  self,
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

    package = lib.mkOption {
      type = lib.types.package;
      description = "The artcraft-launcher package to use.";
      defaultText = lib.literalExpression ''self.packages.''${pkgs.system}.default'';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.artcraft-launcher.package = lib.mkDefault self.packages.${pkgs.system}.default;

    # appimage-run is a required runtime dependency: the Craft apps the
    # launcher installs ship as AppImages.
    environment.systemPackages = [
      cfg.package
      pkgs.appimage-run
    ];
  };
}
