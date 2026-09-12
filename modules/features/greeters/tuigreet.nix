{den, ...}: {
  den.aspects.greeters.tuigreet = {command}: {
    nixos = {
      pkgs,
      config,
      ...
    }: {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = ''
              ${pkgs.tuigreet}/bin/tuigreet \
              --cmd ${command config} --no-xsession-wrapper \
              --asterisks --asterisks-char '*' \
              --time --time-format '%Y-%m-%d %H:%M:%S' \
              --remember \
              --container-padding 2 \
            '';
            user = "greeter";
          };
        };
      };

      # The eGPU adopter (firmware/egpu.nix) may rescan the tunneled GPU at
      # boot; mango's EGL init must not race that rescan — a half-
      # initialized card0 made tuigreet fall back to llvmpipe ("Fail to
      # start EGL, render software", seen 2026-09-12).
      systemd.services.greetd = {
        after = ["egpu-adopt.service"];
        wants = ["egpu-adopt.service"];
      };

      services.xserver.enable = false;
      console.earlySetup = true;
    };
  };
}
