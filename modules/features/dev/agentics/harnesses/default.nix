{den, ...}: {
  den.aspects.dev.agentics.harnesses = {
    includes = [
      den.aspects.dev.agentics.harnesses.antigravity-cli
      den.aspects.dev.agentics.harnesses.claude-code
      den.aspects.dev.agentics.harnesses.codex
      den.aspects.dev.agentics.harnesses.codev
      den.aspects.dev.agentics.harnesses.oh-my-pi
      den.aspects.dev.agentics.harnesses.reasonix
    ];

    nixos = {
      # https://github.com/numtide/llm-agents.nix#binary-cache
      nix.settings = {
        extra-substituters = ["https://cache.numtide.com"];
        extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];
      };
    };
  };
}
