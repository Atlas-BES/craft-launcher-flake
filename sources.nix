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
  version = "0.4.0";
  tag = "v0.4.0";

  perSystem = {
    x86_64-linux.hash = "sha256-9cG5HhSZfQMYlEzf6INmzVBQYcO/OTVpkS/vd3YEFDI=";
    aarch64-linux.hash = "sha256-21me8n5Cjl8qhHIJ0f8pe/HSXjqJi3QES45mRP0F6Xc=";
  };

  # URL template; `arch` is the tarball arch ("x86_64", "aarch64"), i.e. the
  # nix system string minus the "-linux" suffix.
  urlOf =
    arch: tag: version:
    "https://github.com/storytold/craft-launcher/releases/download/${tag}/artcraft-launcher-${version}-linux-${arch}.tar.gz";
}
