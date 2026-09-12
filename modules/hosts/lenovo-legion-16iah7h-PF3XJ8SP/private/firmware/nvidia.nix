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
      boot.kernelParams = [
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        # Attempt 2026-09-12: nvidia_drm.fbdev=0 to keep fbcon off the eGPU
        # (rm external-client deadlock on unplug). REVERTED: mango/wlroots
        # then fails EGL at tuigreet and falls back to llvmpipe — the
        # compositor depends on the fbdev sideband. Freeze work continues
        # in firmware/egpu.nix instead (nvkms ghost-detection on rescan).
        # NMI watchdog: kernel hard-locks (driver spinlock deadlock)
        # self-reboot via the intel_oc_wdt hardware watchdog.
        "nmi_watchdog=1"
      ];

      # Freeze safety net: the eGPU driver-deadlock freezes the display
      # but SysRq still works — Alt+SysRq+R,E,I,S,U,B (REISUB) recovers
      # without power-cycling. Full sysrq bitmask.
      boot.kernel.sysctl."kernel.sysrq" = 1;

      environment.systemPackages = [
        pkgs.unstable.libva
        pkgs.unstable.libva-utils
        pkgs.unstable.libva-vdpau-driver
        # eGPU verification: enumerate ICDs per-arch, render on the 3090.
        pkgs.vulkan-tools
      ];

      # wine on the eGPU: DXVK/VKD3D pick the device by name; wine's WSI
      # goes through Xwayland (X11) so no special Wayland WSI needed. The
      # 32-bit NVIDIA Vulkan/GL stack ships in hardware.graphics
      # extraPackages32 (opengl-driver-32), already enabled host-wide.
      environment.sessionVariables = {
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        LIBVA_DRIVER_NAME = "nvidia";
        WINEGPU_FILTER = "NVIDIA GeForce RTX 3090";
      };
    };
  };
}
