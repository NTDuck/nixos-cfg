{den, ...}: {
  den.hosts.x86_64-linux.dell-latitude-E7270-H836QF2 = {
    users.ayin = {};
  };

  den.aspects.dell-latitude-E7270-H836QF2 = {
    includes = [
      den.aspects.battery.power-profiles-daemon
      den.aspects.battery.upower
      den.aspects.bluetooth
      den.aspects.bootloaders.systemd
      den.aspects.browsers.chromium
      den.aspects.browsers.zen-browser
      (den.aspects.compositors.mangowm {
        terminal = pkgs: "${pkgs.unstable.ghostty}/bin/ghostty";
      })
      den.aspects.dev
      den.aspects.editors.helix
      den.aspects.editors.zed-editor
      den.aspects.file-managers.nemo
      den.aspects.file-managers.yazi
      den.aspects.gaming.itch
      den.aspects.gaming.mangohud
      den.aspects.gaming.steam
      den.aspects.gaming.wine
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
      den.aspects.office.pandoc
      den.aspects.office.libreoffice
      den.aspects.office.texlive
      den.aspects.office.zathura
      den.aspects.productivity.mermaid
      den.aspects.productivity.obsidian
      den.aspects.productivity.taskwarrior
      den.aspects.productivity.tomato
      den.aspects.productivity.world-monitor
      den.aspects.secrets.agenix
      den.aspects.services.cliphist
      den.aspects.services.cloudflare-warp
      den.aspects.services.dconf
      den.aspects.services.fcitx5
      den.aspects.services.gnome-keyring
      den.aspects.services.gvfs
      den.aspects.services.kanshi
      den.aspects.services.keyd
      den.aspects.services.nftables
      den.aspects.services.pipewire
      den.aspects.services.polkit
      den.aspects.services.resolved
      den.aspects.services.ssh
      den.aspects.services.udisks2
      den.aspects.services.xdg
      den.aspects.settings
      den.aspects.shells.prompts.starship
      den.aspects.shells.zsh
      den.aspects.swap.zram
      den.aspects.terminals.ghostty
      den.aspects.utilities.screenshots.flameshot
      den.aspects.utilities.screenshots.gpu-screen-recorder
      den.aspects.utilities.torrents.rtorrent
      den.aspects.utilities.torrents.torrent-tui
      den.aspects.utilities.torrents.webtorrent
      den.aspects.utilities.cava
      den.aspects.utilities.fastfetch
      den.aspects.utilities.p7zip
      den.aspects.utilities.ripgrep
      den.aspects.utilities.rufus
      den.aspects.utilities.zoxide
      den.aspects.virtualization.docker
      den.aspects.virtualization.kubernetes
      den.aspects.virtualization.qemu
      den.aspects.virtualization.waydroid
      den.aspects.stylix
    ];
  };
}
