# Keep the Starship palette in sync with the terminal's real colors.
#
# The colors are read from the terminal itself (OSC 4/10/11 queries) by
# lib/termpalette.c, so this works the same in Ghostty, Rex, and any other
# terminal that answers xterm color queries, locally or over SSH. Generated
# configs are cached per palette, so a new shell normally costs one ~2 ms
# helper call and no Python.
#
# Light/dark switches are picked up live: fish updates
# $fish_terminal_color_theme when the terminal reports a theme change, and the
# handler below re-queries the palette and repaints the prompt.

set -l dotfiles (path resolve (status dirname)/../..)
set -g __theme_sync_src $dotfiles/lib/termpalette.c
set -g __theme_sync_script $dotfiles/lib/sync_starship_palette.py
set -g __theme_sync_bin $HOME/.cache/dotfiles/termpalette
set -g __theme_sync_cache $HOME/.cache/starship/palettes
set -g __theme_sync_template $HOME/.config/starship/starship.toml
test -f $__theme_sync_template; or set __theme_sync_template $dotfiles/config/starship/starship.toml

# Build the helper on first use (or after the source changes).
if not test -x $__theme_sync_bin; or test $__theme_sync_src -nt $__theme_sync_bin
    if command -q cc
        mkdir -p (path dirname $__theme_sync_bin)
        cc -O2 -o $__theme_sync_bin.tmp $__theme_sync_src 2>/dev/null
        and command mv -f $__theme_sync_bin.tmp $__theme_sync_bin
    end
end

function __theme_sync_apply --description 'Point STARSHIP_CONFIG at a palette generated from the terminal colors'
    set -l reply
    if test -x $__theme_sync_bin
        set reply (string split ' ' -- ($__theme_sync_bin 2>/dev/null))
    end

    if test (count $reply) -eq 20
        set -g __theme_sync_scheme $reply[2]
        set -l out $__theme_sync_cache/$reply[1].toml
        if not test -f $out
            or test $__theme_sync_template -nt $out
            or test $__theme_sync_script -nt $out
            python3 $__theme_sync_script --template $__theme_sync_template --output $out --colors $reply[3..] >/dev/null 2>&1
        end
        if test -f $out
            set -gx STARSHIP_CONFIG $out
            return 0
        end
    else if not test -x $__theme_sync_bin; and command -q python3
        # No C compiler on this machine: slower Python query (~40 ms).
        set reply (string split ' ' -- (python3 $__theme_sync_script --template $__theme_sync_template --output-dir $__theme_sync_cache --query 2>/dev/null))
        if test (count $reply) -eq 2; and test -f $reply[1]
            set -g __theme_sync_scheme $reply[2]
            set -gx STARSHIP_CONFIG $reply[1]
            return 0
        end
    end
    return 1
end

function __theme_sync_on_change --on-variable fish_terminal_color_theme
    contains -- "$fish_terminal_color_theme" light dark; or return
    # fish's first report after startup describes the colors we already read.
    if not set -q __theme_sync_seen_report
        set -g __theme_sync_seen_report
        test "$fish_terminal_color_theme" = "$__theme_sync_scheme"; and return
    end
    __theme_sync_apply; and commandline -f repaint
end

# Switching between two themes of the same kind (e.g. one dark Rex theme to
# another, or a Ghostty config reload) sends no notification, so also re-read
# the palette when the terminal regains focus: changing the theme means
# clicking away to the settings and back. fish itself only enables focus
# reporting under tmux, so turn it on while the prompt is showing and off while
# a command runs (programs that don't expect focus events would see \e[I/\e[O).
if test "$TERM" != dumb
    function __theme_sync_focus_on --on-event fish_prompt
        test -t 1; or return
        printf '\e[?1004h'
        set -g __theme_sync_focus_reporting
    end
    function __theme_sync_focus_off --on-event fish_preexec --on-event fish_exit
        set -q __theme_sync_focus_reporting; or return
        set -e __theme_sync_focus_reporting
        printf '\e[?1004l'
    end
    function __theme_sync_on_focus --on-event fish_focus_in
        set -l old $STARSHIP_CONFIG
        __theme_sync_apply
        and test "$STARSHIP_CONFIG" != "$old"
        and commandline -f repaint
    end
end

function theme-sync --description 'Re-read the terminal colors and regenerate the Starship palette'
    # Regenerate even if a cached file exists (e.g. after editing the template).
    set -l cached $__theme_sync_cache/*.toml
    test -n "$cached[1]"; and command rm -f $cached
    if __theme_sync_apply
        echo "Starship palette synced from terminal colors ($__theme_sync_scheme): $STARSHIP_CONFIG"
    else
        echo "Terminal did not report its colors; using $STARSHIP_CONFIG" >&2
        return 1
    end
end
function sync-starship-theme --wraps theme-sync --description 'Alias for theme-sync'
    theme-sync $argv
end

# Terminal didn't answer (no tty, very old terminal, some multiplexers): keep a
# config inherited from the parent shell if it still exists, else the template.
if not __theme_sync_apply
    set -q STARSHIP_CONFIG; and test -f "$STARSHIP_CONFIG"
    or set -gx STARSHIP_CONFIG $__theme_sync_template
end
