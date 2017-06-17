{ stdenv, bash, curl, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "scaleways-scripts";
  src = fetchFromGitHub {
    owner = "scaleway";
    repo = "image-tools";
    rev = "a1124e472e1d45d7697c56abaf43947e609ff44c";
    sha256 = "0iiqqsc0k4aqdql0kwc59zdsf790a5a140dpkscx955jdkjxsixd";
  };
  installPhase = ''
    mkdir -p $out/bin
    cp skeleton-common/usr/local/{s,}bin/scw-* $out/bin/
  '';
  fixupPhase = ''
    sed --in-place --expression=s#'/usr/local/s\?bin/scw-'#"$out/bin/scw-"#g \
      $out/bin/*
  '';
}
