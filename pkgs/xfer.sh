# xfer: move files between the Mac mini and the ThinkPad over Tailscale SSH (rsync).
# The wrapper in pkgs/xfer.nix sets XFER_PEER to the other machine's ssh name and puts rsync and ssh on PATH.

usage() {
  cat <<'EOF'
xfer send <file|dir>... [--to <dir>]         copy to the other machine; default dir ~/Transfer
xfer get <remote path>... [--to <dir>]       copy from the other machine; default local dir ~/Transfer
xfer get --latest <remote dir> [--to <dir>]  the newest file in that folder, e.g. ~/Pictures/Screenshots
xfer ls [<remote dir>]                       list a remote folder, newest first; default ~/Transfer

Prints the absolute path of everything copied, as it now sits on the receiving machine.
A name that already exists there is kept: the new copy gets " (2)", " (3)"... before the extension.
Quote a remote ~ ('~/Pictures') so this machine doesn't expand it to its own home.
EOF
}

die() {
  echo "xfer: $*" >&2
  exit 1
}

peer="${XFER_PEER:?XFER_PEER is not set}"
rsync_path=/run/current-system/sw/bin/rsync
notify_path=/run/current-system/sw/bin/xfer-notify
tilde='~' # a literal ~, for the patterns below
default_dir="$tilde/Transfer"

# Fish reads \' and \\ inside single quotes as escapes, bash doesn't, so no quoting is right for both.
# Refuse a backslash in anything that goes into a remote shell command.
nobs() {
  [[ $1 != *\\* ]] || die "backslash in a name or path is not supported: $1"
}

# Single-quote for the remote shell (bash on the ThinkPad, fish on the mini: both read '\'' as a quote)
shq() {
  printf "'%s'" "${1//\'/\'\\\'\'}"
}

rssh() {
  ssh -n -o BatchMode=yes -o ConnectTimeout=10 "$peer" "$@"
}

