{den, ...}: {
  den.aspects.firmware.openrgb = {
    nixos = {pkgs, ...}: {
      services.hardware.openrgb = {
        enable = true;
        package = pkgs.unstable.openrgb;
      };
    };
  };
}
