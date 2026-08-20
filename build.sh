#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swiftc -O Sources/main.swift -o MangaHop

rm -rf MangaHop.app
mkdir -p MangaHop.app/Contents/MacOS MangaHop.app/Contents/Resources
cp MangaHop MangaHop.app/Contents/MacOS/
cp Info.plist MangaHop.app/Contents/
cp assets/AppIcon.icns MangaHop.app/Contents/Resources/
# ad-hoc sign so macOS remembers the automation permission
codesign --force --sign - MangaHop.app

echo "built MangaHop.app"
