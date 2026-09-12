{
  ...
}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    nixos = {
      config,
      pkgs,
      ...
    }: let
      # UT3G (ASM2464PDX) eGPU bring-up has two quirks this unit papers over:
      # 1. The first NVRM bind after a USB4 link train can fail with
      #    "objClInitPcieChipset: Unable to get PCI port handles" (IO-port
      #    handles lost through the tunnel). A PCI remove/rescan rebinds
      #    cleanly.
      # 2. nvidia-persistenced enumerated GPUs at its own startup and never
      #    adopts hotplugged devices, so nvidia-smi/NVML hide the 3090 until
      #    the daemon restarts.
      # 3. The original udev rules matched only ACTION=="add". With the dock
      #    attached at power-on, boltd re-authorizes ("changed", not "add")
      #    and the tunneled PCI device appears before this generation's rule
      #    is loaded — the uevent is never replayed, egpu-adopt never runs,
      #    /dev/nvidia1 never appears, and CUDA/Vulkan/DXVK see only the
      #    3060 + llvmpipe (seen 2026-09-12 boot d2a56796). ACTION!=remove
      #    matches coldplug replay and every rebind; a multi-user.target
      #    boot trigger covers the pre-udevd window outright.
      # Freeze-safe surgery order (a naive remove/rescan of a live-bound GPU
      # hard-freezes the desktop — seen 2026-09-12):
      #  1. stop persistenced (drops NVML handles; it can't adopt hotplugs
      #     anyway, and a live NVML client on the GPU blocks unbind)
      #  2. unbind nvidia from the 3090 BEFORE removing it
      #  3. remove + rescan, wait for a clean rebind
      #  4. restart persistenced last so NVML enumerates both GPUs
      nvidiaSmi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
      egpu-adopt = pkgs.writeShellScriptBin "egpu-adopt" ''
        set -eu
        gpu="0000:06:00.0"
        sysd=${config.systemd.package}/bin/systemctl

        # Healthy already: nothing to do (udev fires this on every USB4
        # rebind, and the boot unit fires every boot).
        if ${nvidiaSmi} -L 2>/dev/null | grep -q 'RTX 3090'; then
          exit 0
        fi

        # Wait for the tunneled GPU to appear behind the ASM2464 bridge
        # (bolt authorizes -> tunnel -> 04:00.0 -> 05:00.0 -> 06:00.0).
        # Late arrivals are covered by the udev rule; don't sit here long.
        for _ in $(seq 1 5); do
          [ -e "/sys/bus/pci/devices/$gpu" ] && break
          sleep 1
        done
        [ -e "/sys/bus/pci/devices/$gpu" ] || {
          echo "egpu-adopt: $gpu never appeared" >&2
          exit 0
        }

        echo "egpu-adopt: quiescing NVML clients" >&2
        $sysd stop nvidia-persistenced.service 2>/dev/null || true

        # Unbind first if the driver claimed it (echoing remove into a
        # bound nvidia device can wedge the DRM stack).
        if [ -d "/sys/bus/pci/devices/$gpu/driver" ]; then
          echo "egpu-adopt: unbinding nvidia from $gpu" >&2
          echo "$gpu" > /sys/bus/pci/drivers/nvidia/unbind 2>/dev/null || true
          for _ in $(seq 1 10); do
            [ -d "/sys/bus/pci/devices/$gpu/driver" ] || break
            sleep 1
          done
        fi

        echo "egpu-adopt: rescanning $gpu" >&2
        echo 1 > "/sys/bus/pci/devices/$gpu/remove" 2>/dev/null || true
        echo 1 > /sys/bus/pci/rescan
        for _ in $(seq 1 15); do
          [ -e "/sys/bus/pci/devices/$gpu/driver" ] && break
          sleep 1
        done

        echo "egpu-adopt: restarting persistenced" >&2
        # try-restart is a no-op when the unit is stopped (it is, from step
        # 1) — use start-or-restart semantics.
        $sysd try-restart nvidia-persistenced.service 2>/dev/null || true
        $sysd start nvidia-persistenced.service 2>/dev/null || true

        # Final health check: NVRM init may still fail (objClInitPcieChipset
        # through the tunnel); report loudly instead of exiting clean.
        if ${nvidiaSmi} -L 2>/dev/null | grep -q 'RTX 3090'; then
          echo "egpu-adopt: 3090 alive" >&2
        else
          echo "egpu-adopt: 3090 still missing after rescan" >&2
          exit 1
        fi
      '';
    in {
      environment.systemPackages = [egpu-adopt];

      # Fires when boltd authorizes a new Thunderbolt/USB4 device (the UT3G
      # router 0-1), then again on the tunneled PCI device appearance.
      # ACTION!=remove also matches coldplug replay and boltd's
      # "authorized -> authorized" change events, which the old
      # ACTION=="add" rules missed when the dock was attached at power-on.
      services.udev.extraRules = ''
        # Thunderbolt router (boltctl authorizes -> kernel creates the router)
        ACTION!="remove", SUBSYSTEM=="thunderbolt", ATTRS{device_name}=="UT4G", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-adopt.service"
        # Tunneled NVIDIA GPU appearance (belt & braces if bolt already stored)
        ACTION!="remove", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ENV{PCI_SLOT_NAME}=="0000:06:00.0", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-adopt.service"
      '';

      systemd.services.egpu-adopt = {
        description = "NixOS eGPU adopter: rescan tunneled 3090 and refresh NVML";
        after = ["bolt.service" "nvidia-persistenced.service"];
        wants = ["bolt.service"];
        # Boot trigger: covers the window where the tunneled GPU appears
        # before udev rules are loaded (no uevent is replayed into a rule
        # that wasn't loaded yet). Dock-less boots skip via the condition.
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathExists = "/sys/bus/pci/devices/0000:06:00.0";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${egpu-adopt}/bin/egpu-adopt";
          # Tunnel bring-up races bolt authorization; give it room.
          TimeoutStartSec = "120";
        };
      };
    };
  };
}
