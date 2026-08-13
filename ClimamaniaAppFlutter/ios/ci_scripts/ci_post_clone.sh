#!/bin/sh

# Xcode Cloud ejecuta este script tras clonar el repo, antes de resolver
# dependencias. Las máquinas de Xcode Cloud no traen Flutter, así que hay que
# instalarlo y generar la configuración de iOS (Generated.xcconfig) que el
# proyecto Runner necesita y que no está en el repo.

set -e

FLUTTER_VERSION="3.41.9"
FLUTTER_HOME="$HOME/flutter"

echo "▶︎ Instalando Flutter $FLUTTER_VERSION"
# Si el tag no existiera (por ejemplo tras retirar una versión), se cae a stable
# para no romper el build.
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_HOME" \
  || git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_HOME"

export PATH="$FLUTTER_HOME/bin:$PATH"

flutter --version
flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH/ClimamaniaAppFlutter"

echo "▶︎ flutter pub get"
flutter pub get

# --config-only genera ios/Flutter/Generated.xcconfig sin compilar: el archivado
# lo hace después Xcode Cloud con su propio Xcode de release.
echo "▶︎ Generando configuración de iOS"
flutter build ios --release --no-codesign --config-only

echo "▶︎ pod install"
cd ios
pod install

echo "✅ Entorno preparado"
