let
  nixpkgsRev = "c0e881852006b132236cbf0301bd1939bb50867e";
  imageVersion = "4";

  nixpkgsURL = "https://github.com/NixOS/Nixpkgs/archive/${nixpkgsRev}.tar.gz";
  pkgsDefault =
    import (builtins.fetchTarball nixpkgsURL) { system = "x86_64-linux"; };
in { pkgs ? pkgsDefault }:

with pkgs;
let
  orpheusBetter = let
    # The programs that only need to be in path locally:
    toolPath = lib.makeBinPath [ mktorrent flac lame sox ];
  in with python3.pkgs;
  buildPythonApplication rec {
    pname = "orpheusbetter-crawler";
    version = "unstable-2021-04-03";

    src = fetchFromGitHub {
      owner = "ApexWeed";
      repo = pname;
      rev = "b539b0566224da236a65533b8bae28ca6211a82a";
      sha256 = "0d5s3zqm2k9qj51xsxnayzg5agf697bq7hp58vdnwj0q04yqi6q7";
    };

    # Make the version of mechanize required more forgiving
    prePatch = ''
      sed -i 's/==0.2.5/>=0.2.5/' setup.py
    '';

    postInstall = ''
      wrapProgram $out/bin/orpheusbetter --prefix PATH : "${toolPath}"
    '';

    propagatedBuildInputs = [ mutagen requests mechanize MechanicalSoup ];
  };

  versionFile = runCommand "versionFile" { } ''
    ${ripgrep}/bin/rg --replace '$1' '__version__ = "(.*)"' \
      ${orpheusBetter.src}/_version.py \
      | tr -d '\n' \
      > $out
  '';

  version = builtins.readFile versionFile;

  # Envioronment variables:
  path = lib.makeBinPath [ busybox orpheusBetter ];
  home = "/home/ops";

  # The entry point script:
  script = writeScript "entrypoint" ''
    #!${bash}/bin/bash

    echo "=== DOCKER OUTPUT: ==="
    set -Eeuxo pipefail

    export PATH=${path}

    # Set up the envioronment
    mkdir -p ~/.orpheusbetter
    echo ${version} > ~/.orpheusbetter/.version

    # Run the script
    while :
    do
      orpheusbetter --config /config
      if [ $reset_interval -gt 0 ]; then
        echo "=== Going to sleep ==="
        sleep $reset_interval
      else
        break
      fi
    done

    echo "=== DOCKER CONTAINER SHUTTING DOWN REGULARLY ==="
  '';

in dockerTools.buildImage {
  name = "orpheus-better-${orpheusBetter.version}-v${imageVersion}";
  config = {
    Entrypoint = [ script ];

    Volumes = { "${home}" = { }; };
    Env = [ "HOME=${home}" "reset_interval=3600" ];
  };
}
