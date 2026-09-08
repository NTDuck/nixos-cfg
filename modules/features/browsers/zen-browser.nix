{
  den,
  inputs,
  ...
}: {
  den.aspects.browsers.zen-browser = {
    homeManager = {
      config,
      lib,
      pkgs,
      user,
      ...
    }: {
      imports = [
        inputs.zen-browser.homeModules.twilight
      ];

      programs.zen-browser = {
        enable = true;

        # Do not set - would replace policy-aware package with prebuilt flake package
        # package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.twilight;

        setAsDefaultBrowser = true;

        # The Zen flake exposes `env` specifically for launcher-level variables.
        # Set Wayland/PipeWire here, not only in the compositor session, so
        # WebRTC capture works from desktop entries and terminal launches alike.
        # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/16-environment-variables.nix
        env = {
          GTK_USE_PORTAL = "1";
          MOZ_ENABLE_WAYLAND = "1";
          XDG_SESSION_TYPE = "wayland";
        };

        # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/02-policies-configuration.nix
        # https://mozilla.github.io/policy-templates/
        policies = {
          DisableAppUpdate = true;
          DisableTelemetry = true;
          DisablePocket = true;

          ExtensionSettings =
            # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/04-extensions.nix
            builtins.mapAttrs (_: pluginId: {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
              installation_mode = "force_installed";
            }) {
              # https://github.com/EdgeTypE/better-deepseek
              "betterdeepseek@goygoyengine.com" = "better-deepseek";

              # # https://github.com/saeedezzati/superpower-chatgpt
              # "cjiggdeafkdppmdmlcdpfigbalcgbkpg@fancydino.com" = "superpower-chatgpt";
            };
        };

        profiles.${user.name} = {
          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/01-basic-home-manager.nix
          presets = {
            betterfox.enable = true;
            arkenfox.enable = true;
          };

          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/04b-extensions-rycee.nix
          extensions = {
            force = true;
            packages = [
              inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}.sponsorblock
              inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}.ublock-origin
            ];
          };

          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/02b-settings-preferences.nix
          # TODO Add more
          settings = {
            "browser.startup.page" = 3;
            "browser.sessionstore.resume_from_crash" = true;
            "browser.download.always_ask_before_handling_new_types" = false;

            # Download automatically to ~/Downloads instead of opening a
            # GTK/XDG file chooser for every download.
            "browser.download.useDownloadDir" = true;

            # 2 means use the explicit browser.download.dir path.
            "browser.download.folderList" = 2;
            "browser.download.dir" = "${config.home.homeDirectory}/Downloads";

            # Prevent unwanted Arkenfox behaviour (logout on shutdown)
            "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
            "privacy.clearOnShutdown.cookies" = false;
            "privacy.clearOnShutdown.offlineApps" = false;
            "privacy.clearOnShutdown.sessions" = false;

            # Allow switching spaces when scrolling
            "zen.workspaces.swipe-actions" = true;
            "zen.workspaces.wrap-around-navigation" = true;
            "zen.workspaces.natural-scroll" = false;
            "zen.workspaces.scroll-modifier-key" = "ctrl";

            "zen.workspaces.continue-where-left-off" = true;
            "zen.view.compact.hide-tabbar" = true;
            "zen.urlbar.behavior" = "float";

            # TODO Explain intent
            "widget.use-xdg-desktop-portal" = 1;
            "widget.use-xdg-desktop-portal.file-picker" = 1;
            "widget.use-xdg-desktop-portal.mime-handler" = 1;
          };

          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/05-mods-installation.nix
          mods = [
            "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
            "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
            "c6813222-6571-4ba6-8faf-58f3343324f6" # Disable Rounded Corners
            "c01d3e22-1cee-45c1-a25e-53c0f180eea8" # Ghost Tabs
          ];

          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/06-search-engines.nix
          # TODO Add more
          search = {
            force = true;
            default = "ddg";

            engines = {
              nixos-refs = {
                name = "MyNixOS";
                definedAliases = ["@nx"];
                icon = "${pkgs.unstable.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";

                urls = [
                  {
                    template = "https://mynixos.com/search?q={searchTerms}";
                    params = [
                      {
                        name = "query";
                        value = "searchTerms";
                      }
                    ];
                  }
                ];
              };

              movie-tors = {
                name = "WatchSoMuch";
                # TODO Change icon
                icon = "${pkgs.unstable.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = ["@movtor"];

                urls = [
                  {
                    template = "https://watchsomuch.to/Movies/{searchTerms}/";
                    params = [
                      {
                        name = "query";
                        value = "searchTerms";
                      }
                    ];
                  }
                ];
              };
              # https://watchsomuch.to/Movies/mentalist/
            };
          };

          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/07-bookmarks.nix
          bookmarks = {
            force = true;
            settings = [];
          };

          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/08-containers.nix
          containersForce = true;

          containers = {
            "master" = {
              color = "yellow";
              icon = "fingerprint";
              id = 1;
            };
            "dev,edu,fut" = {
              color = "blue";
              icon = "briefcase";
              id = 4;
            };
            "ddd" = {
              color = "red";
              icon = "vacation";
              id = 6;
            };
          };

          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/09-spaces-themes.nix
          # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/10-pinned-tabs.nix
          spacesForce = true;

          pinsForce = true;
          pinsForceAction = "demote";

          spaces = {
            "master" = {
              id = "02d6e596-fe34-4ebc-8906-2dbb63a3800b";
              position = 1000;
              icon = "🐥";
              # container = 1; # <- `containers."master"`

              pins = {
                "Youtube" = {
                  id = "7518af9c-745d-4b5b-bdce-3ba8e8cedeac";
                  url = "https://www.youtube.com/";
                  position = 101;
                };
                "Facebook" = {
                  id = "2330b196-6224-49de-9149-fa5dd4260d57";
                  url = "https://www.facebook.com/";
                  position = 102;
                };
                "Instagram" = {
                  id = "93195e70-17f2-4c5d-8278-ca1784aaa9c4";
                  url = "https://www.instagram.com/";
                  position = 103;
                };
              };
            };
            "dev" = {
              id = "4f5be4a3-8a0c-4201-b85f-f4f70ea1d250";
              position = 2000;
              icon = "🌐";
              container = 4; # <- `containers."dev,edu,fut"`

              pins = {
                "Guthib" = {
                  id = "e0212ebe-07f1-405d-ba00-ab1b0cc5ca85";
                  url = "https://github.com/NTDuck";
                  position = 101;
                };
                "Agentics" = {
                  id = "6f2844e6-35d9-499b-b670-19affdd00588";
                  isFolderCollapsed = false;
                  editedTitle = true;
                  position = 200;
                  folderIcon = "chrome://browser/skin/zen-icons/selectable/star.svg";

                  pins = {
                    "Claude" = {
                      id = "8ccf07e6-d6e3-4fc8-82b8-2c75b2b5c3cf";
                      url = "https://claude.ai/new";
                      position = 201;
                    };
                    "ChatGPT" = {
                      id = "6cd58133-b941-419a-a0d0-33258ed44062";
                      url = "https://chatgpt.com/";
                      position = 202;
                    };
                    "Mistral" = {
                      id = "53fe15cd-f375-4fd6-ab55-7ba4c138d7a0";
                      url = "https://chat.mistral.ai/work";
                      position = 203;
                    };
                    "Perplexity" = {
                      id = "d390204e-c74d-4be5-8b4f-fadff576db3f";
                      url = "https://www.perplexity.ai/";
                      position = 204;
                    };
                    "Qwen" = {
                      id = "e10ba8f6-5473-4017-8dba-bb10b1172bdc";
                      url = "https://chat.qwen.ai/";
                      position = 205;
                    };
                    "Deepseek" = {
                      id = "74cfe18b-0a3b-4d7f-9adb-def0ef75753b";
                      url = "https://chat.deepseek.com/";
                      position = 206;
                    };
                  };
                };
              };
            };
            "edu" = {
              id = "2d5331e2-a1e7-4b07-8261-e7436ae8043f";
              position = 3000;
              icon = "💼";
              container = 4; # <- `containers."dev,edu,fut"`

              pins = {
                "Gmails" = {
                  id = "3023387e-698b-4095-b584-742fb20dafed";
                  isFolderCollapsed = false;
                  editedTitle = true;
                  position = 100;
                  folderIcon = "chrome://browser/skin/zen-icons/selectable/mail.svg";

                  pins = {
                    "Gmail #0" = {
                      id = "3d4b419a-d905-4d32-b94e-6b299d387b4d";
                      url = "https://mail.google.com/mail/u/0/";
                      position = 101;
                    };
                    "Gmail #1" = {
                      id = "606ac3d9-4ebb-47ac-97b9-b7f4288eca84";
                      url = "https://mail.google.com/mail/u/1/";
                      position = 102;
                    };
                  };
                };
              };
            };
            "fut" = {
              id = "b40c5a6d-879c-4257-9ef5-3082d1d19f84";
              position = 4000;
              icon = "💡";
              container = 4; # <- `containers."dev,edu,fut"`
            };
            # "ddd" = {
            #   id = "c75e0fb9-9f36-409e-926c-674b0c03ae55";
            #   position = 5000;
            #   icon = "🔞";
            #   container = 6; # <- `containers."ddd"`
            # };
            # "..." = {
            #   id = "6e239929-a237-4f47-b5fd-1d988de4ae9b";
            #   position = 6000;
            #   icon = "…";
            #   container = 1; # <- `containers."master"`
            # };
          };
        };

        # https://github.com/0xc000022070/zen-browser-flake/blob/main/examples/14-native-messaging.nix
        nativeMessagingHosts = [
          pkgs.unstable.firefoxpwa
        ];
      };

      stylix.targets.zen-browser.profileNames =
        lib.optionals (config.stylix.enable or false) ["${user.name}"];
    };
  };
}
