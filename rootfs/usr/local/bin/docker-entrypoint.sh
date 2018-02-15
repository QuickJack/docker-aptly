#!/bin/bash
set -eo pipefail
shopt -s nullglob

GPGPATH=~/.gnupg
KEYSERVER=pgp.mit.edu
APTLYPATH=/srv/aptly
PUBPATH=$APTLYPATH/public

function checkdir() {
  if [ ! -d "$GPGPATH" ]; then
    echo "====== CREATE GNUGPG DIR ======="
    mkdir -p $GPGPATH
  fi
  if [ ! -d "$PUBPATH" ]; then
    echo "====== CREATE PUBLIC DIR ======="
    mkdir -p $PUBPATH
  fi
}

function checkgpg() {
  if [ ! -f "$GPGPATH/gpg.conf" ]; then
    echo "====== GENERATE GPG CONF FILE ======="
    tee $GPGPATH/gpg.conf << EOF
    personal-digest-preferences SHA256
    cert-digest-algo SHA256
    default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed
    personal-cipher-preferences TWOFISH CAMELLIA256 AES 3DES
EOF
  fi
  if [ ! -f "/etc/mkgpg.conf" ]; then
    echo "======= CREATE BASH CONF GPG ======"
    tee /etc/mkgpg.conf << EOF
    %echo Generating a default key
    Key-Type: default
    Subkey-Type: default
    Name-Real: Ernesto Pérez
    Name-Comment: Xb(9DUfr6m/eZe?YVFe{
    Name-Email: eperez@isotrol.com
    Expire-Date: 0
    %pubring aptly.pub
    %secring aptly.sec
    %commit
    %echo done
EOF
  fi
}

function importkey() {
  gpg --keyserver $SERVERGPG --recv-keys $1 \
  && gpg --export --armor $1 | apt-key add -
}

function gengpg() {
  if [ ! -f "$PUBPATH/gpg.pub.key" ]; then
    echo "======= GENERATE GPG KEY ========"
    gpg --batch --gen-key /etc/mkgpg.conf
    echo "======= FINISH GENERATE KEY ======="
    gpg --list-secret-keys
    echo "======= EXPORT GPG PUB KEY ========"
    IDKEY=$(gpg --list-keys --with-colons | awk -F: '/^pub:/ { print $5 }')
    gpg --armor --output $PUBPATH/gpg.pub.key --export $IDKEY
    gpg --keyserver $KEYSERVER --send-keys $IDKEY
    echo "======== FINISH EXPORT KEY ========"
  else
    echo "======= IMPORT PUB KEY DETECTED ======="
    gpg --import $PUBPATH/gpg.pub.key
    gpg --list-secret-keys
    echo "======= FINISH IMPORT PUB KEY ========"
  fi
}

function checkweb() {
  if [ $WEBUI = "yes" ]; then
    URL=https://github.com/sdumetz/aptly-web-ui/releases
    VERSION=$(curl -L -s -H 'Accept: application/json' $URL/latest|sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
    if [ ! -d "$DIRPATH/ui" ]; then
      echo "======= DEPLOY WEB INTERFACE ======="
      curl -SL $URL/download/$VERSION/aptly-web-ui.tar.gz |tar xzv -C $DIRPATH
      echo "=========== FINISH DEPLOY =========="
    else
      echo "========== !!CANCEL DEPLOY ============"
      echo "======= ALREADY DEPLOYED WEBUI ======="
    fi
  fi
}

checkdir
checkgpg
gengpg
checkweb

. "/etc/importkey.conf"

exec "$@"