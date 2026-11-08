#!/bin/sh
# Finley Brain : installation en une commande.
#   curl -fsSL https://kryve.ai/emilie | sh
# Désinstaller : curl -fsSL https://kryve.ai/emilie | sh -s -- --uninstall
# Les autres options sont transmises à l'installeur : curl -fsSL https://kryve.ai/emilie | sh -s -- --help
#
# Ce script affiche le logo, vérifie le Mac, connecte GitHub si besoin, télécharge
# la version privée de Finley Brain dans un dossier temporaire, puis lance son
# installeur dans ton Terminal. Aucune clé n'est lue ni écrite ici.
set -eu

REPO="${FINLEY_BRAIN_REPO:-louislaurent1/finley-brain-emilie}"
REF="${FINLEY_BRAIN_REF:-main}"
TAG="Finley Brain"

# ── Logo kryve (le wordmark dessiné par Louis, case par case) ──────────────
# Chaque caractère = l'encre d'une case du Terminal, de 0 (vide) à f (pleine).
logo_map() {
  cat <<'MAP'
fff00000000000000000000000000000000000000000000000000000000000000000
fff00000000000000000000000000000000000000000000000000000000000000000
fff00000000000000000000000011000000110000000000000000000000000000000
fff00000006fff3fff09ffffdfffff50009ffffff0000000001fff07dffffffc4000
fff000007fff300ffffe732afd1afff0000fffeffa00000000ffffffe73124afff40
fff0009ffe20000fff30000ff004fff00004ff0eff3000000dfffff100000000cff4
fff0affe1000000fff00000a1002fff00002ff00fff000006fffff60000000000fff
ffffffff3000000fff0000000000fff0000df1001ffe0001ffeeffffffffffffffff
fff500dffe00000fff0000000000fff1007f600005ff800fff0bff40000000000000
fff00002fff9000fff0000000000fff207f8000000bff2cff100fff0000000000200
fff0000007fff40fff0000000000fff5cf500000000fffff60001fff91000017fff2
fff00000000dffefff0000000000fffff10000000000fffc0000005efffffffff700
0000000000000000000000000001fffa000000000000000000000000001221000000
000000000000000000022000001ffd00000000000000000000000000000000000000
000000000000000000dfff104dfc1000000000000000000000000000000000000000
0000000000000000001dffffc4000000000000000000000000000000000000000000
MAP
}

color_mode() {
  case "${FINLEY_BRAIN_COLOR:-}" in 24|256|none) echo "$FINLEY_BRAIN_COLOR"; return ;; esac
  [ -z "${NO_COLOR:-}" ] || { echo none; return; }
  case "${TERM:-dumb}" in dumb) echo none; return ;; esac
  case "${COLORTERM:-}" in *truecolor*|*24bit*) echo 24; return ;; esac
  case "${TERM_PROGRAM:-}" in
    iTerm.app|WezTerm|ghostty|vscode|WarpTerminal) echo 24; return ;;
    Apple_Terminal)
      # Terminal gère les couleurs 24 bits depuis macOS 26.
      v=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)
      [ "${v:-0}" -ge 26 ] 2>/dev/null && { echo 24; return; } ;;
  esac
  echo 256
}

