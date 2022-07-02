let
  nixpkgsRev = "29769d2a1390d294469bcc6518f17931953545e1";
  imageVersion = "8";

  nixpkgsURL = "https://github.com/NixOS/Nixpkgs/archive/${nixpkgsRev}.tar.gz";
  pkgsDefault = import (builtins.fetchTarball nixpkgsURL) { };
in
{ pkgs ? pkgsDefault }:

let
  lib = pkgs.lib;
  inherit (lib) getExe;

  mkCross = crossPkgs:
    let
      orpheusBetter =
        let
          # The programs that only need to be in path locally:
          toolPath = lib.makeBinPath (with crossPkgs; [ mktorrent flac lame sox ]);
        in
        crossPkgs.python3.pkgs.buildPythonApplication rec {
          pname = "orpheusbetter-crawler";
          version = "unstable-2022-05-18";

          src = pkgs.fetchFromGitHub {
            owner = "ApexWeed";
            repo = pname;
            rev = "e3e9fea721fa271621e4b3a5cbcf81e5f028f009";
            hash = "sha256-sgcBDCpIItU3sIjmehxYS7EgNpcPviOVl12cjKIyrRk=";
          };

          patches = [
            # When no flacs are actually found, don't crash...
            ./fix-no-flacs.patch
          ];

          # Make the version of mechanize required more forgiving
          prePatch = ''
            sed -i 's/==0.2.5/>=0.2.5/' setup.py
          '';

          postInstall = ''
            wrapProgram $out/bin/orpheusbetter --prefix PATH : "${toolPath}"
          '';

          propagatedBuildInputs = with crossPkgs.python3.pkgs;
            [ packaging mutagen requests mechanize MechanicalSoup ];
        };

      versionFile = pkgs.runCommand "versionFile" { } ''
        ${getExe pkgs.ripgrep} --replace '$1' '__version__ = "(.*)"' \
          ${orpheusBetter.src}/_version.py \
          | tr -d '\n' \
          > $out
      '';

      version = builtins.readFile versionFile;

      # Envioronment variables:
      path = lib.makeBinPath (with crossPkgs; [ busybox orpheusBetter ]);
      home = "/home/ops";

      # The entry point script:
      script = pkgs.writeScript "entrypoint" ''
        #!${getExe crossPkgs.bash}

        echo "=== DOCKER OUTPUT: ==="
        set -Eeuxo pipefail

        export PATH=${path}

        # Set up the envioronment
        mkdir -p /bin
        /bin/bash --version || ln -s ${getExe crossPkgs.bash} /bin/bash
        mkdir -p ~/.orpheusbetter
        echo ${version} > ~/.orpheusbetter/.version
        mkdir -p /tmp  # For SoX.

        # Run the script
        while :
        do
          until orpheusbetter --config /config
          do
            sleep 15 || true
          done

          if [ $reset_interval -gt 0 ]; then
            echo "=== Going to sleep ==="
            sleep $reset_interval || true
          else
            break
          fi
        done

        echo "=== DOCKER CONTAINER SHUTTING DOWN REGULARLY ==="
      '';
    in
    crossPkgs.dockerTools.buildImage {
      name =
        "orpheus-better-${orpheusBetter.version}-v${imageVersion}-${crossPkgs.system}";
      config = {
        Entrypoint = [ script ];

        Volumes = { "${home}" = { }; };
        Env = [ "HOME=${home}" "reset_interval=300" ];
      };
    };

in
builtins.listToAttrs
  (map
    (x: { name = x.system; value = mkCross x; })
    (with pkgs.pkgsCross; [ pkgs aarch64-multiplatform ]))
