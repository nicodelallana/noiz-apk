# Directiva Maestra de Arquitectura, Rediseño UI/UX y Sistema de Datos — Bizkaia Transit (Noiz)

> **Destinatario del Documento:** Agente IA / Ingeniero Senior de Flutter, Diseñador de Producto Móvil y Arquitecto de Datos de Transporte.  
> **Instrucción de Ejecución:** Lee este documento íntegramente. Tienes autorización total y se espera que **utilices todas las herramientas a tu alcance** (lectura/escritura de código, análisis estático, ejecución de comandos, compilación y pruebas) para transformar radicalmente la aplicación en un producto de nivel internacional (*world-class*), limpio, rápido y sin artificios innecesarios.

---

# PARTE I: Misión de Rediseño, Rendimiento y Experiencia de Usuario

## 1. Rol y Principios de Ejecución

Actúa como **Lead Mobile Product Designer y Principal Flutter Architect** con experiencia en aplicaciones de transporte urbano de primer nivel (*Citymapper*, *Transit*, *Apple Maps Transit*) y sistemas distribuidos.

### Principios Fundamentales
1. **Anti-Slop Radical:** Elimina cualquier rastro de diseño genérico o "hecho por IA" (fondos recargados de neón, tarjetas con sombras excesivas, chips redundantes, botones de simulación o maquetas de pruebas en pantallas de producción).
2. **Claridad Suiza y Jerarquía Visual:** Tipografía limpia (*Space Grotesk* e *Inter*), contraste accesible (WCAG AA/AAA), números de cuenta atrás grandes y legibles a un golpe de vista (a 1 metro de distancia en la calle), identificadores de línea oficiales y consistentes.
3. **Rendimiento a 60/120 FPS:** Ningún salto de frame (*jank*) al hacer scroll. Virtualización estricta de listas, uso de Slivers, y delegación de cálculos pesados fuera del hilo de renderizado.
4. **Offline-First Real:** La aplicación debe arrancar y responder al instante desde la base de datos local SQLite precompilada, sincronizando deltas de tiempo real en segundo plano sin bloquear jamás la UI.

---

## 2. Diagnóstico del Estado Actual y Archivos Clave

El proyecto se encuentra en el repositorio `/home/nicolas/Escritorio/noiz-apk`:
- **Frontend:** Flutter (Dart 3.x, null-safety estricto) con `flutter_riverpod` para el estado y `go_router` para la navegación.
- **Base de Datos Local:** SQLite (`drift` / `sqlite3_flutter_libs`) empaquetada en `assets/db/transit.sqlite` (~7.7 MB, 136 paradas de Euskadi incluyendo las 47 estaciones oficiales de Metro Bilbao L1, L2 y L3, Renfe Cercanías C1/C2/C3, Tranvía, Bilbobus, Bizkaibus, Euskotren, Dbus y TUVISA).
- **Mapas:** `maplibre_gl` con teselas vectoriales abiertas de OpenFreeMap (sin dependencias ni claves de Google Maps).
- **Backend:** Supabase (`env/dev.json` configurado en `https://ocxcrxgagennmukuxnle.supabase.co`).
- **Live Activity / Android Notification:** Canal de primer plano en `android/app/src/main/kotlin/com/bizkaia/transit/TransitLiveService.kt` con canal `transit_live_trip_channel_v4` (`IMPORTANCE_DEFAULT`).

### Mapa de Archivos Críticos
- Enrutamiento y Shell:
  - `lib/presentation/navigation/app_router.dart`: Definición de rutas GoRouter.
  - `lib/presentation/navigation/app_shell.dart`: Barra de navegación inferior y FAB selector de operador.
- Pantallas Principales:
  - `lib/presentation/screens/metro/metro_departures_screen.dart`: Pantalla principal de salidas y selector origen-destino.
  - `lib/presentation/screens/map/`: Carpeta destinada a la nueva pantalla de mapa interactivo (`TransitMapScreen`).
  - `lib/presentation/widgets/map/transit_map_view.dart`: Widget de mapa basado en MapLibre GL.
  - `lib/presentation/screens/alerts/service_alerts_screen.dart`: Pantalla de incidencias y avisos.
  - `lib/presentation/screens/planner/route_planner_screen.dart`: Planificador de rutas origen-destino.
