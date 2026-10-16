#!/bin/bash
# Builds StandRework.dylib for iOS arm64. Run on macOS (or in GitHub Actions).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

MIN_IOS="${MIN_IOS:-15.0}"
OUT="build"
NAME="StandRework"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "iOS SDK: $SDK"

# --- fetch fishhook (single .c/.h, MIT) if not vendored ---------------------
if [ ! -f src/fishhook.c ]; then
  echo "Fetching fishhook..."
  rm -rf _fishhook
  git clone --depth 1 https://github.com/facebook/fishhook.git _fishhook
  cp _fishhook/fishhook.h _fishhook/fishhook.c src/
fi

mkdir -p "$OUT"

echo "Compiling ${NAME}.dylib ..."
xcrun --sdk iphoneos clang \
  -dynamiclib \
  -arch arm64 \
  -isysroot "$SDK" \
  -miphoneos-version-min="$MIN_IOS" \
  -O2 -fobjc-arc \
  -fvisibility=default \
  -framework Foundation \
  -install_name "@executable_path/Frameworks/${NAME}.dylib" \
  -o "$OUT/${NAME}.dylib" \
  src/main.m src/fishhook.c

echo "Built: $OUT/${NAME}.dylib"
file "$OUT/${NAME}.dylib" || true

# Ad-hoc sign (the app gets re-signed anyway; this keeps tools happy).
codesign -f -s - "$OUT/${NAME}.dylib" 2>/dev/null && echo "codesign: ad-hoc OK" || echo "codesign: skipped"
