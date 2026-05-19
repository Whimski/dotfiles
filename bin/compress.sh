#!/bin/bash

find "$1" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | xargs -0 -I{} sh -c '


FILE="$1" 

DIR="$(dirname "$FILE")"
BASE="$(basename "$FILE")"

NAME="${BASE%.*}"
EXT="${BASE##*.}"
OUTPUT="$DIR/${NAME}.compressed.${EXT}"

case "${EXT,,}" in
  jpg|jpeg)
    magick "$FILE" \
      -strip \
      -quality 75 \
      "$OUTPUT"
    ;;
  png)
    magick "$FILE" \
      -strip \
      -quality 75 \
      "$OUTPUT"
    ;;
esac
' _ {}

# other compression 
#      -define png:compression-level=9 \
#      -define png:compression-filter=5 \
