{...}: {
  den.aspects."lenovo-legion-16iah7h-PF3XJ8SP" = {
    nixos = {
      pkgs,
      lib,
      ...
    }: let
      llamaPackage = pkgs.unstable.llama-cpp.override {cudaSupport = true;};

      llamaBench2 = pkgs.buildGoModule {
        pname = "llama-bench2";
        version = "0.1.0";
        src = ./llama-bench2;
        vendorHash = null;
        ldflags = [
          "-X main.defaultLlamaBench=${llamaPackage}/bin/llama-bench"
        ];
      };
    in {
      environment.systemPackages = [
        llamaPackage
        llamaBench2
        pkgs.gum
      ];

      security.pam.loginLimits = [
        {
          domain = "@users";
          item = "memlock";
          type = "-";
          value = "unlimited";
        }
        {
          domain = "@wheel";
          item = "memlock";
          type = "-";
          value = "unlimited";
        }
      ];

      systemd.settings.Manager.DefaultLimitMEMLOCK = "infinity";
      systemd.user.extraConfig = "DefaultLimitMEMLOCK=infinity";
    };
  };
}
