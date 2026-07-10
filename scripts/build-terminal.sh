#!/usr/bin/env bash
# Assembles the entire profile terminal into one seamless SVG (dist/terminal-full.svg).
# Static strips come from assets/, live cards are fetched, pacman comes from dist/
# (when run inside the workflow) or the output branch (when run locally).
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
BASE="https://github-profile-summary-cards.vercel.app/api/cards"
U="GbaGuy"; T="tokyonight"

curl -fsSL "$BASE/profile-details?username=$U&theme=$T"      -o "$TMP/profile.svg"
curl -fsSL "$BASE/stats?username=$U&theme=$T"                -o "$TMP/stats.svg"
curl -fsSL "$BASE/repos-per-language?username=$U&theme=$T"   -o "$TMP/langs-repo.svg"
curl -fsSL "$BASE/most-commit-language?username=$U&theme=$T" -o "$TMP/langs-commit.svg"
if [ -f dist/pacman-contribution-graph-dark.svg ]; then
  cp dist/pacman-contribution-graph-dark.svg "$TMP/pacman.svg"
else
  curl -fsSL "https://raw.githubusercontent.com/GbaGuy/GbaGuy/output/pacman-contribution-graph-dark.svg" -o "$TMP/pacman.svg"
fi

root_tag() { head -c 4000 "$1" | tr '\n' ' ' | grep -o '<svg[^>]*' | head -1; }
w_of() { root_tag "$1" | grep -o 'width="[0-9.]*"'  | head -1 | grep -o '[0-9.]*'; }
h_of() { root_tag "$1" | grep -o 'height="[0-9.]*"' | head -1 | grep -o '[0-9.]*'; }
scale_h() { awk -v tw="$1" -v W="$2" -v H="$3" 'BEGIN{printf "%.2f", tw*H/W}'; }
add() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.2f", a+b}'; }
img() { printf '  <image x="%s" y="%s" width="%s" height="%s" href="data:image/svg+xml;base64,%s"/>\n' \
        "$2" "$3" "$4" "$5" "$(base64 -w0 "$1")"; }

# fixed-size local strips
H_HEADER=576; H_LINKS=56; H_STACK=132; H_CMDSTATS=44; H_BOTTOM=72

H_PROFILE=$(scale_h 900 "$(w_of "$TMP/profile.svg")" "$(h_of "$TMP/profile.svg")")
H_CARD=$(scale_h 300 "$(w_of "$TMP/stats.svg")" "$(h_of "$TMP/stats.svg")")
H_PACMAN=$(scale_h 900 "$(w_of "$TMP/pacman.svg")" "$(h_of "$TMP/pacman.svg")")

Y_LINKS=$H_HEADER
Y_STACK=$(add "$Y_LINKS" "$H_LINKS")
Y_CMDSTATS=$(add "$Y_STACK" "$H_STACK")
Y_PROFILE=$(add "$Y_CMDSTATS" "$H_CMDSTATS")
Y_CARDS=$(add "$Y_PROFILE" "$H_PROFILE")
Y_PACMAN=$(add "$Y_CARDS" "$H_CARD")
Y_BOTTOM=$(add "$Y_PACMAN" "$H_PACMAN")
TOTAL=$(add "$Y_BOTTOM" "$H_BOTTOM")

mkdir -p dist
{
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="900" height="%s" viewBox="0 0 900 %s">\n' "$TOTAL" "$TOTAL"
  printf '  <rect x="0.5" y="0.5" width="899" height="%s" rx="12" fill="#1a1b27"/>\n' "$(add "$TOTAL" -1)"
  img assets/term-header.svg        0   0            900 "$H_HEADER"
  img assets/term-link-linkedin.svg 0   "$Y_LINKS"   300 "$H_LINKS"
  img assets/term-link-gmail.svg    300 "$Y_LINKS"   300 "$H_LINKS"
  img assets/term-link-github.svg   600 "$Y_LINKS"   300 "$H_LINKS"
  img assets/term-stack.svg         0   "$Y_STACK"   900 "$H_STACK"
  img assets/term-cmd-stats.svg     0   "$Y_CMDSTATS" 900 "$H_CMDSTATS"
  img "$TMP/profile.svg"            0   "$Y_PROFILE" 900 "$H_PROFILE"
  img "$TMP/stats.svg"              0   "$Y_CARDS"   300 "$H_CARD"
  img "$TMP/langs-repo.svg"         300 "$Y_CARDS"   300 "$H_CARD"
  img "$TMP/langs-commit.svg"       600 "$Y_CARDS"   300 "$H_CARD"
  img "$TMP/pacman.svg"             0   "$Y_PACMAN"  900 "$H_PACMAN"
  img assets/term-bottom.svg        0   "$Y_BOTTOM"  900 "$H_BOTTOM"
  printf '  <rect x="0.5" y="0.5" width="899" height="%s" rx="12" fill="none" stroke="#3b4261"/>\n' "$(add "$TOTAL" -1)"
  printf '</svg>\n'
} > dist/terminal-full.svg

echo "built dist/terminal-full.svg (900 x $TOTAL)"