banner() {
  # Le test du Terminal se fait ici : dans $(...), la sortie est un tube.
  if [ -t 1 ] || [ -n "${FINLEY_BRAIN_COLOR:-}" ]; then mode=$(color_mode); else mode=none; fi
  if [ "$mode" = none ]; then
    printf '\nkryve  |  %s, la mémoire de ton Finley\n\n' "$TAG"
    return 0
  fi
  logo_map | awk -v mode="$mode" -v tag="$TAG" '
    function hex(h,  i, v) { v = 0; for (i = 1; i <= length(h); i++) v = v * 16 + index("0123456789abcdef", substr(h, i, 1)) - 1; return v }
    function mix(a, b, t) { return int(a + (b - a) * t + 0.5) }
    function c256(r, g, b,   best, d, i, v, lv, ri, gi, bi, k) {
      # gris 232-255
      best = -1
      for (i = 0; i < 24; i++) { v = 8 + 10 * i; d = (r-v)^2 + (g-v)^2 + (b-v)^2; if (best < 0 || d < bd) { bd = d; best = 232 + i } }
      split("0 95 135 175 215 255", lv, " ")
      ri = near(r, lv); gi = near(g, lv); bi = near(b, lv)
      d = (r-lv[ri+1])^2 + (g-lv[gi+1])^2 + (b-lv[bi+1])^2
      if (d < bd) best = 16 + 36 * ri + 6 * gi + bi
      return best
    }
    function near(x, lv,   i, m, d, bd) { m = 0; bd = -1; for (i = 0; i < 6; i++) { d = (x - lv[i+1])^2; if (bd < 0 || d < bd) { bd = d; m = i } } return m }
    function fg(c,  p) { split(c, p, ","); return mode == 24 ? sprintf("\033[38;2;%d;%d;%dm", p[1], p[2], p[3]) : sprintf("\033[38;5;%dm", c256(p[1], p[2], p[3])) }
    function bg(c,  p) { split(c, p, ","); return mode == 24 ? sprintf("\033[48;2;%d;%d;%dm", p[1], p[2], p[3]) : sprintf("\033[48;5;%dm", c256(p[1], p[2], p[3])) }
    { row[NR] = $0; if (length($0) > w) w = length($0) }
    END {
      h = NR
      # Couleurs de la DA kryve : blanc cassé #EBEBEB, encre #222222, lavande #B9CEF9.
      split("235,235,235", CARD, ","); split("34,34,34", INK, ",")
      card = "235,235,235"; ink = "34,34,34"; lav = "185,206,249"
      # Une case du Terminal = un pixel, peint en couleur de fond : rien ne dépend
      # de la police (les demi-blocs laissent des stries dans Terminal).
      padx = 4; left = "  "
      W = w + 2 * padx
      blank = ""; for (i = 0; i < W; i++) blank = blank " "
      print left bg(card) blank "\033[0m"
      for (y = 1; y <= h; y++) {
        line = left bg(card) substr(blank, 1, padx); last = card
        for (x = 1; x <= w; x++) {
          t = hex(substr(row[y], x, 1)) / 15
          c = mix(CARD[1], INK[1], t) "," mix(CARD[2], INK[2], t) "," mix(CARD[3], INK[3], t)
          if (c != last) { line = line bg(c); last = c }
          line = line " "
        }
        print line bg(card) substr(blank, 1, padx) "\033[0m"
      }
      print left bg(card) blank "\033[0m"
      # Bandeau lavande : le nom et la promesse, encre #222.
      n = W - (3 + length(tag) + 29)   # «  ·  la mémoire de ton Finley » = 29 caractères visibles
      print left bg(lav) fg(ink) "\033[1m   " tag "\033[22m  ·  la mémoire de ton Finley" substr(blank, 1, n) "\033[0m"
    }'
  printf '\n'
}

# ── Messages ────────────────────────────────────────────────────────────────
say()  { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    ✓ %s\n' "$*"; }
die()  { printf '\nERREUR : %s\n' "$*" >&2; exit 1; }

has_tty() { [ -t 1 ] && (: </dev/tty) 2>/dev/null; }

# Lancé par « curl | sh », le script arrive sur l'entrée standard : tout est dans
# main(), lu en entier avant de s'exécuter, et les programmes lancés lisent le clavier.
run_attached() {
  if has_tty; then "$@" </dev/tty; else "$@" </dev/null; fi
}

gh_login() {
  info "GitHub va afficher un code : appuie sur Entrée, ton navigateur s'ouvre,"
  info "connecte-toi à GitHub, colle le code sur la page, puis reviens ici"
  "$GH" auth login --hostname github.com --git-protocol https --web </dev/tty \
    || die "connexion à GitHub interrompue. Relance la commande pour réessayer."
}

main() {
# ── Options ─────────────────────────────────────────────────────────────────
MODE=install
for a in "$@"; do
  case "$a" in
    --uninstall) MODE=uninstall ;;
    --banner) MODE=banner ;;
  esac
done

if [ "$MODE" = banner ]; then banner; exit 0; fi
if [ "$MODE" = uninstall ]; then
  # On retire --uninstall, le reste (--yes, --purge, --home, --dry-run) part à uninstall.sh.
  n=$#
  while [ "$n" -gt 0 ]; do
    a=$1; shift; n=$((n - 1))
    [ "$a" = --uninstall ] || set -- "$@" "$a"
  done
fi

banner

# ── 1. Le Mac ───────────────────────────────────────────────────────────────
[ "$(uname -s)" = Darwin ] || die "Finley Brain s'installe sur un Mac (macOS)."

