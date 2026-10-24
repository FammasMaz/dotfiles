/*
 * termpalette: ask the terminal for its real colors (OSC 4 0-15, OSC 10, OSC 11).
 *
 * Works in any terminal that answers xterm color queries (Ghostty, Rex, kitty,
 * WezTerm, iTerm2, foot, ...), locally or over SSH. A DA1 request is sent last
 * as a sentinel: every terminal answers it, so we stop as soon as it arrives
 * instead of waiting for a timeout.
 *
 * Output (one line, exit 0):
 *   <fnv1a-hash> <dark|light> <bg> <fg> <c0> ... <c15>
 * Exit 1 when the terminal did not report all 18 colors, 2 when there is no tty.
 *
 * Bytes that are not query replies (typeahead) are pushed back with TIOCSTI
 * where the OS allows it.
 *
 * Env: TERMPALETTE_TIMEOUT_MS (default 300; only reached if the terminal never
 *      answers DA1), TERMPALETTE_DEBUG=1 dumps the raw replies to stderr.
 *
 * Build: cc -O2 -o termpalette termpalette.c   (config/fish/theme-sync.fish
 *        builds it into ~/.cache/dotfiles/ on first use)
 */
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#define NCOLORS 18 /* 0 = bg, 1 = fg, 2..17 = ANSI 0..15 */

static int tty_fd = -1;
static struct termios saved;
static int have_saved = 0;

static void restore(void) {
    if (have_saved) tcsetattr(tty_fd, TCSANOW, &saved);
}

static void on_signal(int sig) {
    restore();
    signal(sig, SIG_DFL);
    raise(sig);
}

static long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

