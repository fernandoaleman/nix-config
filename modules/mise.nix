# mise settings, as environment variables rather than as a config file.
#
# mise keeps settings and tool versions in the *same* file,
# ~/.config/mise/config.toml, and there is no conf.d or separate settings.toml.
# That file cannot be managed here: Omarchy's 13 AI-tool shims each run
# `mise use -g --quiet <pkg>` on every launch, which writes to it. Pointed at a
# store path, that fails outright --
#
#   mise ERROR Permission denied (os error 13) at path
#     "/nix/store/.<hash>-mise-config.toml.2rdSOe"
#
# -- so every one of those tools would break. Settings also read from MISE_*
# environment variables, which gives the same defaults on both machines with
# nothing to collide over.
#
# Tool *versions* deliberately live elsewhere: per-project mise.toml files,
# which is how mise expects to be used and how terraform needs to be pinned --
# state files record the version that wrote them and refuse older binaries, so
# one flake-pinned terraform would be wrong the moment two repos disagree.
{
  home.sessionVariables = {
    # Let mise read .ruby-version. Not the default: the setting is [] out of
    # the box, so without this a Rails checkout's .ruby-version is ignored.
    MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS = "ruby";

    # Fetch prebuilt Ruby rather than compiling from source -- minutes versus
    # seconds, and the difference is felt on any `mise x ruby@...`.
    MISE_RUBY_COMPILE = "0";
  };

  # legacy_version_file is deliberately absent. The reference setup set it to
  # true, and true is already mise's default on 2026.9.1 -- verified with
  # `mise settings get`. Declaring it would be carrying a line that does
  # nothing, the same test that removed FZF_DEFAULT_COMMAND.
}
