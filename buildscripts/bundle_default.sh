#!/bin/bash -e
# 自定义版 bundle_default.sh（基于上游 v1.1.7）
# 改动：
#   1. 只编 arm64（build.sh --arch arm64），省 3/4 时间且少失败点
#   2. 修上游 bug：depinfo.sh 里 v_ndk=25.2.9519653，但原脚本硬编码
#      strip 到 ndk/27.3.13750724 —— 该路径根本不存在，必然失败。
#      现改为自动探测 sdk/android-sdk-linux/ndk/ 下实际安装的 NDK。

ARCH=arm64
ABI=arm64-v8a

# --------------------------------------------------

if [ ! -f "deps" ]; then
  sudo rm -r deps
fi
if [ ! -f "prefix" ]; then
  sudo rm -r prefix
fi

./download.sh
./patch.sh

# --------------------------------------------------

if [ ! -f "scripts/ffmpeg" ]; then
  rm scripts/ffmpeg.sh
fi
cp flavors/default.sh scripts/ffmpeg.sh

# --------------------------------------------------

./build.sh --arch ${ARCH}

zip -r debug-symbols-default.zip prefix/*/lib

# 自动探测实际安装的 NDK（修掉上游硬编码 27.3.13750724 的 bug）
NDK_DIR=$(ls -d ./sdk/android-sdk-linux/ndk/*/ 2>/dev/null | head -n 1)
if [ -z "${NDK_DIR}" ]; then
  echo "ERROR: 找不到 NDK，sdk/android-sdk-linux/ndk/ 下为空" >&2
  ls -la ./sdk/android-sdk-linux/ 2>&1 | head -20
  exit 1
fi
STRIP="${NDK_DIR}toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
echo "使用 NDK: ${NDK_DIR}"
echo "使用 strip: ${STRIP}"

"${STRIP}" --strip-all prefix/${ABI}/usr/local/lib/libmpv.so

# --------------------------------------------------

cd deps/media-kit-android-helper

sudo chmod +x gradlew
./gradlew assembleRelease

unzip -o app/build/outputs/apk/release/app-release.apk -d app/build/outputs/apk/release

cp ../../prefix/${ABI}/usr/local/lib/libmpv.so app/build/outputs/apk/release/lib/${ABI}

cd app/build/outputs/apk/release

zip -r default-${ABI}.jar lib/${ABI}/*.so

md5sum *.jar
