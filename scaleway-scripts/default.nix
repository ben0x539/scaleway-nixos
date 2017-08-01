{ lib, stdenv, fetchFromGitHub, bash, curl, wget, gnused, gnugrep,
  gzip, # zcat
  openssh, # ssh-keygen
  utillinux, # fallocate?
  kmod, # depmod?
}:

let
  deps = [ curl wget gnused gnugrep ];
  path = lib.makeBinPath deps;
in

stdenv.mkDerivation rec {
  name = "scaleways-scripts";
  src = fetchFromGitHub {
    owner = "scaleway";
    repo = "image-tools";
    rev = "0a76640703b0caab371ddc5e9b68d4c281aa5570";
    sha256 = "1f27p0cqfqdbaw3ifpj8qxmil8zhprvh18y13pmc1nhbf6sa60lv";
  };
  installPhase = ''
    mkdir -p $out/bin
    cp skeleton-common/usr/local/{s,}bin/scw-* $out/bin/
  '';
  fixupPhase = ''
    sed --in-place --expression="
        s#/usr/local/s\\?bin/scw-#$out/bin/scw-#g;
        s#hash curl 2>/dev/null#type -P curl >/dev/null#g;
        s#export PATH=.*#export PATH=${path}:$PATH#;
      " $out/bin/*
  '';
}
