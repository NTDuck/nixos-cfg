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

        # llama-cpp tiering runs FIRST: healthy dock or not, the env file
        # must reflect what nvidia-smi sees right now (3090 when present,
        # 3060 fallback otherwise), and the daemon restarted on flip.
        # (3090 -> weights mmap-tier RAM -> NVMe; --fit off forbids any
        # CPU layer fallback.)
        mkdir -p /run/egpu
        if ${nvidiaSmi} -L 2>/dev/null | grep -q 'RTX 3090'; then
          echo "CUDA_VISIBLE_DEVICES=GPU-a4e36250-873d-62c5-912e-fde18d238a6c" > /run/egpu/llama-cpp.env
        else
          echo "CUDA_VISIBLE_DEVICES=GPU-a81782bc-e6d4-e015-445a-d413a0e94529" > /run/egpu/llama-cpp.env
        fi

        # Healthy already: nothing else to do (udev fires this on every
        # USB4 rebind, and the boot unit fires every boot).
        if ${nvidiaSmi} -L 2>/dev/null | grep -q 'RTX 3090'; then
          $sysd try-restart llama-cpp.service 2>/dev/null || true
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

        # nvkms-ghost guard: a failed first NVRM bind leaves a half-dead
        # nvkms/Evo device behind; a later unbind/unload of it then spins
        # forever in nvEvoDisableVblankSemControl and freezes the desktop
        # (seen 3x on 2026-09-12). If the rescan rebind produced a KMS card
        # for the tunneled GPU while the first bind had failed, drop the
        # eGPU's DRM attachment (nvidia.ko compute stays); card0 removal
        # while the compositor is on the other card is verified-clean.
        if ${nvidiaSmi} -L 2>/dev/null | grep -q 'RTX 3090' \
           && [ -e /sys/class/drm/card0 ] \
           && readlink -f /sys/class/drm/card0/device 2>/dev/null | grep -q "$gpu"; then
          echo "egpu-adopt: dropping tunneled GPU's KMS attachment (nvkms ghost guard)" >&2
          echo "$gpu" > /sys/bus/pci/drivers/nvidia-drm/unbind 2>/dev/null || true
          sleep 1
        fi

        echo "egpu-adopt: restarting persistenced" >&2
        # try-restart is a no-op when the unit is stopped (it is, from step
        # 1) — use start-or-restart semantics.
        $sysd try-restart nvidia-persistenced.service 2>/dev/null || true
        $sysd start nvidia-persistenced.service 2>/dev/null || true

        # llama-cpp already follows via the tiering block at the top.

        # Final health check: NVRM init may still fail (objClInitPcieChipset
        # through the tunnel); report loudly instead of exiting clean.
        if ${nvidiaSmi} -L 2>/dev/null | grep -q 'RTX 3090'; then
          echo "egpu-adopt: 3090 alive" >&2
        else
          echo "egpu-adopt: 3090 still missing after rescan" >&2
        fi
      '';


      # Dock detach: the 3090's CUDA context must die BEFORE the tunnel
      # does. Cable pull gives no warning, so this only helps for graceful
      # teardown paths; the llama UUID pin (never CUDA0) is what makes an
      # abrupt pull survivable for the desktop.
      egpu-release = pkgs.writeShellScriptBin "egpu-release" ''
        set -eu
        sysd=${config.systemd.package}/bin/systemctl
        echo "egpu-release: reverting llama-cpp to laptop 3060" >&2
        mkdir -p /run/egpu
        echo "CUDA_VISIBLE_DEVICES=GPU-a81782bc-e6d4-e015-445a-d413a0e94529" > /run/egpu/llama-cpp.env
        $sysd try-restart llama-cpp.service 2>/dev/null || true
        $sysd stop nvidia-persistenced.service 2>/dev/null || true
        echo "egpu-release: done" >&2
      '';
    in {
      environment.systemPackages = [egpu-adopt egpu-release];

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
        # Dock detach: revert llama tiering before the tunnel is gone
        ACTION=="remove", SUBSYSTEM=="thunderbolt", ATTRS{device_name}=="UT4G", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-release.service"
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

      systemd.services.egpu-release = {
        description = "NixOS eGPU releaser: revert llama tiering on dock detach";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${egpu-release}/bin/egpu-release";
          TimeoutStartSec = "60";
        };
      };
    };
  };
}
