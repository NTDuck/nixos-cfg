{...}: {
  den.aspects."lenovo-legion-16iah7h-PF3XJ8SP" = {
    nixos = {
      pkgs,
      lib,
      ...
    }: let
      llamaPackage = pkgs.unstable.llama-cpp.override {cudaSupport = true;};

      llamaBench2 = pkgs.writeShellScriptBin "llama-bench2" ''
        set -euo pipefail

        export PATH="${lib.makeBinPath [
          pkgs.gum
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
          pkgs.findutils
        ]}:/run/current-system/sw/bin:$PATH"

        NVIDIA_SMI=$(command -v nvidia-smi || echo "/run/current-system/sw/bin/nvidia-smi")
        LLAMA_BENCH="${llamaPackage}/bin/llama-bench"

        TARGET_GPU=""
        MODEL=""
        STRESS=0
        REPETITIONS=""
        INTERVAL="1"
        INTERACTIVE=0
        EXTRA_ARGS=()
        CUSTOM_TESTS=()
        OFFLOAD_ARGS=()
        FA_ARG="-fa 1"
        KV_ARG=""

        bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
        dim()   { printf "\033[2m%s\033[0m\n" "$*"; }
        step()  { printf "  \033[1m%-7s\033[0m %s\n" "$1" "$2"; }
        check() { printf "  \033[32m✓\033[0m \033[1m%-7s\033[0m %s\n" "$1" "$2"; }

        if [[ $# -eq 0 ]] && [[ -t 0 ]]; then
          INTERACTIVE=1
        fi

        while [[ $# -gt 0 ]]; do
          case "$1" in
            --interactive|-i)
              INTERACTIVE=1
              shift
              ;;
            --gpu|--target)
              TARGET_GPU="$2"
              shift 2
              ;;
            --model|-m)
              MODEL="$2"
              shift 2
              ;;
            --stress)
              STRESS=1
              shift
              ;;
            -r|--repetitions)
              REPETITIONS="$2"
              shift 2
              ;;
            --fit-target)
              OFFLOAD_ARGS=(--fit-target "$2")
              shift 2
              ;;
            -ngl|--n-gpu-layers)
              OFFLOAD_ARGS=(-ngl "$2")
              shift 2
              ;;
            --interval)
              INTERVAL="$2"
              shift 2
              ;;
            --help|-h)
              echo "Usage: llama-bench2 [options] [-- extra llama-bench args...]"
              echo ""
              echo "Options:"
              echo "  -i, --interactive             Launch interactive wizard"
              echo "  --gpu, --target <id|name>     Target GPU index or name substring"
              echo "  --model, -m <path|hf_repo>    Local GGUF file path or HuggingFace repo:quant"
              echo "  --stress                      Stress test mode (sustained repetitions & context)"
              echo "  -r, --repetitions <n>         Benchmark repetitions"
              echo "  --fit-target <MiB>            Margin to fit into device VRAM"
              echo "  -ngl, --n-gpu-layers <n>      GPU layers to offload"
              echo "  --interval <seconds>          Telemetry sample rate in seconds"
              exit 0
              ;;
            --)
              shift
              EXTRA_ARGS+=("$@")
              break
              ;;
            *)
              EXTRA_ARGS+=("$1")
              shift
              ;;
          esac
        done

        GPUS_RAW=""
        if command -v "$NVIDIA_SMI" >/dev/null 2>&1; then
          GPUS_RAW=$("$NVIDIA_SMI" --query-gpu=index,name,memory.total,memory.free --format=csv,noheader,nounits 2>/dev/null || true)
        fi

        GPU_ID=0
        GPU_NAME="NVIDIA GPU"
        GPU_TOTAL_MEM="N/A"
        GPU_FREE_MEM="N/A"

        # -----------------------------------------------------------------------------
        # Interactive Mode (Minimal human-made Soft-Serve style)
        # -----------------------------------------------------------------------------
        if [[ "$INTERACTIVE" -eq 1 ]]; then
          echo ""
          bold "  llama-bench2"
          dim "  Interactive LLM Benchmark & Thermal Telemetry"
          echo ""

          # 1. GPU Selection
          GPU_OPTIONS=()
          while IFS=',' read -r idx name total free; do
            [[ -z "$idx" ]] && continue
            idx=$(echo "$idx" | tr -d ' ')
            name=$(echo "$name" | sed 's/^ *//')
            total_gb=$(awk "BEGIN {printf \"%.1f\", $total/1024}")
            free_gb=$(awk "BEGIN {printf \"%.1f\", $free/1024}")
            GPU_OPTIONS+=("$idx · $name ($free_gb/$total_gb GB free)")
          done <<< "$GPUS_RAW"

          if [[ ''${#GPU_OPTIONS[@]} -gt 1 ]]; then
            CHOSEN_GPU=$(printf '%s\n' "''${GPU_OPTIONS[@]}" | gum choose \
              --header="  Select GPU:" \
              --cursor="  > ")
            GPU_ID=$(echo "$CHOSEN_GPU" | awk '{print $1}')
          elif [[ ''${#GPU_OPTIONS[@]} -eq 1 ]]; then
            GPU_ID=$(echo "''${GPU_OPTIONS[0]}" | awk '{print $1}')
          fi

          if [[ -n "$GPUS_RAW" ]]; then
            LINE=$(echo "$GPUS_RAW" | grep "^$GPU_ID," | head -n1 || true)
            if [[ -n "$LINE" ]]; then
              GPU_NAME=$(echo "$LINE" | cut -d',' -f2 | sed 's/^ *//')
              GPU_TOTAL_MEM=$(echo "$LINE" | cut -d',' -f3 | tr -d ' ')
              GPU_FREE_MEM=$(echo "$LINE" | cut -d',' -f4 | tr -d ' ')
            fi
          fi

          FREE_GB=$(awk "BEGIN {printf \"%.1f\", $GPU_FREE_MEM/1024}")
          check "GPU" "$GPU_ID · $GPU_NAME ($FREE_GB GB free)"

          # 2. Model Selection (recursive local fs + caches + suggestions)
          GGUF_LIST=()
          CURRENT_DIR=$(pwd)

          while IFS= read -r f; do
            [[ -n "$f" ]] && GGUF_LIST+=("$f")
          done < <(find "$CURRENT_DIR" -type f -name "*.gguf" 2>/dev/null | sort || true)

          while IFS= read -r f; do
            [[ -n "$f" ]] && GGUF_LIST+=("$f")
          done < <(find "$HOME/.cache" "$HOME/.local/share" -maxdepth 6 -type f -name "*.gguf" 2>/dev/null | sort || true)

          GGUF_LIST+=("unsloth/Qwen3.5-4B-GGUF:Q4_K_M")
          GGUF_LIST+=("unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M")
          GGUF_LIST+=("Qwen/Qwen2.5-Coder-7B-Instruct-GGUF:Q4_K_M")
          GGUF_LIST+=("Qwen/Qwen2.5-14B-Instruct-GGUF:Q4_K_M")
          GGUF_LIST+=("Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_M")
          GGUF_LIST+=("deepseek-ai/DeepSeek-R1-Distill-Qwen-14B-GGUF:Q4_K_M")

          GGUF_UNIQUE=()
          while IFS= read -r item; do
            [[ -n "$item" ]] && GGUF_UNIQUE+=("$item")
          done < <(printf '%s\n' "''${GGUF_LIST[@]}" | awk '!seen[$0]++')

          MODEL=$(printf '%s\n' "''${GGUF_UNIQUE[@]}" | gum filter \
            --header="  Select model (type to filter .gguf or Hugging Face repo):" \
            --placeholder="filter or enter repo:quant..." \
            --no-strict \
            --width=80 \
            --height=10)

          MODEL_LABEL=$(basename "$MODEL")
          if [[ -f "$MODEL" ]]; then
            MODEL_LABEL="$MODEL_LABEL ($(du -h "$MODEL" | cut -f1))"
          fi
          check "Model" "$MODEL_LABEL"

          # 3. Tests Selection
          TEST_CHOICES=(
            "pp512"
            "pp1024"
            "pp2048"
            "pp4096"
            "pp8192"
            "pp16384"
            "pp32768"
            "tg32"
            "tg128"
            "tg256"
            "tg512"
            "tg1024"
          )

          DEFAULT_SELECTIONS="pp512,pp2048,pp4096,pp8192,tg128,tg512"

          CHOSEN_TESTS=$(printf '%s\n' "''${TEST_CHOICES[@]}" | gum choose \
            --no-limit \
            --selected="$DEFAULT_SELECTIONS" \
            --header="  Select workloads (Space to toggle, Enter to confirm):" \
            --cursor="  > ")

          PROMPT_VALS=()
          GEN_VALS=()
          CHOSEN_TOKENS=()

          describe_test() {
            case "$1" in
              pp512)   echo "pp512: 512t prompt TTFT" ;;
              pp1024)  echo "pp1024: 1kt standard context" ;;
              pp2048)  echo "pp2048: 2kt document context" ;;
              pp4096)  echo "pp4096: 4kt long horizon" ;;
              pp8192)  echo "pp8192: 8kt deep horizon" ;;
              pp16384) echo "pp16384: 16kt extreme horizon" ;;
              pp32768) echo "pp32768: 32kt max horizon" ;;
              tg32)    echo "tg32: 32t latency" ;;
              tg128)   echo "tg128: 128t chat" ;;
              tg256)   echo "tg256: 256t medium" ;;
              tg512)   echo "tg512: 512t sustained code" ;;
              tg1024)  echo "tg1024: 1kt extended generation" ;;
              *)       echo "$1" ;;
            esac
          }

          SELECTED_DESCRIPTIONS=()
          while IFS= read -r token; do
            [[ -z "$token" ]] && continue
            CHOSEN_TOKENS+=("$token")
            SELECTED_DESCRIPTIONS+=("$(describe_test "$token")")
            [[ "$token" =~ ^pp([0-9]+)$ ]] && PROMPT_VALS+=("''${BASH_REMATCH[1]}")
            [[ "$token" =~ ^tg([0-9]+)$ ]] && GEN_VALS+=("''${BASH_REMATCH[1]}")
          done <<< "$CHOSEN_TESTS"

          CUSTOM_TESTS=()
          [[ ''${#PROMPT_VALS[@]} -gt 0 ]] && CUSTOM_TESTS+=(-p "$(IFS=,; echo "''${PROMPT_VALS[*]}")")
          [[ ''${#GEN_VALS[@]} -gt 0 ]] && CUSTOM_TESTS+=(-n "$(IFS=,; echo "''${GEN_VALS[*]}")")

          check "Tests" "$(IFS=,; echo "''${CHOSEN_TOKENS[*]}")"
          dim "          ($(IFS= · ; echo "''${SELECTED_DESCRIPTIONS[*]}"))"

          # 4. Other Configurations (moving between choices with Space/Enter)
          CHOSEN_MODE=$(gum choose \
            --header="  Workload mode:" \
            --cursor="  > " \
            "Stress (5 reps)" \
            "Standard (3 reps)" \
            "Quick (1 rep)" \
            "Custom")

          case "$CHOSEN_MODE" in
            *"Stress"*)   STRESS=1; REPETITIONS=5; MODE_TAG="Stress (5 reps)" ;;
            *"Standard"*) REPETITIONS=3; MODE_TAG="Standard (3 reps)" ;;
            *"Quick"*)    REPETITIONS=1; MODE_TAG="Quick (1 rep)" ;;
            *"Custom"*)
              REPETITIONS=$(gum input --placeholder="e.g. 5" --header="  Repetitions:")
              MODE_TAG="Custom ($REPETITIONS reps)"
              ;;
          esac

          CHOSEN_OFFLOAD=$(gum choose \
            --header="  VRAM layer offload:" \
            --cursor="  > " \
            "Auto Fit (1.5G reserve)" \
            "Full Offload (-ngl 99)" \
            "Custom")

          case "$CHOSEN_OFFLOAD" in
            *"Auto Fit"*) OFFLOAD_ARGS=(--fit-target 1500); OFFLOAD_TAG="Auto Fit (1.5G reserve)" ;;
            *"Full"*)     OFFLOAD_ARGS=(-ngl 99); OFFLOAD_TAG="Full Offload" ;;
            *"Custom"*)
              LCOUNT=$(gum input --placeholder="e.g. 24" --header="  GPU layers:")
              OFFLOAD_ARGS=(-ngl "$LCOUNT")
              OFFLOAD_TAG="Layers: $LCOUNT"
              ;;
          esac

          CHOSEN_FA=$(gum choose \
            --header="  Flash Attention:" \
            --cursor="  > " \
            "Enabled" \
            "Disabled")

          if [[ "$CHOSEN_FA" == "Enabled" ]]; then
            FA_ARG="-fa 1"
            FA_TAG="Flash Attention"
          else
            FA_ARG="-fa 0"
            FA_TAG="Standard Attention"
          fi

          CHOSEN_KV=$(gum choose \
            --header="  KV Cache Quantization:" \
            --cursor="  > " \
            "f16" \
            "q8_0" \
            "q4_0")

          case "$CHOSEN_KV" in
            "q8_0") KV_ARG="-ctk q8_0 -ctv q8_0"; KV_TAG="q8_0" ;;
            "q4_0") KV_ARG="-ctk q4_0 -ctv q4_0"; KV_TAG="q4_0" ;;
            *)      KV_ARG=""; KV_TAG="f16" ;;
          esac

          check "Config" "$MODE_TAG · $OFFLOAD_TAG · $FA_TAG · $KV_TAG"
          echo ""

        else
          # Non-interactive CLI
          if [[ -n "$GPUS_RAW" ]]; then
            if [[ -n "$TARGET_GPU" ]]; then
              MATCH=$(echo "$GPUS_RAW" | grep -i "$TARGET_GPU" | head -n1 || true)
              [[ -n "$MATCH" ]] && GPU_ID=$(echo "$MATCH" | cut -d',' -f1 | tr -d ' ')
            fi

            LINE=$(echo "$GPUS_RAW" | grep "^$GPU_ID," | head -n1 || true)
            if [[ -n "$LINE" ]]; then
              GPU_NAME=$(echo "$LINE" | cut -d',' -f2 | sed 's/^ *//')
              GPU_TOTAL_MEM=$(echo "$LINE" | cut -d',' -f3 | tr -d ' ')
              GPU_FREE_MEM=$(echo "$LINE" | cut -d',' -f4 | tr -d ' ')
            fi
          fi

          if [[ -z "$MODEL" ]]; then
            FIRST_GGUF=$(find "$(pwd)" -type f -name "*.gguf" 2>/dev/null | head -n1 || true)
            if [[ -n "$FIRST_GGUF" ]]; then
              MODEL="$FIRST_GGUF"
            else
              echo "Error: No GGUF model specified and none found in $(pwd). Pass --model <file|repo:quant> or run interactively with -i." >&2
              exit 1
            fi
          fi

          [[ ''${#OFFLOAD_ARGS[@]} -eq 0 ]] && OFFLOAD_ARGS=(--fit-target 1500)

          if [[ "$STRESS" -eq 1 ]]; then
            CUSTOM_TESTS=(-p 2048,4096,8192 -n 512)
            [[ -z "$REPETITIONS" ]] && REPETITIONS=5
          elif [[ ''${#CUSTOM_TESTS[@]} -eq 0 ]]; then
            CUSTOM_TESTS=(-p 2048,4096,8192 -n 256)
          fi
        fi

        CTX_ARGS=("''${CUSTOM_TESTS[@]}")
        [[ -n "$FA_ARG" ]] && CTX_ARGS+=($FA_ARG)
        [[ -n "$KV_ARG" ]] && CTX_ARGS+=($KV_ARG)
        [[ -n "$REPETITIONS" ]] && CTX_ARGS+=(-r "$REPETITIONS")

        MODEL_ARGS=()
        [[ -f "$MODEL" ]] && MODEL_ARGS=(-m "$MODEL") || MODEL_ARGS=(-hf "$MODEL")

        # Baseline Query
        INIT_TEMP="N/A"
        INIT_PWR="N/A"
        INIT_VRAM="N/A"

        if command -v "$NVIDIA_SMI" >/dev/null 2>&1; then
          INIT_DATA=$("$NVIDIA_SMI" --id="$GPU_ID" --query-gpu=temperature.gpu,power.draw,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true)
          if [[ -n "$INIT_DATA" ]]; then
            INIT_TEMP=$(echo "$INIT_DATA" | cut -d',' -f1 | tr -d ' ')
            INIT_PWR=$(echo "$INIT_DATA" | cut -d',' -f2 | tr -d ' ')
            INIT_VRAM=$(echo "$INIT_DATA" | cut -d',' -f3 | tr -d ' ')
            GPU_TOTAL_MEM=$(echo "$INIT_DATA" | cut -d',' -f4 | tr -d ' ')
          fi
        fi

        dim "  Baseline: ''${INIT_TEMP}°C · ''${INIT_PWR}W · ''${INIT_VRAM}/''${GPU_TOTAL_MEM} MiB VRAM"
        echo ""

        TMP_DIR=$(mktemp -d)
        TELEMETRY_LOG="$TMP_DIR/telemetry.csv"
        BENCH_RAW_OUT="$TMP_DIR/bench.raw"

        cleanup() {
          if [[ -n "''${TELEMETRY_PID:-}" ]] && kill -0 "$TELEMETRY_PID" 2>/dev/null; then
            kill "$TELEMETRY_PID" 2>/dev/null || true
            wait "$TELEMETRY_PID" 2>/dev/null || true
          fi
          printf "\r\033[K" >&2
          rm -rf "$TMP_DIR"
        }
        trap cleanup EXIT INT TERM

        # Live status ticker on stderr
        if command -v "$NVIDIA_SMI" >/dev/null 2>&1; then
          (
            peak_temp=$INIT_TEMP
            while true; do
              row=$("$NVIDIA_SMI" --id="$GPU_ID" --query-gpu=temperature.gpu,power.draw,utilization.gpu,memory.used --format=csv,noheader,nounits 2>/dev/null || true)
              if [[ -n "$row" ]]; then
                echo "$row" >> "$TELEMETRY_LOG"
                cur_temp=$(echo "$row" | cut -d',' -f1 | tr -d ' ')
                cur_pwr=$(echo "$row" | cut -d',' -f2 | tr -d ' ')
                cur_util=$(echo "$row" | cut -d',' -f3 | tr -d ' ')
                cur_mem=$(echo "$row" | cut -d',' -f4 | tr -d ' ')
                if [[ "$cur_temp" =~ ^[0-9]+$ ]]; then
                  [[ "$peak_temp" == "N/A" || $cur_temp -gt $peak_temp ]] && peak_temp=$cur_temp
                  printf "\r\033[1m⚡ %s°C\033[0m (peak %s°C) · %sW · %s/%s MiB · %s%% util " \
                    "$cur_temp" "$peak_temp" "$cur_pwr" "$cur_mem" "$GPU_TOTAL_MEM" "$cur_util" >&2
                fi
              fi
              sleep "$INTERVAL"
            done
          ) &
          TELEMETRY_PID=$!
        fi

        START_TIME=$(date +%s)
        set +e
        CUDA_VISIBLE_DEVICES="$GPU_ID" "$LLAMA_BENCH" \
          "''${MODEL_ARGS[@]}" \
          "''${OFFLOAD_ARGS[@]}" \
          "''${CTX_ARGS[@]}" \
          "''${EXTRA_ARGS[@]}" | tee "$BENCH_RAW_OUT"
        BENCH_EXIT_CODE=$?
        set -e
        DURATION=$(($(date +%s) - START_TIME))

        # Stop ticker
        if [[ -n "''${TELEMETRY_PID:-}" ]] && kill -0 "$TELEMETRY_PID" 2>/dev/null; then
          kill "$TELEMETRY_PID" 2>/dev/null || true
          wait "$TELEMETRY_PID" 2>/dev/null || true
          unset TELEMETRY_PID
        fi
        printf "\r\033[K" >&2

        echo ""

        # Throughput results via Charm Glamour Markdown formatter
        if [[ -f "$BENCH_RAW_OUT" && -s "$BENCH_RAW_OUT" ]]; then
          grep -E '^\|' "$BENCH_RAW_OUT" | gum format --type=markdown --theme=auto || cat "$BENCH_RAW_OUT"
        fi

        # Telemetry summary via rounded Charm Table
        if [[ -f "$TELEMETRY_LOG" && -s "$TELEMETRY_LOG" ]]; then
          echo ""
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
                delta_t = max_t - init_t
                throttle = (max_t >= 85) ? "YES (>=85°C)" : "NO (Nominal)"
                print "Metric;Measurement"
                printf "Duration;%d seconds\n", duration
                printf "Hardware;[%s] %s\n", gpu_id, gpu_name
                printf "Temperature;%d °C -> %d °C (ΔT: +%d °C · avg: %.1f °C)\n", init_t, max_t, delta_t, sum_t / count
                printf "Power Draw;%.1f W peak (%.1f W avg)\n", max_p, sum_p / count
                printf "VRAM Allocated;%d MiB / %s MiB\n", max_mem, vram_total
                printf "GPU Utilization;%.1f %% avg\n", sum_u / count
                printf "Thermal Throttling;%s\n", throttle
              }
            }
          ' duration="$DURATION" gpu_id="$GPU_ID" gpu_name="$GPU_NAME" vram_total="$GPU_TOTAL_MEM" "$TELEMETRY_LOG" | \
            gum table -p -s ";" -b rounded --widths 18,50
          echo ""
        fi

        exit $BENCH_EXIT_CODE
      '';
    in {
      environment.systemPackages = [
        llamaPackage
        llamaBench2
        pkgs.gum
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
