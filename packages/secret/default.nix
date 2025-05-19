{
  inputs',
  pkgs,
  ...
}:

pkgs.substituteAll {
  name = "secret";
  dir = "bin";
  src = ./secret.sh;
  isExecutable = true;

  binPath = pkgs.lib.makeBinPath (with pkgs; [
    coreutils util-linux gnused
    inputs'.ragenix.packages.ragenix
  ]);
}