- Servicios y Estado:
  - `lib/core/services/location_service.dart`: Servicio nativo de geolocalización por MethodChannel.
  - `lib/presentation/providers/transit_providers.dart`: Providers de paradas, salidas, ubicación y operadores.
  - `lib/data/local/app_database.dart`: Consultas Drift/SQLite locales a las tablas GTFS.
  - `android/app/src/main/kotlin/com/bizkaia/transit/MainActivity.kt`: Handlers de permisos de localización y notificaciones.
  - `android/app/src/main/kotlin/com/bizkaia/transit/TransitLiveService.kt`: Servicio en primer plano para la notificación en pantalla de bloqueo.

---

## 3. Directivas de Mejora Inmediatas

### Directiva A: Optimización de Scroll y Fluidez
- **Problema actual:** Pantallas con `SingleChildScrollView` anidados, recalculando listas completas en cada frame y provocando tirones.
- **Acción requerida:**
  1. Migrar las pantallas principales (`MetroDeparturesScreen`, `ServiceAlertsScreen`) a `CustomScrollView` con `SliverPersistentHeader` y `SliverList.builder`.
  2. Implementar `itemExtent` o `prototypeItem` en las listas de salidas para eliminar el cálculo de dimensiones en tiempo de scroll.
  3. Envolver widgets animados o con gradientes en `RepaintBoundary` para aislar su capa de repintado.
  4. Cachear selectores de Riverpod mediante `.select(...)` para evitar que un cambio menor de estado dispare el reconstruido de toda la lista.

### Directiva B: Redirecciones, Flujo de Navegación y Limpieza de UI
- **Problema actual:** Pantallas con componentes de simulación o pruebas (botones flotantes ficticios, widgets de simulador de Live Activity en rutas de usuario, banners repetitivos).
- **Acción requerida:**
  1. **Depuración de Pantalla:** Eliminar cualquier elemento de desarrollo o simulación de la vista del usuario final.
  2. **Navegación Intuitiva:** Asegurar que tocar una estación en el mapa o en una incidencia abra directamente la vista de salidas de esa estación con animación suave y botón de retroceso (`AppBar` con `leading: BackButton`).
  3. **Simplificación:** En la tarjeta de salidas, mostrar información prioritaria:
     - Línea y color identificador.
     - Destino claro en tipografía destacada.
     - Minutos restantes ("2 min", "5 min", "12 min") con color de estado (verde puntual, ámbar demorado).
     - Si hay filtro de destino activo, mantener una barra sutil y dismissible ("Hacia Kabiezes ✕").

### Directiva C: Sustitución de "Viajes" por Pantalla de Mapa Interactivo (`TransitMapScreen`)
- **Problema actual:** La segunda pestaña de la barra inferior navega a `/saved-trips`, una lista poco dinámica. El usuario necesita ver el transporte geográficamente en tiempo real.
- **Acción requerida:**
  1. **Nueva Pantalla Principal de Mapa (`/map`):**
     - Reemplazar la ruta `/saved-trips` en `AppShell` y `AppRouter` por `TransitMapScreen` con icono de mapa (`Icons.map_rounded`).
  2. **Carga Inicial Geolocalizada:**
     - Al entrar a la pantalla, detectar la posición GPS real del usuario mediante `locationServiceProvider`.
     - Centrar la cámara de MapLibre en sus coordenadas con un zoom caminable (zoom 15.5).
     - Marcar la posición del usuario con un pin azul pulsante.
     - Cargar automáticamente todas las paradas (Metro, Bus, Tren, Tranvía) en un radio de 600 metros desde SQLite.
  3. **Exploración Dinámica al Mover el Mapa:**
     - Escuchar el evento `onCameraIdle` del controlador de MapLibre.
     - Obtener el centro o el `LatLngBounds` visible del mapa.
     - Con un *debounce* de 250 ms, consultar a SQLite las paradas ubicadas en ese cuadrante y actualizar los marcadores.
  4. **Bottom Sheet de Salidas en Vivo:**
     - Al tocar cualquier parada en el mapa, desplegar un panel inferior deslizante (*modal draggable sheet*) con las próximas salidas de esa parada en tiempo real.
     - Permitir seleccionar esa parada como Origen o Destino con un solo toque.

