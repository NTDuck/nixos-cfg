{den, ...}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    nixos = {pkgs, ...}: {
      services.ollama = {
        enable = true;
        package = pkgs.unstable.ollama-cuda;

        host = "127.0.0.1";
        port = 11434;

        loadModels = [
          # `npx llm-checker recommend`
          "mistral:7b-instruct-v0.2-q5_0" # overall, general
          "qwen2.5-coder:7b-base-q5_0" # coding
          "qwen2.5:7b-instruct-q5_0" # reasoning
          "llava:7b-v1.6-mistral-q5_0" # multimodal
          "deepseek-r1:7b" # creative, chat
          "yi:6b-200k-q3_K_S" # reading

          # SLM <1b
          "qwen3.5:0.8b" # reasoning
          "pedrolucas/pedro-open-coder-v2:0.9b-f16" # coding
          "hf.co/IFM/K2-Horizon-0.9B-GGUF:BF16" # wildcard

          # Dense, coding
          "qwen3.5:4b-q4_K_M"
          "hf.co/unsloth/Qwen3-4B-Instruct-2507-GGUF:UD-Q4_K_XL"
          "hf.co/unsloth/Qwen3-4B-Instruct-2507-GGUF:Q5_K_M"

          # MoE, reasoning
          "lfm2.5:8b-a1b-q4_K_M"
          "gpt-oss:20b"
          "qwen3:30b-a3b-thinking-2507-q4_K_M"

          # eGPU
          "qwen3.8:27b"
        ];

        syncModels = true;

        environmentVariables = {
          OLLAMA_FLASH_ATTENTION = "1";
          OLLAMA_KV_CACHE_TYPE = "q4_0";
          OLLAMA_KEEP_ALIVE = "5m";
        };
      };
    };
  };
}
