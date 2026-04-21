Pantalla nativa de arranque en Android:

- Archivo de fondo: `android/app/src/main/res/drawable/launch_background.xml`
- Archivo para Android 5+ : `android/app/src/main/res/drawable-v21/launch_background.xml`
- Tema oscuro ajustado en: `android/app/src/main/res/values-night/styles.xml`

Ahora mismo muestra:

- Fondo blanco
- Icono de la app centrado usando `@mipmap/ic_launcher`

Si cambias el icono de la app con `flutter_launcher_icons`, esta pantalla usara ese mismo icono.

Si luego quieres un logo distinto solo para la pantalla de arranque:

1. Crea una imagen PNG en `android/app/src/main/res/drawable/`
2. Cambia `android:src=\"@mipmap/ic_launcher\"` por tu recurso, por ejemplo `@drawable/mi_logo_splash`

En iPhone la pantalla nativa se controla desde:

- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

Si quieres, en el siguiente paso te la dejo tambien personalizada para iPhone con tu logo.
