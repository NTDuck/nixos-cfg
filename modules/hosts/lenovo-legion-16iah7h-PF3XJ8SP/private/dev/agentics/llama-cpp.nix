{den, ...}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    nixos = {
      config,
      pkgs,
      ...
    }: {
      services.llama-cpp = {
        enable = true;
        package = pkgs.unstable.llama-cpp.override {
          cudaSupport = true;
        };

        host = "127.0.0.1";
        port = 11434; # keeps zed's existing local endpoint

        # Router mode: sections are model ids, instances spawn on demand
        # with the CLI flags below; GGUFs download into LLAMA_CACHE
        # (/var/cache/llama-cpp) on first use.
        modelsPreset = {
          "openbmb/MiniCPM5-1B-GGUF:Q8_0" = {
            hf-repo = "openbmb/MiniCPM5-1B-GGUF";
            hf-file = "MiniCPM5-1B-Q8_0.gguf";
            load-on-startup = true; # 1 GB, always resident on the 3060
          };

          # eGPU (RTX 3090) class: 16.3 GB, does not fit the 6 GB 3060;
          # declared ready, loads on demand when the eGPU is attached.
          "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL" = {
            hf-repo = "unsloth/Qwen3.8-27B-GGUF";
            hf-file = "Qwen3.8-27B-UD-Q4_K_XL.gguf";
            load-on-startup = false;
          };
        };

        extraFlags = [
          # GPU-only: computation on CUDA, never CPU. --fit off so an
          # over-budget model fails loudly instead of silently falling
          # back to CPU.
          #
          # The daemon is pinned to the laptop 3060 BY UUID below (not
          # CUDA0): with the 3090 hotplugged, enumeration order flips and
          # CUDA0 would point at the eGPU — a TB cable pull then kills a
          # live CUDA context and hard-freezes the desktop. The 3090 is
          # for interactive jobs (llama-bench, ad-hoc servers).
          "--device"
          "CUDA0"
          "-ngl"
          "all"
          "--fit"
          "off"
          # mmap the GGUF: NVMe -> RAM pages pulled on demand,
          # zero CPU layer execution.
          "--load-mode"
          "mmap"
          "--flash-attn"
          "on"
          "-c"
          "8192" # cap ctx (models advertise up to 131k) to bound KV VRAM
        ];
      };

      systemd.services.llama-cpp.serviceConfig.Environment = [
        # Laptop 3060 only (see extraFlags comment above).
        "CUDA_VISIBLE_DEVICES=GPU-a81782bc-e6d4-e015-445a-d413a0e94529"
      ];

      environment.systemPackages = [
        config.services.llama-cpp.package
      ];

      # keep the existing memlock pins from the previous setup
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
