# unpack ARCHIVE DEST : ARCHIVE is the .tar.xz name; works whether it was stored whole or split into .part-NN files
unpack() {
  if [ -e "$1" ]; then xz -dc "$1" | tar -x -C "$2"
  elif ls "$1".part-* >/dev/null 2>&1; then cat "$1".part-* | xz -dc | tar -x -C "$2"
  else echo "missing archive: $1" >&2; return 1; fi
}
