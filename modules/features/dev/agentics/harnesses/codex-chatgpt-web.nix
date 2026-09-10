{
  ...
}: let
  ccwVersion = "5.0.6";

  # https://github.com/miuuyy/codex-chatgpt-web — packaged desktop launcher (AppImage).
  # The AppImage is the full cross-platform launcher that owns sign-in, the embedded
  # ChatGPT browser, the Responses daemon, and MCP/tunnel supervision.
  ccwAppImage = {
    pkgs,
    lib,
  }:
    pkgs.stdenv.mkDerivation rec {
      pname = "codex-web-gpt";
      version = ccwVersion;

      src = pkgs.fetchurl {
        url = "https://github.com/miuuyy/codex-chatgpt-web/releases/download/v${version}/codex-web-gpt-${version}-linux-x64.AppImage";
        hash = "sha256-2pP/S18CIo9rGIPNlB2NpEIDBw4l2q15MGwNp3Ou+bk=";
      };

      nativeBuildInputs = [pkgs.makeWrapper];

      # AppImages are self-mounting FUSE binaries; wrap with appimage-run so no
      # FUSE kernel module / setuid helper is needed at runtime.
      dontUnpack = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin $out/share/applications
        cp $src $out/${pname}-${version}.AppImage
        chmod +x $out/${pname}-${version}.AppImage

        makeWrapper ${pkgs.appimage-run}/bin/appimage-run $out/bin/codex-web-gpt \
          --add-flags "$out/${pname}-${version}.AppImage"

        cat > $out/share/applications/codex-web-gpt.desktop <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Codex Web GPT
Comment=ChatGPT Web models inside the native Codex harness
Exec=$out/bin/codex-web-gpt
Icon=codex-web-gpt
Terminal=false
Categories=Development;
StartupWMClass=codex-web-gpt
EOF
        runHook postInstall
      '';

      meta = {
        description = "Use ChatGPT Web (including Pro) as native Codex models via an embedded browser bridge";
        homepage = "https://github.com/miuuyy/codex-chatgpt-web";
        license = lib.licenses.mit;
        mainProgram = "codex-web-gpt";
        platforms = ["x86_64-linux"];
      };
    };
in {
  den.aspects.dev.agentics.harnesses.codex-chatgpt-web = {
    nixos = {pkgs, ...}: {
      environment.systemPackages = [
        (ccwAppImage {
          inherit pkgs;
          inherit (pkgs) lib;
        })
      ];
    };
  };
}
