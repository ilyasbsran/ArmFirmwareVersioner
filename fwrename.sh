#!/bin/bash

# Get the project directory (assumes the script is run from the Debug folder)
PROJECT_DIR=$(dirname "$(pwd)")
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Define the header file paths (assuming they are in the same directory as this script)
SCRIPT_DIR=$(dirname "$0")
BOARD_NAME_FILE="$SCRIPT_DIR/board_name.h"
GIT_VERSION_FILE="$SCRIPT_DIR/version.h"

# Find first .elf file in the current directory
ELF_FILE=$(find . -maxdepth 1 -name '*.elf' | head -n 1)

if [ -z "$ELF_FILE" ]; then
  echo "[ERROR] No .elf file found in current directory!"
  exit 1
fi

# Extract all BOARD_NAME_STR candidates from board_name.h
CANDIDATES=$(grep '#define BOARD_NAME_STR' "$BOARD_NAME_FILE" | cut -d '"' -f2)

# Initialize an empty array to store matched candidates
MATCHES=()

# Iterate over all candidate board names extracted from board_name.h
for candidate in $CANDIDATES; do
    # Search for the candidate as a whole word in the ELF file's strings
    ELF_MATCH=$(strings "$ELF_FILE" | grep -m1 -wF "$candidate")

    # If a match is found, add it to the MATCHES array and print info
    if [ -n "$ELF_MATCH" ]; then
        MATCHES+=("$candidate")
    fi
done

# Evaluate results
if [ "${#MATCHES[@]}" -eq 0 ]; then
  echo "[ERROR] No BOARD_NAME string found in ELF! Did you forget to define one?"
  exit 1
elif [ "${#MATCHES[@]}" -gt 1 ]; then
  echo "[ERROR] Multiple BOARD_NAME values found in ELF: ${MATCHES[*]}"
  echo "[ERROR] Make sure only one board macro is defined during build!"
  exit 1
else
  BOARD_NAME="${MATCHES[0]}"
fi

# Extract all BOARD_VERSION_NAME_STR candidates from board_name.h
CANDIDATES=$(grep '#define BOARD_VERSION_NAME_STR' "$BOARD_NAME_FILE" | cut -d '"' -f2)

# Initialize an empty array to store matched candidates
MATCHES=()

# Iterate over all candidate board version names extracted from board_name.h
for candidate in $CANDIDATES; do
    # Search for the candidate as a whole word in the ELF file's strings
    ELF_MATCH=$(strings "$ELF_FILE" | grep -m1 -wF "$candidate")

    # If a match is found, add it to the MATCHES array and print info
    if [ -n "$ELF_MATCH" ]; then
        MATCHES+=("$candidate")
    fi
done

# Evaluate results
if [ "${#MATCHES[@]}" -eq 0 ]; then
  echo "[ERROR] No BOARD_VERSION_NAME string found in ELF! Did you forget to define one?"
  exit 1
elif [ "${#MATCHES[@]}" -gt 1 ]; then
  echo "[ERROR] Multiple BOARD_VERSION_NAME values found in ELF: ${MATCHES[*]}"
  echo "[ERROR] Make sure only one board version macro is defined during build!"
  exit 1
else
  BOARD_VERSION_NAME="${MATCHES[0]}"
fi


# Extract GIT_VERSION from version.h
GIT_VERSION=$(grep 'static const char\* GIT_VERSION' $GIT_VERSION_FILE | cut -d '"' -f2)

# Check if values are found
if [ -z "$BOARD_NAME" ] || [ -z "$BOARD_VERSION_NAME" ] || [ -z "$GIT_VERSION" ]; then
  echo "[ERROR] BOARD_NAME or BOARD_VERSION_NAME or GIT_VERSION not found in the header files!"
  exit 1
fi

# Clean up any previous .bin file NOT matching the project name in the Debug directory
find "$(pwd)" -type f -name "*.bin" ! -iname "${PROJECT_NAME}*.bin" -exec rm -f {} +

# Find the current .bin file in the Debug directory (not yet renamed)
BIN_FILE_PATH=$(find "$(pwd)" -name "*.bin" | grep -v -i "${PROJECT_NAME}_")

# Check if the .bin file exists
if [ -z "$BIN_FILE_PATH" ]; then
  echo "[ERROR] No new .bin file found in the Debug directory!"
  exit 1
fi

# Use full path for the new bin file
NEW_BIN_FILE="$(pwd)/${BOARD_NAME}_${BOARD_VERSION_NAME}_${GIT_VERSION}.bin"

# Log file paths for debugging
echo "NEW_BIN_FILE: $NEW_BIN_FILE"

# Rename the .bin file with the format BOARD_NAME_BOARD_VERSION_NAME_GIT_VERSION.bin
mv "$BIN_FILE_PATH" "$NEW_BIN_FILE"

# Check if renaming was successful
if [ $? -eq 0 ]; then
  :  # no-op (do nothing)
else
  echo "Error: Failed to rename $BIN_FILE_PATH"
  exit 1
fi