{den, ...}: {
  den.aspects.gaming.wine = {
    nixos = {pkgs, ...}: {
      environment.systemPackages = [
        pkgs.unstable.wine-wayland
        pkgs.unstable.winetricks
        pkgs.unstable.wineWow64Packages.stableFull
        # DXVK/VKD3D route Vulkan by device; without a filter wine lands on
        # the first enumerated GPU (the laptop 3060) and games render there
        # while the eGPU idles. wine3090 forces the docked RTX 3090 for the
        # wow64/X11 launcher; plain `wine` keeps default behavior.
        (pkgs.writeShellScriptBin "wine3090" ''
          export DXVK_FILTER_DEVICE_NAME="NVIDIA GeForce RTX 3090"
          export VKD3D_FILTER_DEVICE_NAME="NVIDIA GeForce RTX 3090"
          # GL games (wine's wgl) follow the GLX vendor: force NVIDIA.
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          exec "${pkgs.unstable.wineWow64Packages.stableFull}/bin/wine" "$@"
        '')
        (pkgs.writeShellScriptBin "wine3090-wayland" ''
          export DXVK_FILTER_DEVICE_NAME="NVIDIA GeForce RTX 3090"
          export VKD3D_FILTER_DEVICE_NAME="NVIDIA GeForce RTX 3090"
          exec "${pkgs.unstable.wine-wayland}/bin/wine" "$@"
        '')
      ];
    };
  };
}
