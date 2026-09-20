# try -- tobi/try, an ephemeral workspace manager. `try` opens a picker over
# dated scratch directories, `try clone <url>` drops a repo into one, and
# Ctrl-G inside the picker graduates a scratch into a real project.
#
# It comes from the upstream flake rather than nixpkgs, and that is not a
# preference. nixpkgs *has* a `try`, and it is a different program entirely --
# binpash/try 0.2.0, "lets you run a command and inspect its effects before
# changing your live system". Adding `try` to packages.nix would have installed
# the wrong tool with no error at all.
#
# The flake carries aarch64-darwin as well as Linux, so this works on the Mac;
# it is a Ruby script with a Nix wrapper, which is why it ports so easily.
# Upstream also ships the home-manager module used here.
#
# path follows Omarchy's convention rather than try's own ~/src/tries default,
# so both machines agree. Omarchy already points its lazy `try` stub at
# ~/Work/tries in default/bash/init.
{
  inputs,
  config,
  ...
}:

{
  imports = [ inputs.try.homeModules.default ];

  programs.try = {
    enable = true;
    path = "~/Work/tries";
  };

  # The upstream module writes only the shell integration -- an `eval` against
  # an absolute store path -- and never puts try on PATH. That is enough for
  # interactive use, where the function shadows everything, but it leaves
  # `command -v try` answering with Arch's tobi-try 1.8.2 here and with nothing
  # at all on macOS. Declaring the package makes both machines agree on 1.10.1
  # however try is reached.
  home.packages = [ config.programs.try.package ];
}
