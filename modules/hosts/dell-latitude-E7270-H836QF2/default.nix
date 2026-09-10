{den, ...}: {
  den.hosts.x86_64-linux.dell-latitude-E7270-H836QF2 = {
    users.ayin = {};
  };

  den.aspects.dell-latitude-E7270-H836QF2 = {
    includes = [
      den.aspects.battery
      den.aspects.bluetooth
      den.aspects.bootloaders.systemd
      den.aspects.browsers.firefox
      (den.aspects.compositors.mangowm {
        terminal = pkgs: "${pkgs.unstable.foot}/bin/foot";
      })
      den.aspects.dev
      den.aspects.editors.helix
      den.aspects.editors.zed-editor
      den.aspects.file-managers.nemo
      den.aspects.file-managers.yazi
      den.aspects.gaming.itch
      den.aspects.gaming.mangohud
      den.aspects.gaming.steam
      den.aspects.gaming.wlib
      den.aspects.gaming.rpgmakermlinux-cicpoffs
      (den.aspects.greeters.tuigreet {
        command = config: "${config.programs.mango.package}/bin/mango";
      })
      # `linux-cachyos-latest-7.1.1` conflicts with `broadcom-sta`
      # den.aspects.kernels.cachyos-kernel
      den.aspects.messenging.discord
      den.aspects.messenging.telegram
      den.aspects.multimedia.ffmpeg
      den.aspects.multimedia.gallery-dl
      den.aspects.multimedia.imv
      den.aspects.multimedia.mpv
      den.aspects.multimedia.obs-studio
      den.aspects.multimedia.yt-dlp
      den.aspects.music.youtube-music
      den.aspects.nix
      den.aspects.noctalia
      # den.aspects.lix
      den.aspects.nh
      den.aspects.nix-ld
      den.aspects.nur
      den.aspects.office.libreoffice
      den.aspects.office.zathura
      den.aspects.productivity.mermaid
      den.aspects.productivity.obsidian
      den.aspects.productivity.taskwarrior
      den.aspects.productivity.tomato
      den.aspects.secrets.agenix
      den.aspects.services.cliphist
      den.aspects.services.fcitx5
      den.aspects.services.pipewire
      den.aspects.services.dconf
      den.aspects.services.gnome-keyring
      den.aspects.services.polkit
      den.aspects.services.cloudflare-warp
      den.aspects.services.nftables
      den.aspects.services.resolved
      den.aspects.settings
      den.aspects.shells.prompts.powerlevel10k
      den.aspects.shells.zsh
      den.aspects.swap.zram
      den.aspects.terminals.foot
      den.aspects.utilities.screenshots.flameshot
      den.aspects.utilities.cava
      den.aspects.utilities.fastfetch
      den.aspects.utilities.p7zip
      den.aspects.utilities.ripgrep
      den.aspects.utilities.rufus
      den.aspects.utilities.zoxide
      den.aspects.virtualization.docker
      den.aspects.virtualization.waydroid
      den.aspects.stylix
    ];
  };
}
