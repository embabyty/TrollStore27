#!/usr/bin/env bash

set -e

# Build the iOS 26.6.1 / iOS 27.0 RC CoreTrust-enabled TrollInstallerX IPA.
# The app is signed with the CoreTrust bypass (CVE-2023-41991) and the private
# entitlements required to spawn the bundled root helper as root (persona),
# allowing TrollStore installation without any kernel exploit.

cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"

# Resolve to absolute paths: these are also used after pushd into DerivedData,
# where relative paths would no longer point at the repo
FAST_PATH_SIGN="${FAST_PATH_SIGN:-$SCRIPT_DIR/../Exploits/fastPathSign/fastPathSign}"
ROOT_HELPER="${ROOT_HELPER:-$SCRIPT_DIR/../RootHelper/.theos/obj/trollstorehelper}"
TROLLSTORE_TAR="${TROLLSTORE_TAR:-$SCRIPT_DIR/../_build/TrollStore.tar}"

# Refresh the bundled TrollStore.tar from the latest build so the installer
# ships the current TrollStore binaries
if [[ -f "$TROLLSTORE_TAR" ]]; then
    cp "$TROLLSTORE_TAR" Resources/TrollStore.tar
fi

xcodebuild -configuration Release -derivedDataPath DerivedData/TrollInstallerX -destination 'generic/platform=iOS' -scheme TrollInstallerX CODE_SIGNING_ALLOWED="NO" CODE_SIGNING_REQUIRED="NO" CODE_SIGN_IDENTITY="" ARCHS="arm64" ONLY_ACTIVE_ARCH="NO"
cp Resources/ents.plist DerivedData/TrollInstallerX/Build/Products/Release-iphoneos/
pushd DerivedData/TrollInstallerX/Build/Products/Release-iphoneos
rm -rf Payload TrollInstallerX27.ipa
mkdir Payload
cp -r TrollInstallerX.app Payload

# Bundle the CoreTrust-enabled root helper (signed with the CoreTrust bypass
# during the RootHelper theos build)
if [[ ! -f "$ROOT_HELPER" ]]; then
    echo "ERROR: trollstorehelper not found at $ROOT_HELPER (build RootHelper first)" >&2
    exit 1
fi
cp "$ROOT_HELPER" Payload/TrollInstallerX.app/trollstorehelper

# Apply the CoreTrust bypass (CVE-2023-41991) to the main executable, carrying
# the private entitlements needed for the CoreTrust install method
"$FAST_PATH_SIGN" --entitlements ents.plist Payload/TrollInstallerX.app/TrollInstallerX

# Adhoc sign any embedded dynamic libraries so they can be loaded
find Payload/TrollInstallerX.app -name '*.dylib' -exec ldid -S {} \;

zip -qry TrollInstallerX27.ipa Payload
popd
cp DerivedData/TrollInstallerX/Build/Products/Release-iphoneos/TrollInstallerX27.ipa .
rm -rf Payload
echo "Built TrollInstallerX27.ipa"