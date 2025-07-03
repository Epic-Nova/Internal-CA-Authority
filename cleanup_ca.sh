#!/bin/bash

set -e

# Paths to CA files - adjust if necessary
CA_DIR="./epicnova-ca"
INDEX_FILE="$CA_DIR/index.txt"
SERIAL_FILE="$CA_DIR/serial"

echo "🔄 Cleaning up CA database and resetting serial number..."

# Clear index.txt (deletes all issued cert records)
if [ -f "$INDEX_FILE" ]; then
  echo "Clearing index database ($INDEX_FILE)..."
  > "$INDEX_FILE"
else
  echo "Warning: index file $INDEX_FILE does not exist."
fi

# Reset serial number to 1000 (or desired starting value)
echo "Resetting serial number in $SERIAL_FILE to 1000..."
echo "1000" > "$SERIAL_FILE"

echo "✅ CA cleanup done. index.txt cleared and serial reset to 1000."