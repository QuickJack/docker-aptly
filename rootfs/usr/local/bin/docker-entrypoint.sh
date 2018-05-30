#!/bin/bash
set -eo pipefail
shopt -s nullglob

GPGPATH="$HOME/.gnupg"
KEYSERVER="pgp.mit.edu"
APTLYPATH="/srv/aptly"
PUBPATH="${APTLYPATH}/public"
GPGTYPE="${GPGTYPE:-default}"
GPGNAME="${GPGNAME:-Aptly Repository}"
GPGMAIL="${GPGMAIL:-aptly@mail.com}"
GPGCIPHER="${GPGCIPHER:-SHA256}"
GPGLENGHT="${GPGLENGHT:-2048}"
GPGCOMMENT="${GPGCOMMENT:-Key Repository Packages deb}"
GPGEXPIRE="${GPGEXPIRE:-0}"
GPGSERVER="${GPGSERVER-keys.gnupg.net}"

function checkdir() {
  if [ ! -d "$GPGPATH" ]; then
    echo "====== CREATE GNUGPG DIR ======="
    mkdir -p $GPGPATH
    chmod -R 600 $GPGPATH
  fi
  if [ ! -d "$PUBPATH" ]; then
    echo "====== CREATE PUBLIC DIR ======="
    mkdir -p $PUBPATH
  fi
}

function checkconf() {
  if [ -f "$APTLYPATH/aptly.conf" ]; then
    echo "====== DETECTED APTLY CONFIG FILE ======="
     cp -av $APTLYPATH/aptly.conf /etc/aptly.conf
    echo "====== APTLY CONFIG FILE APPLIED ======"
  fi
}

function checkgpg() {
  if [ ! -f "${GPGPATH}/gpg.conf" ]; then
    echo "====== GENERATE GPG CONF FILE ======="
    tee ${GPGPATH}/gpg.conf << EOF
    personal-digest-preferences ${GPGCIPHER}
    cert-digest-algo ${GPGCIPHER}
    default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
    personal-cipher-preferences TWOFISH CAMELLIA256 AES 3DES
EOF
  fi
  if [ ! -f "/etc/mkgpg.conf" ]; then
    echo "======= CREATE BASH CONF GPG ======"
    tee /etc/mkgpg.conf << EOF
    %echo >>>>> Generating a default key <<<<<<<
    Key-Type: ${GPGTYPE}
    Key-Length: ${GPGLENGHT}
    Subkey-Type: ${GPGTYPE}
    Subkey-Length: ${GPGLENGHT}
    Name-Real: ${GPGNAME}
    Name-Comment: ${GPGCOMMENT}
    Name-Email: ${GPGMAIL}
    Expire-Date: ${GPGEXPIRE}
    %no-ask-passphrase
    %no-protection
    %commit
    %echo >>>>>> Done GPG key <<<<<<<<<
EOF
  fi
}

function importkey() {
  echo "====== IMPORT KEYS PUBLIC ======"
  gpg --keyserver ${SERVERGPG} --recv-keys $1 \
  && gpg --export --armor $1 | apt-key add -
  gpg --no-default-keyring --keyring trustedkeys.gpg --keyserver ${GPGSERVER} --recv-keys $1
  echo "====== FINISH IMPORT PUBLIC KEYS ======"
}

function gengpg() {
  if [ ! -f "${APTLYPATH}/gpg.priv.key" ]; then
    echo "======= GENERATE GPG PRIVATE KEY ========"
    gpg --batch --gen-key /etc/mkgpg.conf
    echo "======= FINISH GENERATE PRIVATE KEY ======="
    gpg --list-secret-keys
  else
    echo "======= IMPORT PRIVATE KEY DETECTED ======="
    gpg --import ${APTLYPATH}/gpg.priv.key
    gpg --list-secret-keys
    echo "======= FINISH IMPORT PRIVATE KEY ========"
  fi
  if [ ! -f "${PUBPATH}/gpg.pub.key" ]; then
    echo "======= EXPORT GPG PUB KEY ========"
    IDKEY=$(gpg --list-keys --with-colons | awk -F":" '/^pub:/ { print $5 }')
    gpg --armor --output ${PUBPATH}/gpg.pub.key --export $IDKEY
    gpg --keyserver ${KEYSERVER} --send-keys $IDKEY
    echo "======== FINISH EXPORT KEY ========"
  else
    echo "======= IMPORT PUB KEY DETECTED ======="
  fi
    gpg --import ${PUBPATH}/gpg.pub.key
    gpg --list-secret-keys
    echo "======= FINISH IMPORT PUB KEY ========"
}

function checkweb() {
  if [ "${WEBUI}" = "yes" ]; then
    URL=https://github.com/sdumetz/aptly-web-ui/releases
    VERSION=$(curl -L -s -H 'Accept: application/json' ${URL}/latest|sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
    if [ ! -d "${PUBPATH}/ui" ]; then
      echo "======= DEPLOY WEB INTERFACE ======="
      curl -SL ${URL}/download/${VERSION}/aptly-web-ui.tar.gz |tar xzv -C ${PUBPATH}
      echo "=========== FINISH DEPLOY =========="
    else
      echo "========== !!CANCEL DEPLOY ============"
      echo "======= ALREADY DEPLOYED WEBUI ======="
    fi
  fi
}

checkdir
checkconf
checkgpg
gengpg
checkweb

. "/etc/importkeys.conf"

exec "$@"
