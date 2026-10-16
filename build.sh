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
  echo "Fetching Dobby..."
  rm -rf _dobby_src _dobby _dobby_build
  git clone --depth 1 https://github.com/jmpews/Dobby.git _dobby_src

  echo "Building Dobby for iphoneos/arm64 via CMake ..."
  cmake -S _dobby_src -B _dobby_build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_SYSTEM_PROCESSOR=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_IOS" \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -DDOBBY_GENERATE_SHARED=OFF \
    -DDOBBY_DEBUG=OFF \
    -DDOBBY_BUILD_EXAMPLE=OFF \
    -DDOBBY_BUILD_TEST=OFF || echo "cmake configure failed"
  cmake --build _dobby_build --config Release -j 8 || echo "cmake build failed"

  mkdir -p _dobby
  find _dobby_build -name 'libdobby.a' -print -exec cp {} _dobby/ \; 2>/dev/null || true

  # Fallback: upstream helper script (its "import pipes" is dead code and breaks
  # on Python >= 3.13, so strip the line first).
  if [ ! -f _dobby/libdobby.a ]; then
    echo "CMake path produced nothing, falling back to platform_builder.py ..."
    sed -i '' '/^import pipes$/d' _dobby_src/scripts/platform_builder.py || true
    ( cd _dobby_src && python3 scripts/platform_builder.py --platform=iphoneos --arch=arm64 ) || true
    find _dobby_src -name 'libdobby.a' -print -exec cp {} _dobby/ \; 2>/dev/null || true
  fi

  find _dobby_src -name 'dobby.h' -print -exec cp {} _dobby/ \; 2>/dev/null || true
  test -f _dobby/libdobby.a || { echo "ERROR: libdobby.a not produced"; exit 1; }
  test -f _dobby/dobby.h    || { echo "ERROR: dobby.h not found"; exit 1; }
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
