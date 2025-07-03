#!/bin/bash
set -e

# === 🏷️  Variables ===
CA_DIR="./epicnova-ca"
CA_NAME="Example Root CA"
CA_PASS="EXAMPPLE_PASSWORD"  # Replace for production use
COUNTRY="DE"
STATE="Imaginary State"
LOCATION="Imaginary City"
ORG="Example"
EMAIL="support@example.com"
CN="Example Root CA"

# === 📁 Create CA directory structure ===
echo "📁 Creating CA directory structure at $CA_DIR"
mkdir -p "$CA_DIR"/{certs,crl,newcerts,private,devices}
touch "$CA_DIR/index.txt"
echo 1000 > "$CA_DIR/serial"
echo 1000 > "$CA_DIR/crlnumber"

# === 🔐 Generate private CA key ===
echo "🔐 Generating CA private key"
openssl genrsa -aes256 -passout pass:"$CA_PASS" -out "$CA_DIR/private/ca.key.pem" 4096
chmod 600 "$CA_DIR/private/ca.key.pem"

# === 📜 Generate self-signed CA certificate ===
echo "📜 Creating self-signed CA certificate"
openssl req -config <(cat <<EOF
[ req ]
default_bits        = 4096
prompt              = no
default_md          = sha256
distinguished_name  = dn
x509_extensions     = v3_ca

[ dn ]
C = $COUNTRY
ST = $STATE
L = $LOCATION
O = $ORG
CN = $CN
emailAddress = $EMAIL

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
extendedKeyUsage = serverAuth, clientAuth
EOF
) \
-new -x509 -days 7300 \
-key "$CA_DIR/private/ca.key.pem" \
-out "$CA_DIR/certs/ca.cert.pem" \
-passin pass:"$CA_PASS"

chmod 644 "$CA_DIR/certs/ca.cert.pem"

# === ⚙️  Write OpenSSL configuration ===
echo "⚙️  Writing OpenSSL configuration file"
cat > "$CA_DIR/openssl.cnf" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $CA_DIR
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/example.crl.pem
RANDFILE          = \$dir/private/.rand

private_key       = \$dir/private/ca.key.pem
certificate       = \$dir/certs/ca.cert.pem

default_md        = sha256
unique_subject    = no

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 3650
default_crl_days  = 365
preserve          = no
policy            = policy_strict

[ policy_strict ]
countryName             = optional
stateOrProvinceName     = optional
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 4096
prompt              = no
default_md          = sha256
distinguished_name  = dn

[ dn ]
O = $ORG
CN = $CN

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, keyCertSign, cRLSign
extendedKeyUsage = serverAuth, clientAuth

[ usr_cert ]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "Epic Nova User Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection

[ crl_ext ]
authorityKeyIdentifier = keyid:always
EOF

# === 📄 Generate initial empty CRL ===
echo "📄 Generating initial empty CRL..."
openssl ca \
  -gencrl \
  -config "$CA_DIR/openssl.cnf" \
  -passin pass:"$CA_PASS" \
  -out "$CA_DIR/crl/example.crl.pem"

chmod 644 "$CA_DIR/crl/example.crl.pem"
echo "✅ Initial CRL generated at $CA_DIR/crl/example.crl.pem"

# === ✅ Finished ===
echo "✅ Certificate Authority successfully created at: $CA_DIR"
