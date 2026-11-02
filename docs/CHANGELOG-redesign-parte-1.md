# Rediseño · Parte I (rama `redesign/parte-1`)

Cambios hechos sobre `AI_TRANSIT_REDESIGN_AND_DATA_SPEC.md`, parte I y lo de Android de la parte III. Fecha: 2 nov 2026.

## Hecho

| Directiva | Qué ha cambiado |
|---|---|
| **C · Mapa** | La pestaña "Viajes" pasa a ser **Mapa** (`/map`, `TransitMapScreen`). Se centra en tu GPS con zoom 15,5 y pinta las paradas de todos los operadores en 600 m. Al mover el mapa recarga las paradas de la zona visible (`onCameraIdle` + 250 ms de debounce, consulta por caja en SQLite). Al tocar una parada se abre una hoja deslizante con sus próximas salidas y dos botones: "Salir de aquí" e "Ir hasta aquí". Los viajes guardados siguen en el menú ⋮ de Inicio, porque alimentan el widget. |
| **D · Ubicación** | `resolvedUserLocationProvider`: solo muestra el diálogo del sistema y, si se deniega, usa Plaza Moyúa sin mensajes de error. En el mapa sale una píldora discreta: "Sin ubicación: mostrando el centro de Bilbao". En Android: **corregido el fallo** que trataba la "ubicación aproximada" como denegada, y si no hay una posición reciente se pide una nueva (con 8 s de tiempo máximo). |
| **D · Avisos** | Arriba "Cerca de ti (< 3 km)", medido con Haversine contra la parada afectada más cercana. Debajo "Toda la red", con chips de Metro, Bizkaibus, Euskotren y Cercanías. Al tocar un aviso se abre la parada afectada. `ServiceAlert` tiene ahora `affectedStopIds` (equivale al `informed_entity.stop_id` de GTFS-RT). |
| **A · Fluidez** | Las listas de salidas usan `SliverFixedExtentList` con una altura fija que sigue el tamaño de texto del sistema. La tarjeta principal va dentro de un `RepaintBoundary`. Avisos pasa a `CustomScrollView`. |
| **B · Limpieza** | El simulador de Live Activity solo aparece en compilaciones debug. El banner del viaje activo ya no abre el simulador. El filtro de destino es ahora un chip "Hacia X ✕". Hay una pantalla nueva de parada (`StopDeparturesScreen`) con `BackButton`. Nueva fila de salida (`DepartureRow`): línea, destino grande y minutos en verde (en hora), ámbar (con retraso) o neutro (según horario). |
| **E · Notificación** | Formato del spec: título `Metro Bilbao: L1 Plentzia`, texto `Próxima salida en 3 min (14:32) • Siguiente: 8 min`, subtexto `Estación • Andén`, y botones **Actualizar** y **Finalizar**. Los minutos se recalculan cada 30 s en el propio servicio. Ya no se inventan "4 paradas / 25 %" al seguir una salida. |
| **III · Tiendas** | Aviso de independencia en el onboarding y en Ajustes. Pantalla `/settings/licenses` con las fuentes, sus licencias y las licencias de software. El subtipo del foreground service tiene el texto del spec. `MissingPluginException` ya no rompe la app donde no hay canal nativo. |

`flutter analyze`: 0 avisos. `flutter test`: 32/32. Hay un test actualizado: la pestaña se llama ahora "Mapa", como pide el spec.

## Versión web (vista previa)

La app ya compila para navegador: `flutter build web --release` con los mismos `--dart-define` de `env/dev.json`.

- **Base de datos.** En web, `transit.sqlite` se carga en memoria con SQLite en WebAssembly (`lib/data/local/connection/open_web.dart`). `web/sqlite3.wasm` tiene que ser de la misma versión que el paquete `sqlite3` (ahora la 2.9.4). Los viajes guardados se pierden al cerrar la pestaña.
- **Ubicación.** Se pide con la geolocalización del navegador; si se deniega, se usa Moyúa.
- **Lo que no existe en web.** La notificación de bloqueo y el widget de inicio no existen en el navegador. Google Sign-In solo se inicializa al usarlo: en web necesita un client ID que todavía no está creado.
- **Fallos corregidos de paso (también afectan a Android).** Una salida del minuto en curso aparecía como "1439 min". La hoja de parada del mapa quedaba tapada por la barra inferior.

## Honestidad de datos (importante)

- **Horarios sintéticos.** `tools/build_gtfs/build_transit_db.py` no descarga GTFS: las paradas están puestas a mano y los horarios los genera el propio script ("Synthesizing realistic schedules"). Antes de publicar hay que cargar los GTFS reales.
- **"En directo" falso.** El repositorio marcaba casi todas las salidas como tiempo real sin que hubiera ningún feed GTFS-RT conectado. Ahora todas se muestran como **"Según horario"** hasta que se fusione el tiempo real (`transit_repository_impl.dart`, bloque comentado).
- **Avisos de ejemplo.** Las 5 incidencias están escritas en el código. La pantalla lo dice en un aviso visible hasta que se conecte el feed oficial.

## Pendiente

1. **Supabase vacío.** El proyecto `ocxcrxgagennmukuxnle` no tiene tablas. Hay que aplicar `supabase/migrations/` (`supabase db push`) y activar Google y Apple en Auth. Sin `delete_user_account`, el botón de borrar cuenta falla.
2. **Otro proyecto Supabase.** `TransitConstants.defaultStorageBucketUrl` apunta a `zbwrjtncyblaxaarbmsr`, no al de `env/dev.json`.
3. **iOS sin proyecto.** `ios/` no tiene `Runner.xcodeproj`, `Info.plist` ni `AppDelegate`. Hay que generarlo (`flutter create --platforms ios .`), añadir los textos de permisos, `NSSupportsLiveActivities` y el canal nativo `com.bizkaia.transit/live_trip`. Hace falta un Mac con Xcode.
4. **Política de privacidad.** Falta una URL pública, y también la URL web para pedir el borrado de cuenta que exige Google Play.
5. **Parte II** (ingesta GTFS/GTFS-RT, Edge Functions, `feed_health`) sin empezar.
6. **Plugins con KGP.** `home_widget` y `sign_in_with_apple` aplican el Kotlin Gradle Plugin; Flutter avisa de que en versiones futuras dejará de compilar.