# A path on the other machine, relative to its home when it starts with ~/ or with this machine's home
# (an unquoted ~ was already expanded here, and the two homes differ)
rpath() {
  local p=$1
  case "$p" in
    "$tilde") p=. ;;
    "$tilde"/*) p=${p#"$tilde"/} ;;
    "$HOME") p=. ;;
    "$HOME"/*) p=${p#"$HOME"/} ;;
  esac
  [[ -n $p ]] || p=.
  [[ $p == / ]] || p=${p%/}
  printf '%s\n' "$p"
}

# A path on this machine, with a leading ~/ expanded
lpath() {
  case "$1" in
    "$tilde") printf '%s\n' "$HOME" ;;
    "$tilde"/*) printf '%s\n' "$HOME/${1#"$tilde"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# $1 = path from rpath, $2 = the other machine's home
rabs() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    .) printf '%s\n' "$2" ;;
    *) printf '%s\n' "$2/$1" ;;
  esac
}

# The first of "name", "name (2).ext", "name (3).ext"... not in the newline-separated list $2. $3 = 1 for a folder.
free_name() {
  local name=$1 taken=$2 isdir=$3 base ext="" n=2 cand
  if ! grep -qxF -- "$name" <<<"$taken"; then
    printf '%s\n' "$name"
    return
  fi
  base=$name
  if [[ $isdir != 1 && $name == ?*.* ]]; then
    ext=".${name##*.}"
    base=${name%.*}
  fi
  while :; do
    cand="$base ($n)$ext"
    if ! grep -qxF -- "$cand" <<<"$taken"; then
      printf '%s\n' "$cand"
      return
    fi
    n=$((n + 1))
  done
}

# Never deletes or overwrites: --ignore-existing on top of the free name. -s keeps names with spaces intact.
do_rsync() {
  rsync -a -s --ignore-existing --rsync-path="$rsync_path" "$@" || die "rsync failed"
}

remote_home() {
  # shellcheck disable=SC2016  # $HOME is for the remote shell
  rssh 'echo $HOME' || die "cannot reach $peer over ssh"
}

cmd_send() {
  local to=$default_dir srcs=() src rdir rhome rabsdir taken name newname isdir names=()
  while (($#)); do
    case "$1" in
      --to) [[ $# -ge 2 ]] || die "--to needs a folder"; to=$2; shift 2 ;;
      --to=*) to=${1#--to=}; shift ;;
      -*) die "unknown option $1 (xfer --help)" ;;
      *) srcs+=("$1"); shift ;;
    esac
  done
  ((${#srcs[@]})) || die "send what? (xfer --help)"
  # Absolute, so a name with a colon or leading dash is never read by rsync as a host or option, and . and .. have a name
  local abs=()
  for src in "${srcs[@]}"; do
    src=${src%/}
    [[ -e $src ]] || die "no such file or folder: $src"
    if [[ -d $src ]]; then
      src=$(cd -- "$src" && pwd)
    elif [[ $src != /* ]]; then
      src=$PWD/$src
    fi
    abs+=("$src")
  done
  srcs=("${abs[@]}")

  nobs "$to"
  for src in "${srcs[@]}"; do
    nobs "$(basename -- "${src%/}")"
  done
  rdir=$(rpath "$to")
  rhome=$(remote_home)
  rabsdir=$(rabs "$rdir" "$rhome")
  taken=$(rssh "mkdir -p $(shq "$rdir") && command ls -1A -- $(shq "$rdir")") || die "cannot prepare $to on $peer"

  for src in "${srcs[@]}"; do
    src=${src%/}
    name=$(basename -- "$src")
    isdir=0
    [[ -d $src ]] && isdir=1
    newname=$(free_name "$name" "$taken" "$isdir")
    taken+=$'\n'"$newname"
    if ((isdir)); then
      do_rsync "$src/" "$peer:$rdir/$newname/"
    else
      do_rsync "$src" "$peer:$rdir/$newname"
    fi
    printf '%s\n' "$rabsdir/$newname"
    names+=("$newname")
  done

  # A desktop notification where one is installed (the ThinkPad); the mini has none, and a failure only warns
  local args
  args=$(shq "$to")
  for name in "${names[@]}"; do
    args+=" $(shq "$name")"
  done
  rssh "test ! -x $notify_path || $notify_path $args" || echo "xfer: warning: could not notify $peer" >&2
}

cmd_get() {
  local to=$default_dir latest=0 remotes=() r rp name newname dest taken rc isdir
  while (($#)); do
    case "$1" in
      --to) [[ $# -ge 2 ]] || die "--to needs a folder"; to=$2; shift 2 ;;
      --to=*) to=${1#--to=}; shift ;;
      --latest) latest=1; shift ;;
      -*) die "unknown option $1 (xfer --help)" ;;
      *) remotes+=("$1"); shift ;;
    esac
  done
  ((${#remotes[@]})) || die "get what? (xfer --help)"
  if ((latest)); then
    [[ ${#remotes[@]} -eq 1 ]] || die "--latest takes one folder"
    rp=$(rpath "${remotes[0]}")
    nobs "$rp"
    name=$(rssh "command ls -1tp -- $(shq "$rp")") || die "cannot list ${remotes[0]} on $peer"
    name=$(grep -v '/$' <<<"$name" | head -n 1 || true)
    [[ -n $name ]] || die "no files in ${remotes[0]} on $peer"
    nobs "$name"
    remotes=("$rp/$name")
  fi

  dest=$(lpath "$to")
  mkdir -p -- "$dest"
  dest=$(cd -- "$dest" && pwd)
  taken=$(command ls -1A -- "$dest")

  for r in "${remotes[@]}"; do
    rp=$(rpath "$r")
    nobs "$rp"
    rc=0
    rssh "test -d $(shq "$rp")" || rc=$?
    case "$rc" in
      0) isdir=1 ;;
      1)
        isdir=0
        rssh "test -e $(shq "$rp")" || die "no such file or folder on $peer: $r"
        ;;
      *) die "cannot reach $peer over ssh" ;;
    esac
    name=$(basename -- "$rp")
    newname=$(free_name "$name" "$taken" "$isdir")
    taken+=$'\n'"$newname"
    if ((isdir)); then
      do_rsync "$peer:$rp/" "$dest/$newname/"
    else
      do_rsync "$peer:$rp" "$dest/$newname"
    fi
    printf '%s\n' "$dest/$newname"
  done
}

cmd_ls() {
  local dir=${1:-$default_dir}
  [[ $# -le 1 ]] || die "ls takes one folder"
  nobs "$dir"
  rssh "command ls -1tp -- $(shq "$(rpath "$dir")")" || die "cannot list $dir on $peer"
}

case "${1:-}" in
  send) shift; cmd_send "$@" ;;
  get) shift; cmd_get "$@" ;;
  ls) shift; cmd_ls "$@" ;;
  -h | --help | help | "") usage ;;
  *) die "unknown command $1 (xfer --help)" ;;
esac