### Directiva D: Ubicación GPS Confiable y Avisos Geolocalizados
- **Acción requerida:**
  1. **Permiso de Ubicación:** Al iniciar la app, solicitar educadamente el permiso de ubicación si no está concedido. Si el usuario lo deniega, fijar la ubicación por defecto en el centro de Bilbao (Plaza Moyúa: `43.2630, -2.9349`) sin mostrar errores intrusivos.
  2. **Avisos e Incidencias Geolocalizadas (`ServiceAlertsScreen`):**
     - Calcular la distancia en kilómetros (fórmula de Haversine) entre la posición GPS del usuario y las paradas o líneas afectadas por cada incidencia.
     - Mostrar primero la sección: **"Cerca de ti (< 3 km)"** con alertas prioritarias que afecten a su entorno inmediato.
     - Agrupar el resto bajo "Toda la red" con chips de filtrado por operador (Metro, Bizkaibus, Euskotren, Cercanías).

### Directiva E: Rediseño del Live Activity y Notificación en Pantalla de Bloqueo
- **Problema actual:** La notificación nativa en Android es genérica o puede no destacar en la pantalla de bloqueo.
- **Acción requerida:**
  1. **Android Foreground Service (`TransitLiveService.kt`):**
     - Diseñar una notificación enriquecida con `NotificationCompat.BigTextStyle` o vista personalizada.
     - Contenido:
       - **Título:** `Metro Bilbao: L1 Plentzia` (o la línea/destino activo).
       - **Texto Principal:** `Próxima salida en 3 min (14:32)` • `Siguiente: 8 min`.
       - **Subtexto:** `Estación Moyua • Andén 1`.
       - **Acciones Rápidas:** Botón `[ ↻ Actualizar ]` y botón `[ Finalizar ]`.
     - Configurar `CATEGORY_NAVIGATION` y `VISIBILITY_PUBLIC` para garantizar que sea visible con el teléfono bloqueado.
  2. **iOS ActivityKit (Especificación Lista para Swift):**
     - Estructura `ActivityAttributes` para `TransitTripAttributes` con Dynamic Island:
       - Modo Compact: Icono de línea + minutos restantes en color de línea.
       - Modo Expanded / Lock Screen: Barra de progreso de la ruta, estación de origen, estación de destino, hora estimada y estado de puntualidad.

---

# PARTE II: Especificación Universal de Integración de Operadores de Transporte

A continuación se detalla la especificación técnica universal para la integración de cualquier operador en la plataforma:

