{
  den,
  inputs,
  ...
}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    nixos = {pkgs, ...}: {
      # The nixos-hardware Legion profile (not included) ships the same
      # johnfanv2 `lenovo-legion-module` that firmware/lll.nix wires up.
      # hardware.nvidia.open was the profile's default; kept explicit.
      hardware.nvidia.open = true;

      # hardware.opengl = {
      #   enable = true;
      #   driSupport = true;
      # };

      hardware.nvidia = {
        modesetting.enable = true;
        nvidiaSettings = true;
        nvidiaPersistenced = true;
        powerManagement.enable = true;
      };

      services.xserver = {
        videoDrivers = ["nvidia"];
        deviceSection = ''
          Option "Coolbits" "28"
        '';
      };

      boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];
      boot.kernelParams = ["nvidia.NVreg_PreserveVideoMemoryAllocations=1"];

      environment.systemPackages = [
        pkgs.unstable.libva
        pkgs.unstable.libva-utils
        pkgs.unstable.libva-vdpau-driver
      ];

      environment.sessionVariables = {
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        LIBVA_DRIVER_NAME = "nvidia";
      };
    };
  };
}
