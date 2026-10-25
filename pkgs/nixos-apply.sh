# nixos-apply: pull, build (nom), show what changed (nvd), switch, sync to GitHub, restart quickshell
# `nixos-apply -l` also signs you out afterwards, for changes that need a fresh session
cd "$HOME"/nixos-staging

# Catppuccin Mocha
rgb() { printf '\e[38;2;%sm' "$1"; }
mauve=$(rgb '203;166;247') blue=$(rgb '137;180;250') sky=$(rgb '137;220;235')
green=$(rgb '166;227;161') red=$(rgb '243;139;168') yellow=$(rgb '249;226;175')
overlay=$(rgb '108;112;134') bold=$'\e[1m' reset=$'\e[0m'
started=$SECONDS
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; printf "\e[?25h"' EXIT

step() { printf '\n  %s●%s %s%s%s\n' "$mauve" "$reset" "$bold" "$1" "$reset"; }
ok()   { printf '    %s✓%s %s\n' "$green" "$reset" "$1"; }
warn() { printf '    %s⚠%s %s\n' "$yellow" "$reset" "$1"; }
# Indent and dim a command's output so it reads as detail under the current step
quiet() { sed -u "s/^/    ${overlay}│${reset} /"; }

# spin "label" cmd...: braille spinner while cmd runs; its output is only shown if it fails
spin() {
  local label=$1 log="$tmp/spin.log" frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0 t=$SECONDS
  shift
  "$@" >"$log" 2>&1 &
  local pid=$!
  printf '\e[?25l'
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r    %s%s%s %s' "$sky" "${frames[i++ % 10]}" "$reset" "$label"
    sleep 0.08
  done
  printf '\r\e[K\e[?25h'
  if wait "$pid"; then
    ok "$label ${overlay}($((SECONDS - t))s)${reset}"
  else
    printf '    %s✗%s %s\n' "$red" "$reset" "$label"
    quiet <"$log"
    return 1
  fi
}

printf '\n'
# NixOS logo (fastfetch's nixos_old_small), two-tone
printf '%s%s%s\n' "$blue" '  \\  \\ //' "$reset"
printf '%s%s%s\n' "$blue" ' ==\\__\\/ //' "$reset"
printf '%s%s%s   %snixos-apply%s\n' "$sky" '   //   \\//' "$reset" "$bold" "$reset"
printf '%s%s%s    %s%s · %s%s\n' "$sky" '==//     //==' "$reset" "$overlay" "$(hostname)" "$(date '+%a %R')" "$reset"
printf '%s%s%s\n' "$blue" ' //\\___//' "$reset"
printf '%s%s%s\n' "$blue" '// /\\  \\==' "$reset"
# shellcheck disable=SC1003
printf '%s%s%s\n' "$blue" '  // \\  \\' "$reset"

step "sync"
before=$(git rev-parse HEAD)
# The mini pushes to the same repo (darwin-apply), so start from its latest commits
spin "pulling from github" git pull -q --rebase --autostash
pulled=$(git rev-list --count "$before"..HEAD)
[[ $pulled -gt 0 ]] && ok "$pulled new commit(s) from upstream"
# Flakes only see files git knows about, so pick up new ones before building
git add -A
changed=$(git diff --cached --name-only | wc -l)
[[ $changed -gt 0 ]] && ok "$changed local file(s) changed: ${overlay}$(git diff --cached --name-only | head -4 | xargs)${reset}"

step "build"
# nom draws the live build tree; builds as you, only activation needs root
nom build .#nixosConfigurations.nixos.config.system.build.toplevel --out-link "$tmp/system" --option warn-dirty false
new=$(readlink -f "$tmp/system")

step "changes"
if [[ $new == "$(readlink -f /run/current-system)" ]]; then
  ok "already running this exact system, nothing to switch"
  same=1
else
  # Skip nvd's <<< / >>> store-path header lines
  nvd diff /run/current-system "$new" | tail -n +3 | quiet
fi

if [[ -z ${same:-} ]]; then
  step "switch"
  sudo -v -p "    ${yellow}⚿${reset} sudo password: "
  # Already built above, so hand nixos-rebuild the result instead of evaluating again.
  # --no-reexec: it would otherwise try to build a matching nixos-rebuild from <nixpkgs/nixos>, which needs NIX_PATH.
  # Drop its own "Done. The new configuration is …" line, we print our own.
  nixos-rebuild switch --store-path "$new" --sudo --no-reexec 2>&1 | grep --line-buffered -v '^Done\.' | quiet
  ok "switched to ${overlay}$(basename "$new" | cut -c1-12)…${reset}"
  # Tools can move between profiles on a switch (git went to home-manager), so drop bash's cached paths
  hash -r
fi

step "publish"
# Publish what was just deployed to github.com/satherj/nixos-config (public!).
# gitleaks scans the staged changes first; anything that looks like a secret blocks the sync.
push() {
  git diff --cached --quiet || git commit -qm "nixos-apply $(date '+%F %R')"
  # Retry the push (also sends any earlier unpushed commits) so a Wi-Fi/DNS blip doesn't lose the sync
  for i in 1 2 3 4 5 6; do
    git push -q && return 0
    [[ $i -lt 6 ]] && { echo "git push failed, retrying in 5s ($i/6)…"; sleep 5; }
  done
  return 1
}
if ! spin "gitleaks scan" gitleaks git --pre-commit --staged --no-banner --log-level warn .; then
  git reset -q
  warn "gitleaks flagged something above, not syncing to GitHub"
elif ! spin "pushing to github" push; then
  warn "config sync to GitHub failed (try git push in ~/nixos-staging)"
fi

if [[ ${1:-} == "-l" || ${1:-} == "--logout" ]]; then
  step "logout"
  for s in 3 2 1; do printf '\r    signing out in %s%s%s… (Ctrl+C to stay)' "$yellow" "$s" "$reset"; sleep 1; done
  printf '\n'
  niri msg action quit --skip-confirmation
# qs kill instead of pkill: the process is named .quickshell-wrapped, so pkill -x never matched
elif qs kill -p /etc/quickshell >/dev/null 2>&1; then
  step "shell"
  spin "restarting quickshell" sh -c 'sleep 0.3; qs -p /etc/quickshell -d >/dev/null 2>&1'
fi

byes=("fresh snow on the system" "all flakes in place" "reproducibly yours" "the store is happy")
printf '\n  %s✻%s %sdone in %ss%s %s· %s%s\n\n' "$mauve" "$reset" "$bold" "$((SECONDS - started))" "$reset" \
  "$overlay" "${byes[RANDOM % ${#byes[@]}]}" "$reset"