static int hexval(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* Parse one "h", "hh", "hhh" or "hhhh" component, scaled to 0..255. */
static int parse_component(const char **p, int *out) {
    unsigned long v = 0, max = 0;
    int n = 0;
    while (n < 4 && hexval(**p) >= 0) {
        v = v * 16 + (unsigned long)hexval(**p);
        max = max * 16 + 15;
        (*p)++;
        n++;
    }
    if (n == 0) return 0;
    *out = (int)((v * 255 + max / 2) / max);
    return 1;
}

/* Parse "rgb:R/G/B" or "rgba:R/G/B/A" into #rrggbb. */
static int parse_rgb(const char *s, char out[8]) {
    int r, g, b;
    if (strncmp(s, "rgba:", 5) == 0) s += 5;
    else if (strncmp(s, "rgb:", 4) == 0) s += 4;
    else return 0;
    if (!parse_component(&s, &r) || *s++ != '/') return 0;
    if (!parse_component(&s, &g) || *s++ != '/') return 0;
    if (!parse_component(&s, &b)) return 0;
    snprintf(out, 8, "#%02x%02x%02x", r, g, b);
    return 1;
}

static void handle_osc(const char *body, char colors[NCOLORS][8], int *have) {
    int slot = -1;
    const char *value = NULL;
    if (strncmp(body, "4;", 2) == 0) {
        char *end;
        long idx = strtol(body + 2, &end, 10);
        if (end != body + 2 && *end == ';' && idx >= 0 && idx < 16) {
            slot = 2 + (int)idx;
            value = end + 1;
        }
    } else if (strncmp(body, "10;", 3) == 0) {
        slot = 1;
        value = body + 3;
    } else if (strncmp(body, "11;", 3) == 0) {
        slot = 0;
        value = body + 3;
    }
    if (slot >= 0 && !have[slot] && parse_rgb(value, colors[slot])) have[slot] = 1;
}

/* Same light/dark rule as Neovim's 'background' detection. */
static int is_dark(const char *hex) {
    int r = hexval(hex[1]) * 16 + hexval(hex[2]);
    int g = hexval(hex[3]) * 16 + hexval(hex[4]);
    int b = hexval(hex[5]) * 16 + hexval(hex[6]);
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0 < 0.5;
}

int main(void) {
    int timeout_ms = 300;
    const char *env = getenv("TERMPALETTE_TIMEOUT_MS");
    if (env && atoi(env) > 0) timeout_ms = atoi(env);

    tty_fd = open("/dev/tty", O_RDWR | O_NOCTTY);
    if (tty_fd < 0 || tcgetattr(tty_fd, &saved) < 0) return 2;
    have_saved = 1;
    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    signal(SIGHUP, on_signal);

    struct termios raw = saved;
    raw.c_lflag &= ~(tcflag_t)(ICANON | ECHO);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    if (tcsetattr(tty_fd, TCSANOW, &raw) < 0) return 2;

    char query[512];
    int qlen = 0;
    for (int i = 0; i < 16; i++) qlen += snprintf(query + qlen, sizeof query - (size_t)qlen, "\033]4;%d;?\033\\", i);
    qlen += snprintf(query + qlen, sizeof query - (size_t)qlen, "\033]10;?\033\\\033]11;?\033\\\033[c");
    if (write(tty_fd, query, (size_t)qlen) != qlen) {
        restore();
        return 2;
    }

    char buf[8192];
    size_t len = 0;
    int got_da1 = 0;
    long deadline = now_ms() + timeout_ms;
    while (!got_da1 && len < sizeof buf - 1) {
        long left = deadline - now_ms();
        if (left <= 0) break;
        /* select(), not poll(): macOS poll() does not support tty devices. */
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(tty_fd, &rfds);
        struct timeval tv = {left / 1000, (int)(left % 1000) * 1000};
        if (select(tty_fd + 1, &rfds, NULL, NULL, &tv) <= 0) break;
        ssize_t n = read(tty_fd, buf + len, sizeof buf - 1 - len);
        if (n <= 0) break;
        len += (size_t)n;
        /* DA1 reply: ESC [ ? <params> c */
        for (size_t i = 0; i + 2 < len; i++) {
            if (buf[i] == '\033' && buf[i + 1] == '[' && buf[i + 2] == '?') {
                size_t j = i + 3;
                while (j < len && ((buf[j] >= '0' && buf[j] <= '9') || buf[j] == ';')) j++;
                if (j < len && buf[j] == 'c') {
                    got_da1 = 1;
                    break;
                }
            }
        }
    }
    restore();
    buf[len] = '\0';
    if (getenv("TERMPALETTE_DEBUG")) {
        for (size_t i = 0; i < len; i++) fprintf(stderr, (buf[i] < 32 || buf[i] > 126) ? "\\x%02x" : "%c", (unsigned char)buf[i]);
        fprintf(stderr, "\n[%zu bytes, da1=%d]\n", len, got_da1);
    }

    char colors[NCOLORS][8];
    int have[NCOLORS] = {0};
    char pushback[8192];
    size_t plen = 0;

    for (size_t i = 0; i < len;) {
        if (buf[i] == '\033' && i + 1 < len && buf[i + 1] == ']') {
            /* OSC ... (BEL | ESC \) */
            size_t j = i + 2;
            while (j < len && buf[j] != '\007' && !(buf[j] == '\033' && j + 1 < len && buf[j + 1] == '\\')) j++;
            if (j >= len) break; /* truncated reply: drop it */
            char saved_c = buf[j];
            buf[j] = '\0';
            handle_osc(buf + i + 2, colors, have);
            buf[j] = saved_c;
            i = j + (buf[j] == '\007' ? 1 : 2);
            continue;
        }
        if (buf[i] == '\033' && i + 2 < len && buf[i + 1] == '[' && buf[i + 2] == '?') {
            size_t j = i + 3;
            while (j < len && ((buf[j] >= '0' && buf[j] <= '9') || buf[j] == ';')) j++;
            if (j < len && buf[j] == 'c') {
                i = j + 1; /* our DA1 sentinel */
                continue;
            }
        }
        pushback[plen++] = buf[i++];
    }

#ifdef TIOCSTI
    for (size_t i = 0; i < plen; i++) ioctl(tty_fd, TIOCSTI, &pushback[i]);
#endif
    close(tty_fd);

    for (int i = 0; i < NCOLORS; i++)
        if (!have[i]) return 1;

    char line[256];
    int off = 0;
    for (int i = 0; i < NCOLORS; i++) off += snprintf(line + off, sizeof line - (size_t)off, " %s", colors[i]);

    unsigned int hash = 2166136261u;
    for (int i = 0; i < off; i++) {
        hash ^= (unsigned char)line[i];
        hash *= 16777619u;
    }
    printf("%08x %s%s\n", hash, is_dark(colors[0]) ? "dark" : "light", line);
    return 0;
}
