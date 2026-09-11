{den, ...}: {
  den.aspects.lenovo-legion-16iah7h-PF3XJ8SP = {
    includes = [
      den.aspects.hardware.lenovo-legion-toolkit
    ];

    nixos = {...}: {
      # [[1]] In [[Fan Curve]], apply [[performance-ac]] preset + [Minifancurve if too cold]
      # [[2]] In [[Other Options]], apply:
      # | Configuration                        | Default   | Custom   |
      # | ------------------------------------ | --------- | -------: |
      # | CPU Long Term Power Limit [W] (PL1)  |        60 |      115 |
      # | CPU Short Term Power Limit [W] (PL2) | 45/80/135 |      135 |
      # | CPU Peak Power Limit [W]             |         0 |        0 |
      # | CPU Cross Loading Power Limit [W]    |         0 |        0 |
      # | CPU APU SPPT Power Limit [W]         |         0 |        0 |
      # | GPU cTGP Power Limit [W]             |         0 |      140 |
      # | GPU PPAB Power Limit [W]             |        15 |       25 |
      # | GPU Temperature Limit [°C]           |         0 |       90 |
    };
  };
}
