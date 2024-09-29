{ pkgs
, fetchFromGitHub
, linux
, lib
, stdenv
}:
let
  name = "wsl2-linux-kernel";
  arch =
    if pkgs.system == "aarch64-linux" then
      "arm64"
    else if pkgs.system == "x86_64-linux" then
      "amd64"
    else
      throw "Unsupported system ${pkgs.system}";
  versions = (lib.importJSON ./versions.json).kernels;
  listNthAt = l: n: builtins.elemAt l n;
  kVersion = builtins.substring 15 24 ((listNthAt versions 0).kernel.tag);
  zfsVersion = builtins.substring 4 10 ((listNthAt versions 0).modules.zfs.tag);
in
stdenv.mkDerivation {
  name = "${name}-kver-${kVersion}-zfs-${zfsVersion}";

  src = fetchFromGitHub {
    owner = "Microsoft";
    repo = "WSL2-Linux-Kernel";
    rev = (listNthAt versions 0).kernel.tag;
    sha256 = (listNthAt versions 0).kernel.sha256;
  };

  makeFlags = [ "KCONFIG_CONFIG=Microsoft/config-wsl" ];
  nativeBuildInputs = linux.nativeBuildInputs;

  enableParallelBuilding = true;

  postPatch = ''
    patchShebangs ./scripts/bpf_doc.py;
  '';

  installPhase = ''
    mkdir -p $out
    cp arch/${if arch == "arm64" then
      "arm64"
      else if arch == "amd64" then
        "x86"
      else throw "This error shouldn't happen - please open a bug report"}/boot/bzImage $out/bzImage-${arch}
  '';
}
