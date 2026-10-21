#!/bin/sh
# Copies a downloaded MARS HOMER update over the install folder, then starts the app again
# (Raspberry Pi / Linux). Started by core/updater.gd after the app has quit.
# Usage: apply_update.sh <pid> <stage dir> <install dir> <executable>
# Old files are kept in .previous and put back if anything fails.
PID="$1"; STAGE="$2"; INSTALL="$3"; EXE="$4"
i=0
while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 120 ]; do sleep 0.5; i=$((i+1)); done
sleep 1
BACKUP="$INSTALL/.previous"
rm -rf "$BACKUP"; mkdir -p "$BACKUP"
LIST="$(mktemp)"
( cd "$STAGE" && find . -type f ) > "$LIST"
ok=1
DONE="$(mktemp)"
while IFS= read -r f; do
  rel="${f#./}"
  mkdir -p "$(dirname "$INSTALL/$rel")" "$(dirname "$BACKUP/$rel")"
  [ -f "$INSTALL/$rel" ] && cp -p "$INSTALL/$rel" "$BACKUP/$rel"
  if cp "$STAGE/$rel" "$INSTALL/$rel"; then echo "$rel" >> "$DONE"; else ok=0; break; fi
done < "$LIST"
if [ "$ok" -ne 1 ]; then
  while IFS= read -r rel; do
    [ -f "$BACKUP/$rel" ] && cp -p "$BACKUP/$rel" "$INSTALL/$rel"
  done < "$DONE"
fi
rm -f "$LIST" "$DONE"
# Zip extraction does not keep the executable bit.
chmod +x "$EXE" 2>/dev/null
cd "$INSTALL" || exit 1
nohup "$EXE" >/dev/null 2>&1 &
