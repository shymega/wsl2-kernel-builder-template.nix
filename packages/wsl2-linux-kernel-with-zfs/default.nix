{ pkgs
, fetchFromGitHub
, lib
, stdenv
}:
let
  wsl2-linux-kernel-base = import ../wsl2-linux-kernel-base { inherit pkgs lib; };
  kernelTag = builtins.substring 15 24 "linux-msft-wsl-6.6.36.6";
  kernelSha256 = "0sjkj939h47yi2n4kn5058k6qrpl5xipxdf1nl3r96d5xarxjcpa";
  kernelZfsTag = builtins.substring 4 10 "zfs-2.2.6";

  arch =
    if pkgs.system == "aarch64-linux" then
      "arm64"
    else if pkgs.system == "x86_64-linux" then
      "amd64"
    else
      throw "Unsupported system ${pkgs.system}";

  inherit (wsl2-linux-kernel-base) mkBaseKernel;

  version = "kv${kernelTag}-zfsv${kernelZfsTag}";

  src = fetchFromGitHub {
    owner = "Microsoft";
    repo = "WSL2-Linux-Kernel";
    rev = kernelTag;
    sha256 = kernelSha256;
  };

  extraConfig = with lib.kernel;{
    CONFIG_KERNEL_ZSTD = yes;

    CONFIG_MODULE_COMPRESS_ZSTD = yes;

    CONFIG_ZPOOL = yes;
    CONFIG_ZSWAP = yes;
    CONFIG_ZSWAP_COMPRESSOR_DEFAULT_ZSTD = yes;

    CONFIG_CRYPTO_842 = module;
    CONFIG_CRYPTO_LZ4 = module;
    CONFIG_CRYPTO_LZ4HC = module;
    CONFIG_CRYPTO_ZSTD = yes;

    CONFIG_ZRAM_DEF_COMP_ZSTD = yes;
    CONFIG_ZRAM_WRITEBACK = yes;
    CONFIG_ZRAM_MULTI_COMP = yes;
  };

  kernel = mkBaseKernel {
    inherit src extraConfig;
    version = kernelTag;
  };
in
stdenv.mkDerivation {
  name = "wsl2-linux-kernel-with-zfs";
  inherit version src;

  makeFlags = [ "KCONFIG_CONFIG=Microsoft/config-wsl" ];
  inherit (kernel) nativeBuildInputs buildInputs;

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
