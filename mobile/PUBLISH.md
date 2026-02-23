# Publicación: Ad Revenue Dashboard - For ironSource

## Nombre de la app
- **Android**: `android:label="Ad Revenue Dashboard - For ironSource"` (AndroidManifest.xml)
- **iOS**: `CFBundleDisplayName` y `CFBundleName` (Info.plist)

## Iconos (opcional)
1. Crea `assets/icon.png` (1024×1024)
2. Añade en `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
  adaptive_icon_background: "#1a237e"
  adaptive_icon_foreground: "assets/icon.png"
```

3. Ejecuta: `flutter pub run flutter_launcher_icons`

## Android (release)
1. ~~Crea el keystore~~ ✅ Hecho (`upload-keystore.jks` en la raíz de mobile)
2. ~~Configura `key.properties`~~ ✅ Hecho
3. `android/app/build.gradle.kts` ya está configurado para usar `key.properties`
4. `applicationId` está configurado como `com.adrevenue.ironsource`
5. Build: `flutter build appbundle`

## iOS (release)
1. Configura firma en Xcode
2. Build: `flutter build ipa`