```markdown
# Prompt: Integración de datos de transporte público (cualquier operador)

## 1. Rol

Actúa como arquitecto de software senior especializado en datos de movilidad (GTFS, GTFS-RT, SIRI), backend con Supabase/Postgres y apps móviles en Flutter. Tu objetivo es diseñar y generar la integración completa de **un operador de transporte** de forma que el mismo patrón sirva para **cualquier otro operador o modo** (metro, tranvía, autobús urbano e interurbano, cercanías, ferry, funicular, bici compartida, etc.).

## 2. Contexto del proyecto

- App móvil en **Flutter** (iOS y Android) para consultar horarios, seguimiento en tiempo real y alertas.
- Backend en **Supabase** (plan gratuito siempre que sea viable): Postgres, Auth, Storage, Edge Functions, Realtime, `pg_cron`, `pg_net`.
- No existe API pública propia del operador: se consumen **ficheros publicados en portales de datos abiertos** (URL estable de descarga).
- Los usuarios **nunca** consultan al operador directamente: el backend descarga una vez y todos leen de Supabase.

### Variables de entrada (rellenar por operador)

| Variable | Valor |
|---|---|
| `OPERATOR_ID` | _ej. `metro_bilbao`_ |
| `OPERATOR_NAME` | _nombre comercial_ |
| `MODE` | _metro / bus / tranvía / tren / ferry / otro_ |
| `GTFS_STATIC_URL` | _URL del .zip_ |
| `GTFS_RT_TRIP_UPDATES_URL` | _URL .pb o `N/A`_ |
| `GTFS_RT_VEHICLE_POSITIONS_URL` | _URL .pb o `N/A`_ |
| `GTFS_RT_ALERTS_URL` | _URL .pb o `N/A`_ |
| `SIRI_URL` | _URL XML o `N/A`_ |
| `LICENSE` | _licencia y requisito de atribución_ |
| `TIMEZONE` | _ej. `Europe/Madrid`_ |

Si algún dato falta, **no lo inventes**: márcalo como `PENDIENTE DE VERIFICAR` y propón cómo comprobarlo.

## 3. Principios obligatorios

1. **Agnóstico de operador y de modo**: todo el esquema, scripts y funciones se parametrizan por `operator_id`. Añadir un operador nuevo = añadir configuración, no código.
2. **IDs con prefijo de operador** (`{operator_id}:{id_original}`) en todas las tablas para evitar colisiones entre feeds.
3. **Separar estático y tiempo real**: GTFS (horarios teóricos) y GTFS-RT/SIRI (retrasos, posiciones, alertas) tienen ciclos y destinos distintos.
4. **Degradación elegante**: si un operador no publica trip updates o alertas, la app sigue funcionando con horario teórico y/o posiciones.
5. **Idempotencia**: toda ingesta usa upsert o reemplazo por versión; ejecutarla dos veces no duplica datos.
6. **Mínimo coste y mínimo consumo**: no consultar más rápido que `header.timestamp` del feed; no guardar histórico infinito salvo que se pida.
7. **Seguridad por defecto**: RLS activado, claves de servicio solo en backend, ningún secreto en la app ni en el repositorio.
8. **Respeto de licencias**: documentar atribución y condiciones de reutilización de cada dataset.

## 4. Fase 0: Descubrimiento y validación del feed

Antes de escribir código, genera un informe de viabilidad por operador:

- ¿Qué feeds existen realmente (estático, trip updates, vehicle positions, alerts, SIRI)?
- Frecuencia real de actualización (medida con `header.timestamp`, no asumida).
- Peso del GTFS y número aproximado de filas de `stop_times`.
- ¿Los `trip_id` / `route_id` / `stop_id` del feed RT coinciden con los del GTFS estático? Probar con una muestra y reportar el porcentaje de coincidencia.
- Calendarios: `calendar.txt`, `calendar_dates.txt`, excepciones y festivos.
- Soporte de `frequencies.txt` (servicios por intervalo, común en metro y tranvía).
- Cobertura de accesibilidad, `shapes.txt`, `fare_*`, `transfers.txt`.
- Codificación, zona horaria y horas > 24:00:00 (viajes que cruzan medianoche).

Entrega: tabla resumen con semáforo (verde/ámbar/rojo) y limitaciones detectadas.

## 5. Fase 1: GTFS estático

**Ejecución**: script externo (Python o Node) lanzado por GitHub Actions con cron (diario o semanal). **No** usar Edge Functions para esto (límites de tiempo y memoria).

Tareas:

1. Descargar el .zip, comprobar hash/`ETag`/`Last-Modified` y abortar si no hay cambios.
2. Validar con un validador GTFS (p. ej. MobilityData GTFS Validator) y registrar avisos.
3. Normalizar: prefijar IDs, convertir horas > 24h, resolver calendarios a fechas de servicio concretas.
4. Cargar en Postgres con `COPY` o upserts por lotes.
5. Generar un **SQLite optimizado por operador** (solo columnas e índices que la app necesita), con número de versión, y subirlo a **Supabase Storage**.
6. Registrar la ejecución en una tabla `ingest_runs` (operador, tipo, versión, filas, duración, errores).

### Esquema mínimo (Postgres)

```sql
create table operators (
  id text primary key,
  name text not null,
  mode text not null,
  timezone text not null,
  license text,
  attribution text
);

create table stops (
  id text primary key,            -- operator_id:stop_id
  operator_id text references operators(id),
  name text not null,
  lat double precision,
  lon double precision,
  wheelchair_boarding smallint,
  parent_station text
);

create table routes (
  id text primary key,
  operator_id text references operators(id),
  short_name text,
  long_name text,
  route_type smallint,
  color text,
  text_color text
);

create table trips (
  id text primary key,
  operator_id text references operators(id),
  route_id text references routes(id),
  service_id text,
  headsign text,
  direction_id smallint,
  shape_id text
);

