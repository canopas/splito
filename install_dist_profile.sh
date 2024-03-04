#!/usr/bin/env sh

DIST_PROFILE_FILE=${BUILD_PROVISION_UUID}.mobileprovision

# Recreate the certificate from the secure environment variable
echo $BUILD_PROVISION_PROFILE | base64 --decode > $DIST_PROFILE_FILE

# Lock the keychain
#security lock-keychain $BUILD_KEYCHAIN

echo "XXX --- Profile: $BUILD_KEYCHAIN_PASSWORD"

echo "XXX --- Unlocking keychain..."
# Unlock the keychain
security unlock-keychain -p $BUILD_KEYCHAIN_PASSWORD $BUILD_KEYCHAIN

echo "XXX --- Find password"
security find-generic-password -s $BUILD_KEYCHAIN

echo "XXX --- Create a directory for provisioning profiles"
# Create a directory for provisioning profiles
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"

echo "XXX --- Copy the provisioning profile where Xcode can find it"
# Copy the provisioning profile where Xcode can find it
cp ${DIST_PROFILE_FILE} "$HOME/Library/MobileDevice/Provisioning Profiles/${BUILD_PROVISION_UUID}.mobileprovision"

echo "XXX --- Lock the keychain"
# Lock the keychain
security lock-keychain $BUILD_KEYCHAIN

echo "XXX --- Clean profile"
# clean
rm -fr *.mobileprovision
