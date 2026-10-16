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

# --- Dobby (iOS arm64 static lib, needed for the il2cpp inline hook) ---------
if [ ! -f _dobby/libdobby.a ]; then
  echo "Fetching + building Dobby for iphoneos/arm64 ..."
  rm -rf _dobby_src _dobby
  git clone --depth 1 https://github.com/jmpews/Dobby.git _dobby_src
  ( cd _dobby_src && python3 scripts/platform_builder.py --platform=iphoneos --arch=arm64 )
  mkdir -p _dobby
  find _dobby_src -name 'libdobby.a' -print -exec cp {} _dobby/ \;
  find _dobby_src -name 'dobby.h'    -print -exec cp {} _dobby/ \;
  test -f _dobby/libdobby.a || { echo "ERROR: libdobby.a not produced"; exit 1; }
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
  -I src -I _dobby -I _dobby_src \
  -framework Foundation \
  -lc++ \
  -install_name "@executable_path/Frameworks/${NAME}.dylib" \
  -o "$OUT/${NAME}.dylib" \
  src/main.m src/il2cpp_hook.m src/fishhook.c \
  _dobby/libdobby.a

echo "Built: $OUT/${NAME}.dylib"
file "$OUT/${NAME}.dylib" || true

# Ad-hoc sign (the app gets re-signed anyway; this keeps tools happy).
codesign -f -s - "$OUT/${NAME}.dylib" 2>/dev/null && echo "codesign: ad-hoc OK" || echo "codesign: skipped"