if [ "$MODE" = uninstall ]; then
  say "Désinstallation"
  home="$HOME"
  prev=""
  for a in "$@"; do
    case "$a" in --home=*) home="${a#--home=}" ;; esac
    [ "$prev" = --home ] && home="$a"
    prev="$a"
  done
  un="$home/.finley-brain/bundle/uninstall.sh"
  [ -f "$un" ] || { info "Finley Brain n'est pas installé ici, rien à retirer."; exit 0; }
  info "ta mémoire (le dossier FinleyBrain) est gardée, seuls les réglages ajoutés sont retirés"
  status=0
  run_attached bash "$un" "$@" || status=$?
  exit "$status"
fi

[ "$(uname -m)" = arm64 ] || die "il faut un Mac avec une puce Apple (M1 ou plus récent)."
[ "$(id -u)" -ne 0 ] || die "lance la commande sans sudo, depuis ta session normale."
ok "Mac compatible (macOS $(sw_vers -productVersion 2>/dev/null))"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/finley-brain.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM

# ── 2. GitHub ───────────────────────────────────────────────────────────────
say "Connexion à GitHub"
GH=""
if command -v gh >/dev/null 2>&1; then
  GH=$(command -v gh)
else
  for p in /opt/homebrew/bin/gh /usr/local/bin/gh; do [ -x "$p" ] && GH=$p && break; done
fi
if [ -z "$GH" ]; then
  info "téléchargement de l'outil GitHub officiel (gh), juste pour cette installation"
  url=$(curl -fsSL --retry 2 https://api.github.com/repos/cli/cli/releases/latest 2>/dev/null \
        | grep -o '"browser_download_url": *"[^"]*_macOS_arm64\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/') || true
  [ -n "${url:-}" ] || die "impossible de trouver l'outil GitHub. Vérifie ta connexion, puis relance la commande."
  curl -fsSL --retry 2 -o "$tmp/gh.zip" "$url" || die "téléchargement de l'outil GitHub impossible. Relance la commande."
  (cd "$tmp" && unzip -q gh.zip) || die "archive de l'outil GitHub illisible. Relance la commande."
  GH=$(find "$tmp" -path '*/bin/gh' -type f | head -1)
  [ -n "$GH" ] && [ -x "$GH" ] || die "outil GitHub introuvable après téléchargement."
  ok "outil GitHub prêt"
fi

if ! "$GH" auth status --hostname github.com >/dev/null 2>&1; then
  has_tty || die "GitHub n'est pas connecté et ce Terminal ne permet pas de le faire. Lance la commande dans l'app Terminal."
  gh_login
fi
login=$("$GH" api user --jq .login 2>/dev/null || true)
ok "GitHub connecté${login:+ (compte $login)}"

if ! "$GH" api "repos/$REPO" --silent >/dev/null 2>&1 && has_tty; then
  printf '\n    Le compte %s n'"'"'a pas accès à Finley Brain.\n' "${login:-connecté}"
  printf '    Te connecter avec un autre compte GitHub ? (o/N) '
  read -r ans </dev/tty || ans=n
  case "$ans" in
    o|O|oui|Oui) gh_login; login=$("$GH" api user --jq .login 2>/dev/null || true) ;;
  esac
fi
if ! "$GH" api "repos/$REPO" --silent >/dev/null 2>&1; then
  die "ton compte GitHub${login:+ $login} n'a pas encore accès à Finley Brain.
       Envoie ce pseudo à kryve, accepte l'invitation reçue par mail de GitHub, puis relance la commande."
fi
ok "accès à Finley Brain confirmé"

# ── 3. Téléchargement ───────────────────────────────────────────────────────
say "Téléchargement de Finley Brain"
"$GH" api "repos/$REPO/tarball/$REF" >"$tmp/finley-brain.tar.gz" 2>"$tmp/gh.err" \
  || die "téléchargement impossible ($(head -c 200 "$tmp/gh.err")). Relance la commande."
mkdir -p "$tmp/src"
tar -xzf "$tmp/finley-brain.tar.gz" -C "$tmp/src" --strip-components 1 \
  || die "archive illisible. Relance la commande."
[ -f "$tmp/src/install.sh" ] || die "installeur absent du téléchargement. Préviens kryve."
ok "version téléchargée ($(du -sh "$tmp/src" | cut -f1 | tr -d ' '))"

# ── 4. Installation ─────────────────────────────────────────────────────────
say "Installation (la suite est guidée, elle te demandera tes deux clés)"
status=0
run_attached bash "$tmp/src/install.sh" "$@" || status=$?
exit "$status"
}

main "$@"
