{ writers, python3Packages }:

writers.writePython3Bin "wtask"
  {
    libraries = [ python3Packages.pyyaml ];
    flakeIgnore = [ "E501" ];
  }
  (builtins.readFile ./wtask.py)
