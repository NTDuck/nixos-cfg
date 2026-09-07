{den, ...}: {
  den.aspects.dev.toolchains.java-kotlin = {
    nixos = {pkgs, ...}: {
      environment.systemPackages = [
        # pkgs.unstable.jdk21

        pkgs.unstable.maven
        pkgs.unstable.gradle

        pkgs.unstable.spring-boot-cli
        pkgs.unstable.jdt-language-server

        # pkgs.unstable.jetbrains.idea-oss
        pkgs.unstable.jetbrains.idea
      ];

      # environment.sessionVariables = {
      #   JAVA_HOME = "${pkgs.unstable.jdk21.home}";
      # };
    };

    homeManager = {pkgs, ...}: {
      programs.java = {
        enable = true;
        # package = pkgs.unstable.jdk;
        package = pkgs.unstable.jdk11;
      };
    };
  };
}
