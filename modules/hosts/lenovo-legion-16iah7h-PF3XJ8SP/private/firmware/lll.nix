{...}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    nixos = {
      config,
      pkgs,
      ...
    }: {
      # https://github.com/johnfanv2/LenovoLegionLinux — nixpkgs packaging:
      # `lenovo-legion` app (legion_gui, legion_cli) + `lenovo-legion-module`
      # (legion-laptop.ko, renamed from lenovo_legion.ko). Both at 0.0.22:
      # the app comes from unstable to match the module version packaged in
      # the CachyOS kernel package set.
      environment.systemPackages = [pkgs.unstable.lenovo-legion];

      boot.extraModulePackages = [config.boot.kernelPackages.lenovo-legion-module];
      boot.kernelModules = ["legion_laptop"];

      # legion-laptop binds Lenovo's WMI gamezone/capdata/hotkey GUIDs itself,
      # so the in-kernel equivalents must stay unloaded or they claim the
      # device first.
      boot.extraModprobeConfig = ''
        blacklist ideapad_acpi
        blacklist ideapad_laptop
        blacklist lenovo_wmi_events
        blacklist lenovo_wmi_hotkey_utilities
        blacklist lenovo_wmi_other
        blacklist lenovo_wmi_capdata01
        blacklist lenovo_wmi_gamezone
        blacklist lenovo_wmi_helpers
        blacklist lenovo_wmi_capdata
      '';

      # [[1]] In [[Fan Curve]], apply [[performance-ac]] preset + [Minifancurve if too cold]
      # [[2]] In [[Other Options]], apply:
      # | Configuration                        | Default   | Custom   |
      # | ------------------------------------ | --------- | -------: |
      # | CPU Long Term Power Limit [W] (PL1)  |        60 |      115 |
      # | CPU Short Term Power Limit [W] (PL2) | 45/80/135 |      135 |
      # | CPU Peak Power Limit [W]             |         0 |        0 |
      # | CPU Cross Loading Power Limit [W]    |         0 |        0 |
      # | CPU APU SPPT Power Limit [W]         |         0 |        0 |
      # | GPU cTGP Power Limit [W]             |         0 |      140 |
      # | GPU PPAB Power Limit [W]             |        15 |       25 |
      # | GPU Temperature Limit [°C]           |         0 |       90 |
    };
  };
}
