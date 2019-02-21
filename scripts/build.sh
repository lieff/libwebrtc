pushd $(dirname "$0")/../build
set -e

case "$OSTYPE" in
  darwin*)      PLATFORM=macos ;;
  linux*)       PLATFORM=linux ;;
  win32*|msys*) PLATFORM=win ;;
  *)            echo "Building on unsupported OS: $OSTYPE"; exit 1; ;;
esac

if [ "$PLATFORM" = "linux" ]; then
if [ "$TRAVIS" = "true" ]; then
export DEBIAN_FRONTEND="noninteractive"
apt-get update -qq
apt-get install -qq -y git yasm build-essential curl wget rsync \
 flex bison bzip2 zip p7zip fakeroot patch pkg-config python \
 libappindicator3-dev libasound2-dev libatspi2.0-dev libbrlapi-dev libbz2-dev libcairo2-dev \
 libcap-dev libcups2-dev libcurl4-gnutls-dev libdrm-dev libelf-dev libffi-dev libgbm-dev \
 libglib2.0-dev libglu1-mesa-dev libgnome-keyring-dev libgtk-3-dev libkrb5-dev libnspr4-dev \
 libnss3-dev libpam0g-dev libpci-dev libpulse-dev libsctp-dev libspeechd-dev libsqlite3-dev \
 libssl-dev libudev-dev libxslt1-dev libxss-dev libxt-dev libxtst-dev \
 uuid-dev libbluetooth-dev libxkbcommon-dev

 if [ "${TARGET_OS}" = "android" ]; then
  apt-get -y install openjdk-8-jre openjdk-8-jdk
 fi
fi
fi

if [ ! -d "depot_tools" ]; then
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi

export PATH=$PWD/depot_tools:$PATH

if [ ! -d "src" ]; then
if [ "${TARGET_OS}" = "android" ]; then
fetch --nohooks webrtc_android
else if [ "${TARGET_OS}" = "ios" ]; then
fetch --nohooks webrtc_ios
else
fetch --nohooks webrtc
fi
fi
#gclient sync --no-history
# ^ downloads too many data, setup only needed for build manually
python src/build/util/lastchange.py -o src/build/util/LASTCHANGE
if [ "$PLATFORM" = "linux" ]; then
/usr/bin/python src/build/linux/sysroot_scripts/install-sysroot.py --arch=amd64
download_from_google_storage --no_resume --platform=linux* --no_auth --bucket chromium-gn -s src/buildtools/linux64/gn.sha1
if [ "${TARGET_OS}" = "android" ]; then
/usr/bin/python src/tools/clang/scripts/update.py
fi
fi
if [ "$PLATFORM" = "macos" ]; then
python src/build/mac_toolchain.py
python src/tools/clang/scripts/update.py
download_from_google_storage --no_resume --platform=darwin --no_auth --bucket chromium-gn -s src/buildtools/mac/gn.sha1
fi
fi

timestamp=$(date '+%Y-%m-%d')
mkdir -p zips
cd src

if [ "${TARGET_OS}" = "android" ]; then
gn gen out/${TARGET_OS} --args='target_os="android" target_cpu="arm" is_debug=false treat_warnings_as_errors=false rtc_include_tests=false proprietary_codecs=true'
ninja -C out/${TARGET_OS}
zip -j ../zips/webrtc_${TARGET_OS}_$timestamp out/${TARGET_OS}/obj/*.a out/${TARGET_OS}/obj/*.ninja
else if [ "${TARGET_OS}" = "ios" ]; then
gn gen out/${TARGET_OS} --args='target_os="ios" target_cpu="arm64" is_debug=false treat_warnings_as_errors=false rtc_include_tests=false proprietary_codecs=true ios_enable_code_signing=false'
ninja -C out/${TARGET_OS}
zip -j ../zips/webrtc_${TARGET_OS}_$timestamp out/${TARGET_OS}/obj/*.a out/${TARGET_OS}/obj/*.ninja
else

if [ "$PLATFORM" = "linux" ]; then
git apply ../../patches/*.patch
#gn gen out/Debug --args="is_debug=true is_clang=false treat_warnings_as_errors=false rtc_include_tests=false use_custom_libcxx=false proprietary_codecs=true"
#ninja -C out/Debug
#zip -j ../zips/webrtc_${PLATFORM}_debug_$timestamp out/Debug/obj/*.a out/Debug/obj/*.ninja
fi
gn gen out/Release --args="is_debug=false is_clang=false treat_warnings_as_errors=false rtc_include_tests=false use_custom_libcxx=false proprietary_codecs=true"
ninja -C out/Release
zip -j ../zips/webrtc_${PLATFORM}_release_$timestamp out/Release/obj/*.a out/Release/obj/*.ninja

if [ "$PLATFORM" = "linux" ]; then
mkdir -p ../include
../../scripts/copy_headers.sh . ../include
zip -r ../zips/webrtc_include_$timestamp ../include
fi

fi
fi
