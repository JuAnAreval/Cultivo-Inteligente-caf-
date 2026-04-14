# App Campo IA Local

Aplicacion Flutter orientada a trabajo de campo para gestionar fincas, lotes y registros agricolas con soporte offline y flujos asistidos por IA local.

La app esta pensada para operar en contextos rurales donde la conectividad puede ser limitada o inexistente. Por eso combina:

- autenticacion con persistencia de sesion
- almacenamiento local con SQLite
- sincronizacion offline-first con backend
- mapa con OpenStreetMap
- IA local para estructurar registros a partir de lenguaje natural

## Estado actual

Hoy el proyecto ya incluye:

- login con sesion persistente
- refresh token automatico
- modulo de fincas
- modulo de lotes
- historial de actividades por lote
- historial de insumos por lote
- creacion asistida por IA para actividades
- creacion asistida por IA para insumos
- mapa de fincas con seleccion, enfoque y acceso a lotes
- soporte offline con sincronizacion cuando vuelve la conexion

## Stack tecnico

- Flutter
- Provider
- SQLite con `sqflite`
- `shared_preferences`
- `http`
- `dio`
- `flutter_map`
- `latlong2`
- `geolocator`
- `speech_to_text`
- `intl`

## Enfoque de arquitectura

El proyecto esta organizado por dominio para que ubicar la logica sea mas facil:

```text
lib/
  core/
    config/
    models/
    providers/
    services/
      actividades/
      ai/
      auth/
      cosechas/
      fincas/
      insumos/
      lotes/
      shared/
  layout/
  screens/
    actividades/
    ai/
    auth/
    fincas/
    home/
    insumos/
    lotes/
```

### Convencion actual

- `screens/`: vistas y flujo de UI
- `services/`: acceso a datos, IA, auth, sync y soporte tecnico
- `shared/`: piezas transversales como `database_helper`, `http_client` y `sync_service`
- carpetas por dominio: `fincas`, `lotes`, `actividades`, `insumos`, `cosechas`

## Flujo principal de la app

1. La app inicia en login si no hay sesion valida.
2. Si existe sesion, intenta restaurarla y refrescar token si hace falta.
3. Al entrar al home, la primera pestaña muestra `Fincas`.
4. Desde una finca se entra a sus lotes.
5. Desde un lote se puede entrar a:
   - actividades
   - insumos
6. Actividades e insumos tienen historial y registro con IA.

## IA local

La app usa IA local para transformar texto libre en borradores editables.

### Casos actuales

- `Actividades`: convierte una descripcion hablada o escrita en campos estructurados como fecha, actividad, aplicaciones, dosis y observaciones.
- `Insumos`: convierte una descripcion hablada o escrita en campos como insumo, ingredientes activos, fecha, tipo, origen y factura.

### Flujo IA

1. El usuario escribe o dicta.
2. La IA local analiza el mensaje.
3. Se genera un borrador editable.
4. El usuario revisa y corrige.
5. El registro se guarda localmente y luego se sincroniza.

### Modelo local

Actualmente se usa un modelo local tipo Qwen descargado en el dispositivo. La inicializacion y descarga se controlan desde las pantallas de chat IA y el servicio LLM.

## Offline-first

La app esta construida con una estrategia offline-first:

- los registros se guardan localmente
- cada tabla local maneja estado de sincronizacion
- cuando hay internet se hace push de pendientes
- luego se hace pull remoto para reflejar cambios del backend
- si algo fue eliminado o modificado en remoto, la base local se actualiza

Esto aplica al menos para:

- fincas
- lotes
- actividades
- insumos
- cosechas

## Mapa

El mapa usa OpenStreetMap con `flutter_map`.

Actualmente permite:

- ver fincas georreferenciadas
- usar ubicacion actual del dispositivo
- abrir listado de fincas bajo demanda
- centrar el mapa al tocar una finca del listado
- tocar un pin para ver detalles
- entrar a lotes desde el detalle de una finca

## Rutas principales

Las rutas declaradas en `main.dart` son:

- `/login`
- `/home`
- `/dashboard`
- `/add-farm`
- `/farms`
- `/lots`
- `/add-lot`

Nota: aunque algunas rutas o nombres de archivo siguen en ingles por compatibilidad, la estructura de carpetas ya se esta llevando a espanol por dominio.

## Servicios importantes

### Auth

- `auth/auth_service.dart`
- `auth/session_service.dart`

Responsables de:

- login
- persistencia de token y refresh token
- restauracion de sesion
- refresco automatico

### Shared

- `shared/database_helper.dart`
- `shared/http_client.dart`
- `shared/sync_service.dart`

Responsables de:

- base local SQLite
- cliente HTTP centralizado
- sincronizacion global

### Dominio

- `fincas/finca_service.dart`
- `lotes/lote_service.dart`
- `actividades/actividad_campo_service.dart`
- `insumos/insumo_servies.dart`
- `cosechas/cosecha_service.dart`

## Ejecutar el proyecto

### Requisitos

- Flutter SDK instalado
- Android Studio o VS Code
- dispositivo Android o emulador

### Comandos

```bash
flutter pub get
flutter run
```

Para validar que todo este bien:

```bash
flutter analyze
```

## Configuracion relevante

La configuracion del backend se centraliza en:

- `lib/core/config/api_config.dart`

Y el tema visual principalmente en:

- `lib/core/config/app_colors.dart`

## Permisos Android

La app actualmente usa permisos para:

- internet
- grabacion de audio
- ubicacion fina y aproximada

Estos permisos estan declarados en:

- `android/app/src/main/AndroidManifest.xml`

## Modulos pendientes o en evolucion

Estas piezas ya estan contempladas pero aun pueden crecer o cambiar:

- exportacion a Excel
- perfil y configuracion
- modulo completo de cosechas en UI
- carga de archivos para factura
- mejora de prompts y validaciones IA
- refinamiento visual adicional

## Nota sobre factura en insumos

Por ahora `factura` se maneja como texto.

La idea futura es migrarlo a archivo o imagen:

- guardar foto localmente
- sincronizar cuando el backend soporte archivos
- reemplazar el campo de texto por selector de imagen

## Objetivo del proyecto

Construir una app de campo, simple de usar, visualmente limpia y funcional aun sin internet, donde la IA ayude a convertir conversaciones o notas en registros estructurados sin quitarle control al usuario.
