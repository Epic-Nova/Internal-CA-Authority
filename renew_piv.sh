#!/bin/bash
set -euo pipefail

CA_DIR="./epicnova-ca"

echo -n "🔐 Please enter YubiKey PIN: "
read -s YUBIKEY_PIN
echo

# Set array of PIV slots
slots=("9a" "9c" "9d" "9e")

CA_KEY_PASS_PROMPT="🔐 Enter passphrase for CA key: "
CA_KEY_PASS=""

# Collect user info
read -r -p "👤 First name (GN): " GN
read -r -p "👤 Last name (SN): " SN
read -r -p "📧 Email: " EMAIL
read -r -p "🏢 Department (OU): " OU
read -r -p "🆔 Epic Nova Account-ID (UID): " EPIC_UID

# Get YubiKey serial number
YK_SERIAL=$(ykman info | grep -i 'Serial number' | awk '{print $3}')
if [[ -z "$YK_SERIAL" ]]; then
  echo "❌ Could not read YubiKey serial number. Is it connected?"
  exit 1
fi

echo "🔐 Using YubiKey with serial: $YK_SERIAL"

# Create device directories
DEVICE_DIR="$CA_DIR/devices/$YK_SERIAL"
mkdir -p "$DEVICE_DIR"/{csr,certs,pubkeys,crl}

# Prompt for CA key passphrase once
read -s -p "$CA_KEY_PASS_PROMPT" CA_KEY_PASS
echo ""

# Export public keys from YubiKey slots
for slot in "${slots[@]}"; do
  echo "📤 Exporting Public Key from Slot $slot"
  ykman piv keys export "$slot" "$DEVICE_DIR/pubkeys/$slot.pubkey.pem"
done

# Create subject string
SUBJECT="/CN=$GN $SN/OU=$OU/O=Example/L=Imaginary City/ST=Imaginary State/C=DE/emailAddress=$EMAIL/UID=$EPIC_UID/SN=$SN/GN=$GN/"

# Generate CSRs for all slots
for slot in "${slots[@]}"; do
  echo "📝 Generating CSR for Slot $slot"
  cat "$DEVICE_DIR/pubkeys/$slot.pubkey.pem" | yubico-piv-tool \
    -P "$YUBIKEY_PIN" -s "$slot" \
    -a verify-pin \
    -a request-certificate \
    -S "$SUBJECT" \
    -i - -o "$DEVICE_DIR/csr/$slot.csr.pem"
done

# Sign CSRs with CA
for slot in "${slots[@]}"; do
  echo "🔏 Signing CSR for Slot $slot"
  openssl ca \
    -batch \
    -config "$CA_DIR/openssl.cnf" \
    -extensions usr_cert \
    -days 365 \
    -notext -md sha256 \
    -passin pass:"$CA_KEY_PASS" \
    -in "$DEVICE_DIR/csr/$slot.csr.pem" \
    -out "$DEVICE_DIR/certs/$slot.cert.pem"
done

# Import certificates back to YubiKey slots
for slot in "${slots[@]}"; do
  echo "📥 Importing Certificate to Slot $slot"
  yubico-piv-tool -P "$YUBIKEY_PIN" -s "$slot" \
    -a verify-pin \
    -a import-certificate \
    -i "$DEVICE_DIR/certs/$slot.cert.pem"
done

# Show certificates info
for slot in "${slots[@]}"; do
  echo "=== 📄 Certificate in Slot $slot ==="
  yubico-piv-tool -s "$slot" -a read-certificate | openssl x509 -noout -subject -dates
done

# Generate a CRL for each slot
for slot in "${slots[@]}"; do
  echo "🛑 Generating CRL for Slot $slot"
  CRL_FILE="$DEVICE_DIR/crl/example-$slot.crl.pem"
  openssl ca \
    -gencrl \
    -config "$CA_DIR/openssl.cnf" \
    -passin pass:"$CA_KEY_PASS" \
    -out "$CRL_FILE"
  echo "✅ CRL generated at $CRL_FILE"
done

echo "✅ Device $YK_SERIAL successfully enrolled."
