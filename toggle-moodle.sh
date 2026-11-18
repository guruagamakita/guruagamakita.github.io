#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ( $1 != online && $1 != offline ) ]]; then
  echo "Penggunaan: $0 online|offline" >&2
  exit 1
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mode=$1
config=moodle/config.json
php_config=/var/www/html/moodle/config.php
state_dir="${HOME:?HOME tidak diatur}/.cache/moodle-toggle"
pid_file="$state_dir/tunnel.pid"
local_root=http://localhost/moodle

for command in git python3 sudo; do
  command -v "$command" >/dev/null || { echo "Perintah tidak ditemukan: $command" >&2; exit 1; }
done
if [[ $mode == online ]]; then
  command -v cloudflared >/dev/null || { echo "cloudflared tidak ditemukan" >&2; exit 1; }
fi
git ls-files --error-unmatch -- "$config" >/dev/null || {
  echo "Commit $config sebelum menjalankan skrip." >&2; exit 1;
}
if ! git diff --quiet -- "$config" || ! git diff --cached --quiet -- "$config"; then
  echo "$config memiliki perubahan lokal atau staged; simpan terlebih dahulu." >&2
  exit 1
fi
sudo -v
mkdir -p -- "$state_dir"
if ! mkdir -- "$state_dir/lock" 2>/dev/null; then
  echo "Skrip lain sedang berjalan atau lock tersisa di $state_dir/lock." >&2
  exit 1
fi
trap 'rmdir -- "$state_dir/lock"' EXIT

is_our_tunnel() {
  local pid=$1
  local -a args=()
  [[ $pid =~ ^[0-9]+$ && -r /proc/$pid/cmdline ]] || return 1
  mapfile -d '' -t args < "/proc/$pid/cmdline"
  [[ ${#args[@]} -ge 4 && ${args[0]##*/} == cloudflared &&
     ${args[1]} == tunnel && ${args[2]} == --url && ${args[3]} == "$local_root" ]]
}

set_wwwroot() {
  sudo python3 -c '
import os, re, sys, tempfile
path, url = sys.argv[1:]
if os.path.islink(path):
    sys.exit("config.php berupa symlink; ubah wwwroot secara manual.")
with open(path, encoding="utf-8", newline="") as f:
    data = f.read()
pattern = r"^([ \t]*\$CFG->wwwroot[ \t]*=[ \t]*)([\"\x27])[^\r\n\"\x27]*\2([ \t]*;)"
data, count = re.subn(pattern, lambda m: m.group(1) + repr(url) + m.group(3), data, flags=re.MULTILINE)
if count != 1:
    sys.exit("config.php harus memiliki tepat satu penetapan $CFG->wwwroot.")
stat = os.stat(path)
fd, temp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".moodle-config-")
try:
    with os.fdopen(fd, "w", encoding="utf-8", newline="") as f:
        f.write(data)
    os.chmod(temp, stat.st_mode)
    os.chown(temp, stat.st_uid, stat.st_gid)
    os.replace(temp, path)
finally:
    if os.path.exists(temp):
        os.unlink(temp)
' "$php_config" "$1"
}

set_portal() {
  python3 -c '
import json, os, sys, tempfile
path, mode, url = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
data["mode"] = mode
if mode == "online":
    data["online_url"] = url
fd, temp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".moodle-config-")
try:
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.chmod(temp, os.stat(path).st_mode)
    os.replace(temp, path)
finally:
    if os.path.exists(temp):
        os.unlink(temp)
' "$config" "$mode" "$1"
}

pid=
if [[ -f $pid_file ]]; then
  read -r pid < "$pid_file" || { echo "PID tunnel tidak dapat dibaca." >&2; exit 1; }
  if [[ ! $pid =~ ^[0-9]+$ ]]; then
    echo "PID tunnel tidak valid di $pid_file." >&2; exit 1
  fi
  if kill -0 "$pid" 2>/dev/null && ! is_our_tunnel "$pid"; then
    echo "PID $pid bukan tunnel Moodle yang dikenali; tidak akan dihentikan." >&2; exit 1
  fi
fi

if [[ $mode == online ]]; then
  if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Tunnel Moodle sudah berjalan (PID $pid); jalankan offline terlebih dahulu." >&2; exit 1
  fi
  log=$(mktemp "$state_dir/tunnel.XXXXXXXX.log")
  nohup cloudflared tunnel --url "$local_root" > "$log" 2>&1 < /dev/null &
  pid=$!
  printf '%s\n' "$pid" > "$pid_file"
  url=
  for ((i=0; i<60; i++)); do
    url=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$log" | head -n 1 || true)
    [[ -n $url ]] && break
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 1
  done
  if [[ -z $url ]] || ! kill -0 "$pid" 2>/dev/null; then
    if is_our_tunnel "$pid"; then kill "$pid"; fi
    rm -f -- "$pid_file"
    echo "Tunnel gagal mendapatkan URL. Periksa $log." >&2
    exit 1
  fi
  if ! set_wwwroot "$url"; then
    if is_our_tunnel "$pid"; then kill "$pid"; fi
    rm -f -- "$pid_file"
    echo "Gagal mengubah wwwroot; tunnel dihentikan." >&2
    exit 1
  fi
  if ! set_portal "$url"; then
    echo "Gagal mengubah portal; tunnel dan wwwroot online masih aktif (PID $pid)." >&2
    exit 1
  fi
  message="Moodle Online"
else
  set_wwwroot "$local_root"
  set_portal ""
  if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
  fi
  rm -f -- "$pid_file"
  message="Moodle Offline"
fi

git add -- "$config"
if ! git diff --cached --quiet -- "$config"; then
  git commit --only -m "$message" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" -- "$config"
else
  echo "Konfigurasi portal tidak berubah; tidak ada commit baru."
fi
git push
