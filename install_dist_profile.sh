#!/usr/bin/env sh

DIST_PROFILE_FILE=${BUILD_PROVISION_UUID}.mobileprovision

# Recreate the certificate from the secure environment variable
echo "$BUILD_PROVISION_PROFILE" | base64 --decode > "$DIST_PROFILE_FILE"

# Create a directory for provisioning profiles
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"

# Copy the provisioning profile where Xcode can find it
cp "${DIST_PROFILE_FILE}" "$HOME/Library/MobileDevice/Provisioning Profiles/${BUILD_PROVISION_UUID}.mobileprovision"

# Lock the keychain
security lock-keychain "$BUILD_KEYCHAIN"

# clean
rm -fr -- *.mobileprovision
