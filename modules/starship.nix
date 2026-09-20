# The prompt. Omarchy's starship.toml, carried over so the Mac gets the same
# prompt rather than starship's default.
#
# It ports cleanly because every colour in it is a *named* ANSI colour --
# "bold cyan", "italic cyan" -- which resolves against the terminal's palette
# rather than a hardcoded hex value. Nothing here refers to Omarchy's theme
# state, so the same file produces the same prompt on both machines as long as
# the terminals agree on their sixteen colours.
{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      add_newline = true;
      command_timeout = 200;
      format = "[$directory$git_branch$git_status]($style)$character";

      character = {
        error_symbol = "[✗](bold cyan)";
        success_symbol = "[❯](bold cyan)";
      };

      directory = {
        truncation_length = 2;
        truncation_symbol = "…/";
        repo_root_style = "bold cyan";
        repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "italic cyan";
      };

      git_status = {
        format = "[$all_status]($style)";
        style = "cyan";
        ahead = "⇡\${count} ";  # U+21E1
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";  # U+21D5 U+21E1 U+21E3
        behind = "⇣\${count} ";  # U+21E3
        conflicted = " ";  # U+EBAB
        up_to_date = " ";  # U+F00C
        untracked = "? ";
        modified = " ";  # U+EA71
        stashed = "";
        staged = "";
        renamed = "";
        deleted = "";
      };
    };
  };
}
