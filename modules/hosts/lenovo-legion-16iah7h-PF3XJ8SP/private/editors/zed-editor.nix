{den, ...}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    homeManager = {
      programs.zed-editor.userSettings = {
        agent = {
          default_model = {
            provider = "openai";
            model = "openbmb/MiniCPM5-1B-GGUF:Q8_0";
            api_url = "http://127.0.0.1:11434/v1";
            enable_thinking = true;
          };
          dock = "right";
          favourite_models = [];
          model_parameters = [];
        };
      };
    };
  };
}
