#!/bin/bash
rm -rf _f
git clone "https://github.com" -b stable --depth 1 _f
export PATH="$PATH:$PWD/_f/bin"
flutter config --enable-web
flutter pub get
