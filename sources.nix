# Release metadata for the upstream prebuilt binaries.
#
# The flake installs ArtCraft Launcher from the official .tar.gz releases of
# https://github.com/storytold/craft-launcher. One tarball per supported
# architecture.
#
# To update: bump `version`, then refresh each hash from the release's
# SHA256SUMS.txt:
#   nix hash convert --to base64 --hash-algo sha256 <hex-digest>
{
  version = "0.4.1";
  tag = "v0.4.1";

  perSystem = {
    x86_64-linux.hash = "sha256-Ki7lHWm9uBdKKkjzApf9v6RgtuhzfDVmobbsRvgx+kA=";
    aarch64-linux.hash = "sha256-20iCpVxNVDZFFT8oNySqDmIy9BK/q9UljssBdjD0oQQ=";
  };

  # URL template; `arch` is the tarball arch ("x86_64", "aarch64"), i.e. the
  # nix system string minus the "-linux" suffix.
  urlOf =
    arch: tag: version:
    "https://github.com/storytold/craft-launcher/releases/download/${tag}/artcraft-launcher-${version}-linux-${arch}.tar.gz";
}
