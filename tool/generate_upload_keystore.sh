#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
keystore="$project_dir/android/app/upload-keystore.jks"
properties="$project_dir/android/key.properties"
credentials="$project_dir/android/upload-key-credentials.txt"

if [[ -e "$keystore" || -e "$properties" || -e "$credentials" ]]; then
  echo "Upload key already exists; refusing to overwrite it." >&2
  exit 1
fi

umask 077
password="$(openssl rand -hex 24)"
keytool_bin="${JAVA_HOME:-}/bin/keytool"
if [[ ! -x "$keytool_bin" ]]; then
  keytool_bin="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
fi
if [[ ! -x "$keytool_bin" ]]; then
  echo "keytool not found; install a JDK or Android Studio." >&2
  exit 1
fi
"$keytool_bin" -genkeypair -v \
  -keystore "$keystore" \
  -storetype JKS \
  -storepass "$password" \
  -keypass "$password" \
  -alias motorix-upload \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -dname "CN=Motorix Upload, OU=Mobile, O=Motorix, L=Jakarta, ST=DKI Jakarta, C=ID"

printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=motorix-upload\nstoreFile=upload-keystore.jks\n' \
  "$password" "$password" > "$properties"
printf 'Store password: %s\nKey password: %s\nAlias: motorix-upload\n' \
  "$password" "$password" > "$credentials"

echo "Created Android upload key and local recovery credentials."
