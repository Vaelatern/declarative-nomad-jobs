#!/bin/bash

# Process multiple blocks repeatedly until EOF
while true; do
  # Read the first line as TGT_FILE
  if ! read -r TGT_FILE; then
    # EOF reached
    break
  fi

  # Skip empty lines or handle edge case
  [ -z "$TGT_FILE" ] && continue

  # Temporary file to collect content before base64
  temp_content=$(mktemp)

  # Read lines until '--' or EOF
  found_delim=0
  while IFS= read -r line; do
    if [ "$line" = "--" ]; then
      found_delim=1
      break
    fi
    printf '%s\n' "$line" >> "$temp_content"
  done

  # If we didn't find '--' but hit EOF, still process what we have
  if [ $found_delim -eq 0 ] && [ ! -s "$temp_content" ]; then
    rm -f "$temp_content"
    continue
  fi

  # Encode and write to target file
  ln -s "$TGT_FILE" "b64($(base64 "$temp_content" | tr -d '\n')).tpl"
  rm -f "$temp_content"
done
