#!/usr/bin/env sh

# Recreate the certificate from the secure environment variable
CERTIFICATE_P12=dist_certificate.p12

# Recreate the certificate from the secure environment variable
echo $BUILD_CERTIFICATE_KEY | base64 --decode > $CERTIFICATE_P12

# Lock the keychain
security lock-keychain $BUILD_KEYCHAIN

# Unlock the keychain
security unlock-keychain -p $BUILD_KEYCHAIN_PASSWORD $BUILD_KEYCHAIN

# Set keychain settings
security set-keychain-settings $BUILD_KEYCHAIN

# Import the certificate to the keychain
security import $CERTIFICATE_P12 -k $BUILD_KEYCHAIN -P $BUILD_CERTIFICATE_PASSWORD -T /usr/bin/codesign;

# Set key partition list
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k $BUILD_KEYCHAIN_PASSWORD $BUILD_KEYCHAIN

# Lock the keychain
security lock-keychain $BUILD_KEYCHAIN

# remove certs
rm -fr *.p12
