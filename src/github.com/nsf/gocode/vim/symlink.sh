#!/bin/sh
cd "${0%/*}"
ROOTDIR=`pwd`
mkdir -p "$HOME/.vim/autoload"
mkdir -p "$HOME/.vim/ftplugin/go"
ln -s "$ROOTDIR/autoload/gocomplete.vim" "$HOME/.vim/autoload/"
ln -s "$ROOTDIR/ftplugin/go/gocomplete.vim" "$HOME/.vim/ftplugin/go/"