create table stop_times (
  trip_id text references trips(id),
  stop_sequence int,
  stop_id text references stops(id),
  arrival_secs int,               -- segundos desde medianoche (admite > 86400)
  departure_secs int,
  primary key (trip_id, stop_sequence)
);

create index on stop_times (stop_id, departure_secs);
```

Añadir `service_dates`, `frequencies`, `shapes`, `transfers` y `fares` solo si el feed los incluye.

### Estrategia del SQLite en el móvil

- Un archivo por operador; el usuario descarga solo los que usa.
- La app guarda la versión local y, al abrir, consulta la versión remota; si es mayor, descarga y sustituye de forma atómica.
- Debe funcionar **offline** para: próximas salidas en una parada, búsqueda de paradas y planificación básica.
- Librería sugerida en Flutter: `drift` o `sqflite`.

## 6. Fase 2: Tiempo real (GTFS-RT / SIRI)

**Ejecución**: Edge Function de Supabase invocada por `pg_cron` + `pg_net` (cada 30 s si la versión lo admite; si no, cada minuto). Una función por tipo de feed, parametrizada por `operator_id`.

| Feed | Tabla destino | Estrategia |
|---|---|---|
| Vehicle positions | `vehicle_positions` | Upsert por `vehicle_id`, una fila por vehículo (sin histórico) |
| Trip updates | `trip_updates` / `stop_time_updates` | Upsert por `trip_id` + `stop_id`; purgar entradas caducadas |
| Alerts | `alerts` | Upsert por `alert_id`; guardar líneas/paradas afectadas, texto multilingüe y periodo de validez |

Reglas:

- Decodificar con `gtfs-realtime-bindings` (protobuf). Si el operador solo ofrece SIRI, parsear XML y **mapear al mismo modelo interno**.
- Ignorar feeds cuyo `header.timestamp` sea más antiguo que un umbral (p. ej. 5 min) y marcarlo como `stale`.
- Manejar `ScheduleRelationship` (`SCHEDULED`, `ADDED`, `CANCELED`, `SKIPPED`, `NO_DATA`).
- Tabla `feed_health` por operador y feed: última descarga correcta, latencia, código HTTP, número de entidades.
- Reintentos con backoff y sin romper el resto de operadores si uno falla.
- Activar **Supabase Realtime** solo en las tablas que la app escucha (`vehicle_positions`, `alerts`, `trip_updates`).

## 7. Fase 3: Fusión horario teórico + tiempo real

La app (y el backend cuando haga falta) debe calcular la hora estimada así:

```
hora_estimada = horario_teórico (SQLite) + retraso (Supabase)
```

Casos a cubrir explícitamente:

- Viaje cancelado, añadido, saltado o desviado.
- IDs del feed RT que no existen en el estático (registrar y tratar como "sin dato").
- Servicios por frecuencia (sin hora fija): mostrar "cada X min" y estimar por posición.
- Cruces de medianoche y cambios de día de servicio.
- Cambio horario (CET/CEST).
- Si no hay dato RT: mostrar el horario teórico con indicador visible de "sin tiempo real".

## 8. Fase 4: Alertas, notificaciones y Live Activities

1. Tabla `user_favorites` (usuario, operador, línea, parada, sentido, franjas horarias).
2. Al insertar una alerta o un retraso relevante, un trigger o función cruza con los favoritos y genera notificaciones.
3. **Android**: FCM con notificación persistente actualizada (y "live updates" en Android 16 si está disponible).
4. **iOS**: Live Activities con ActivityKit.
   - Tabla `live_activity_tokens` (usuario, `activity_id`, push token, viaje/parada, estado, caducidad).
   - Envío por APNs solo cuando hay **cambio relevante** (retraso, llegada inminente, cancelación), respetando los límites de frecuencia.
   - Soportar push-to-start para viajes habituales.
   - Requiere cuenta de Apple Developer y clave APNs (guardada solo en secretos del backend).
5. Limpiar tokens caducados o inválidos tras cada respuesta de APNs/FCM.

## 9. Seguridad y privacidad

- **RLS** en todas las tablas con datos de usuario; tablas de transporte en solo lectura para `anon`/`authenticated`.
- `service_role` únicamente en Edge Functions y GitHub Actions (secretos cifrados).
- Validar y sanear todo lo que venga de feeds externos (son datos no confiables).
- Limitar el tamaño de descarga y el tiempo de espera de cada petición.
- Minimizar datos personales: guardar solo lo necesario para notificar; permitir borrado de cuenta y datos.
- No registrar tokens ni claves en logs.

## 10. Rendimiento y coste (plan gratuito de Supabase)

- Estimar tamaño de base de datos, filas y ejecuciones de Edge Functions al mes y comparar con los límites del plan.
- Purgar datos RT caducados; no almacenar histórico por defecto.
- Índices solo donde las consultas lo justifiquen.
- Preferir el SQLite local para consultas de horarios y dejar a Supabase solo lo dinámico.
- Si el plan gratuito se queda corto, indicar qué componente escala primero y alternativas.

## 11. Observabilidad y pruebas

- Logs estructurados por operador y fase; tabla `ingest_runs` y `feed_health` consultables.
- Alertas internas si un feed lleva N minutos sin actualizarse.
- Pruebas unitarias del parseo y de la fusión estático + RT con fixtures reales.
- Pruebas de regresión con un GTFS de ejemplo por modo (metro, bus, tren).
- Checklist de validación antes de publicar un operador nuevo.

## 12. Cómo añadir un operador nuevo (plantilla)

1. Rellenar la tabla de variables de la sección 2.
2. Ejecutar la Fase 0 y revisar el informe de viabilidad.
3. Añadir el registro en `operators` y su configuración (URLs, frecuencia, mapeos especiales).
4. Lanzar la ingesta estática y generar su SQLite.
5. Activar las funciones RT disponibles.
6. Verificar la fusión con casos reales.
7. Documentar licencia y atribución en la app.

## 13. Formato de entrega esperado

Genera, en este orden y sin saltarte pasos:

1. **Informe de viabilidad** del operador (Fase 0).
2. **Arquitectura** con diagrama en texto o Mermaid.
3. **SQL** completo (tablas, índices, RLS, funciones, `pg_cron`).
4. **Script de ingesta estática** + workflow de GitHub Actions.
5. **Edge Functions** de tiempo real, comentadas.
6. **Generador del SQLite** con versionado.
7. **Código Flutter** de la capa de datos (SQLite local, Realtime, fusión).
8. **Backend de notificaciones y Live Activities**.
9. **Pruebas** y checklist de validación.
10. **Riesgos, limitaciones y siguientes pasos.**

## 14. Reglas de comportamiento

- Responde en **español**.
- Explica cada decisión de diseño en 1-2 frases; sin relleno.
- Si algo es una suposición, márcalo como tal.
- No inventes URLs, campos ni límites de servicios: verifica o marca como pendiente.
- Código completo y ejecutable, no fragmentos con "..." salvo que se indique.
- Si hay varias opciones, recomienda una y justifica brevemente por qué.
- Ante ambigüedad bloqueante, haz **una sola pregunta**; si no bloquea, avanza con una suposición declarada.
```

---

# PARTE III: Checklist de Verificación para el Agente

Cuando ejecutes las tareas asignadas en este documento, debes verificar uno a uno los siguientes puntos:

- [ ] **Scroll 60 FPS:** Ninguna pantalla principal produce caídas de frames al desplazarse rápidamente.
- [ ] **Sustitución de Pantalla:** La ruta `/map` está activa en la barra inferior en lugar de `/saved-trips`, cargando la ubicación real del usuario de forma inmediata y explorando paradas al mover la cámara.
- [ ] **Avisos Ordenados por Proximidad:** La pantalla `/alerts` muestra arriba del todo las incidencias que afectan a estaciones o líneas a menos de 3 km del usuario.
- [ ] **Live Activity Profesional:** La notificación persistente en Android se visualiza claramente en la pantalla de bloqueo con tipografía legible, badge de línea, minutos restantes y acciones de control.
- [ ] **Limpieza de UI:** Todos los elementos superfluos o botones de simulación eliminados del flujo del usuario común.
- [ ] **Compilación y Tests:** `flutter analyze` reporta 0 errores o advertencias, y `flutter test` pasa al 100%.
