# Cómo hacer que el icono tenga forma redondeada (squircle) en macOS

En macOS, **el sistema no aplica la forma redondeada automáticamente** como en iOS. Hay que usar una imagen que ya tenga el squircle aplicado.

## Opción 1: Squircle (web, gratis)

1. Entra en **https://squircle.kruschel.dev/**
2. Arrastra `assets/icon/logo.png`
3. Descarga el resultado (PNG con esquinas redondeadas)
4. Guarda el archivo como `assets/icon/logo_macos.png`
5. En `pubspec.yaml`, dentro de `macos:`, cambia `image_path` a `"assets/icon/logo_macos.png"`
6. Ejecuta: `dart run flutter_launcher_icons`
7. Limpia y ejecuta: `flutter clean && flutter run -d macos`

## Opción 2: CandyIcons (web, gratis)

1. Entra en **https://www.candyicons.com/free-tools/app-icon-assets-generator**
2. Sube `assets/icon/logo.png`
3. Elige **macOS**
4. Descarga el .zip
5. Reemplaza el contenido de `macos/Runner/Assets.xcassets/AppIcon.appiconset/` con los archivos generados

## Opción 3: App Squircle (Mac App Store)

1. Instala **Squircle** desde la Mac App Store
2. Arrastra tu `logo.png` sobre la app
3. Exporta como AppIcon.appiconset
4. Reemplaza `macos/Runner/Assets.xcassets/AppIcon.appiconset/` con lo exportado
