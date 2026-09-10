{...}: {
  den.aspects."lenovo-legion-16iah7h-PF3XJ8SP" = {
    nixos = {
      pkgs,
      ...
    }: let
      llamaPackage = pkgs.unstable.llama-cpp.override {cudaSupport = true;};
    in {
      environment.systemPackages = [
        llamaPackage
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
