{
  den,
  inputs,
  ...
}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    nixos = {pkgs, ...}: {
      # The nixos-hardware profile ships johnfanv2's `lenovo-legion-module`
      # (same lenovo_legion.ko name as the toolkit driver) - replaced by
      # den.aspects.hardware.lenovo-legion-toolkit.
      # Was set by the nixos-hardware profile's Ampere defaults; keep open
      # kernel modules explicitly.
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
