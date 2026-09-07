{den, ...}: {
  den.aspects."lenovo-legion-16iah7h-PF3XJ8SP" = {
    nixos = {pkgs, ...}: let
      llamaPackage = pkgs.unstable.llama-cpp.override {cudaSupport = true;};

      llamaBenchMonitor = pkgs.writeShellScriptBin "llama-bench-monitor" ''
        set -euo pipefail

        TARGET="auto"
        MODEL=""
        PRESET=""
        HORIZON="long"
        STRESS=0
        INTERVAL="1"
        EXTRA_ARGS=()

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --target) TARGET="$2"; shift 2 ;;
            --model|-m) MODEL="$2"; shift 2 ;;
            --preset) PRESET="$2"; shift 2 ;;
            --horizon) HORIZON="$2"; shift 2 ;;
            --stress) STRESS=1; shift ;;
            --interval) INTERVAL="$2"; shift 2 ;;
            --help|-h)
              echo "Usage: llama-bench-monitor [options] [-- extra llama-bench args...]"
              echo "  --target <3060|3090|auto|<idx>>  Select target GPU (default: auto)"
              echo "  --preset <3060|3090>             3060 (6GB VRAM) or 3090 (24GB eGPU)"
              echo "  --model <path_or_hf_repo>        Local GGUF or HF repo:quant"
              echo "  --horizon <short|medium|long>    Context workload length (default: long)"
              echo "  --stress                         Stress test (sustained repetitions & context)"
              echo "  --interval <seconds>             Telemetry sample rate (default: 1)"
              exit 0
              ;;
            --) shift; EXTRA_ARGS+=("$@"); break ;;
            *) EXTRA_ARGS+=("$1"); shift ;;
          esac
        done

        GPU_ID=0
        GPU_NAME="Default GPU"

        if command -v nvidia-smi >/dev/null 2>&1; then
          GPUS=$(nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader)
          if [[ "$TARGET" == "3090" ]]; then
            MATCH=$(echo "$GPUS" | grep -i "3090" | head -n1 || true)
            [[ -n "$MATCH" ]] && GPU_ID=$(echo "$MATCH" | cut -d',' -f1 | tr -d ' ')
          elif [[ "$TARGET" == "3060" ]]; then
            MATCH=$(echo "$GPUS" | grep -i "3060" | head -n1 || true)
            [[ -n "$MATCH" ]] && GPU_ID=$(echo "$MATCH" | cut -d',' -f1 | tr -d ' ')
          elif [[ "$TARGET" =~ ^[0-9]+$ ]]; then
            GPU_ID="$TARGET"
          else
            MATCH_3090=$(echo "$GPUS" | grep -i "3090" | head -n1 || true)
            if [[ -n "$MATCH_3090" ]]; then
              GPU_ID=$(echo "$MATCH_3090" | cut -d',' -f1 | tr -d ' ')
              [[ -z "$PRESET" ]] && PRESET="3090"
            fi
          fi
          GPU_NAME=$(echo "$GPUS" | grep "^$GPU_ID," | cut -d',' -f2 | sed 's/^ *//' || echo "GPU $GPU_ID")
        fi

        [[ -z "$PRESET" ]] && PRESET=$([[ "$GPU_NAME" =~ 3090 ]] && echo "3090" || echo "3060")

        if [[ "$STRESS" -eq 1 ]]; then
          if [[ "$PRESET" == "3090" ]]; then
            CTX_ARGS=(-p 4096,8192,16384 -n 512 -fa 1 -r 5)
          else
            CTX_ARGS=(-p 2048,4096,8192 -n 512 -fa 1 -r 5)
          fi
        else
          case "$HORIZON" in
            short)  CTX_ARGS=(-p 512,1024 -n 128) ;;
            medium) CTX_ARGS=(-p 1024,2048,4096 -n 256 -fa 1) ;;
            long)
              if [[ "$PRESET" == "3090" ]]; then
                CTX_ARGS=(-p 4096,8192,16384 -n 512 -fa 1)
              else
                CTX_ARGS=(-p 2048,4096,8192 -n 256 -fa 1)
              fi
              ;;
            *) CTX_ARGS=() ;;
          esac
        fi

        LOCAL_QWEN35_4B=$(find "$HOME/.cache/huggingface/hub" -name "*Qwen3*4B*Q4*.gguf" 2>/dev/null | head -n1 || true)

        if [[ "$PRESET" == "3090" ]]; then
          if [[ -z "$MODEL" ]]; then
            MODEL_ARGS=(-hf "unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M")
          elif [[ -f "$MODEL" ]]; then
            MODEL_ARGS=(-m "$MODEL")
          else
            MODEL_ARGS=(-hf "$MODEL")
          fi
          NGL_ARGS=(-ngl 99)
        else
          # 3060 (6GB VRAM)
          if [[ -z "$MODEL" ]]; then
            if [[ -n "$LOCAL_QWEN35_4B" && -f "$LOCAL_QWEN35_4B" ]]; then
              MODEL_ARGS=(-m "$LOCAL_QWEN35_4B")
            else
              MODEL_ARGS=(-hf "unsloth/Qwen3.5-4B-GGUF:Q4_K_M")
            fi
          elif [[ -f "$MODEL" ]]; then
            MODEL_ARGS=(-m "$MODEL")
          else
            MODEL_ARGS=(-hf "$MODEL")
          fi
          NGL_ARGS=(--fit-target 1500)
        fi

        TMP_DIR=$(mktemp -d)
        TELEMETRY_LOG="$TMP_DIR/telemetry.csv"

        cleanup() {
          if [[ -n "''${TELEMETRY_PID:-}" ]] && kill -0 "$TELEMETRY_PID" 2>/dev/null; then
            kill "$TELEMETRY_PID" 2>/dev/null || true
            wait "$TELEMETRY_PID" 2>/dev/null || true
          fi
          rm -rf "$TMP_DIR"
        }
        trap cleanup EXIT INT TERM

        if command -v nvidia-smi >/dev/null 2>&1; then
          (
            while true; do
              nvidia-smi --id="$GPU_ID" --query-gpu=temperature.gpu,power.draw,utilization.gpu,memory.used --format=csv,noheader,nounits >> "$TELEMETRY_LOG" 2>/dev/null || true
              sleep "$INTERVAL"
            done
          ) &
          TELEMETRY_PID=$!
        fi

        START_TIME=$(date +%s)
        set +e
        CUDA_VISIBLE_DEVICES="$GPU_ID" ${llamaPackage}/bin/llama-bench \
          "''${MODEL_ARGS[@]}" \
          "''${NGL_ARGS[@]}" \
          "''${CTX_ARGS[@]}" \
          "''${EXTRA_ARGS[@]}"
        BENCH_EXIT_CODE=$?
        set -e
        DURATION=$(($(date +%s) - START_TIME))

        if [[ -n "''${TELEMETRY_PID:-}" ]] && kill -0 "$TELEMETRY_PID" 2>/dev/null; then
          kill "$TELEMETRY_PID" 2>/dev/null || true
          wait "$TELEMETRY_PID" 2>/dev/null || true
          unset TELEMETRY_PID
        fi

        if [[ -f "$TELEMETRY_LOG" && -s "$TELEMETRY_LOG" ]]; then
          echo ""
          echo "================================================================================"
          echo " GPU Thermal & Power Telemetry Summary (Duration: ''${DURATION}s)"
          echo "================================================================================"
          awk -F', ' '
            NR == 1 { init_t = min_t = max_t = $1; min_p = max_p = $2; max_mem = $4 }
            {
              t = $1 + 0; p = $2 + 0; u = $3 + 0; m = $4 + 0
              sum_t += t; sum_p += p; sum_u += u; count++
              if (t > max_t) max_t = t
              if (t < min_t) min_t = t
              if (p > max_p) max_p = p
              if (m > max_mem) max_mem = m
            }
            END {
              if (count > 0) {
                printf " Initial Temperature : %d °C\n", init_t
                printf " Minimum Temperature : %d °C\n", min_t
                printf " Peak Temperature    : %d °C (ΔT: +%d °C)\n", max_t, max_t - init_t
                printf " Average Temperature : %.1f °C\n", sum_t / count
                printf " Peak Power Draw     : %.1f W\n", max_p
                printf " Average Power Draw  : %.1f W\n", sum_p / count
                printf " Peak VRAM Used      : %d MiB\n", max_mem
                printf " Average Utilization : %.1f %%\n", sum_u / count
              }
            }
          ' "$TELEMETRY_LOG"
          echo "================================================================================"
        fi

        exit $BENCH_EXIT_CODE
      '';
    in {
      environment.systemPackages = [
        llamaPackage
        llamaBenchMonitor
      ];

      security.pam.loginLimits = [
        { domain = "@users"; item = "memlock"; type = "-"; value = "unlimited"; }
        { domain = "@wheel"; item = "memlock"; type = "-"; value = "unlimited"; }
      ];

      systemd.settings.Manager.DefaultLimitMEMLOCK = "infinity";
      systemd.user.extraConfig = "DefaultLimitMEMLOCK=infinity";
    };
  };
}
