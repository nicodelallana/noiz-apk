# Registro de Cambios y Paridad de Funcionalidades — Barik Transit

Este documento consolida la auditoría técnica, la arquitectura implementada y la matriz de fidelidad alcanzada respecto a la app de referencia (*Garraio* / `https://garraio.es/` y sus registros en vídeo).

---

## 1. Cobertura Integral de Operadores de Euskadi

Barik ha expandido su arquitectura de dominio y capa de datos de forma multi-operador y offline-first para dar cobertura completa a todos los modos y operadores de Bizkaia, Gipuzkoa y Araba.

| Operador | Modo de Transporte | Territorio | Fuente de Datos Oficial | Estado de Frecuencia / Tiempo Real |
| :--- | :--- | :--- | :--- | :--- |
| **Metro Bilbao** | Metro | Bizkaia | Consorcio de Transportes de Bizkaia (CTB) / Open Data Euskadi | **En directo** (GTFS-RT / Real-time feed) |
| **Bizkaibus** | Autobús Interurbano | Bizkaia | Diputación Foral de Bizkaia / Open Data Euskadi | **En directo** (GTFS-RT / Web Service) |
| **Bilbobus** | Autobús Urbano | Bizkaia | Ayuntamiento de Bilbao / Open Data Euskadi | **En directo** (GTFS-RT) |
| **Euskotren Tren & Topo** | Cercanías / Suburbano | Bizkaia / Gipuzkoa | Euskotren / Moveuskadi GTFS | **En directo** (GTFS-RT) |
| **Tranvía de Bilbao** | Tranvía | Bizkaia | Euskotren Tranbia / CTB | **En directo** (GTFS-RT) |
| **Tranvía de Vitoria-Gasteiz** | Tranvía | Araba | Euskotren Tranbia / Tuvisa Open Data | **En directo** (GTFS-RT) |
| **Renfe Cercanías Bilbao** | Cercanías | Bizkaia | Renfe Operadora / Ministerio de Transportes | **En directo** (GTFS-RT) |
| **Renfe Cercanías Donostia** | Cercanías | Gipuzkoa | Renfe Operadora / Moveuskadi | **En directo** (GTFS-RT) |
| **Dbus** | Autobús Urbano | Gipuzkoa | Donostiako Tranbia Konpainia / Donostia Open Data | **En directo** (GTFS-RT / SIRI) |
| **Lurraldebus** | Autobús Interurbano | Gipuzkoa | Diputación Foral de Gipuzkoa / Moveuskadi | **En directo** (GTFS-RT) |
| **TUVISA & BEI** | Autobús Urbano / Eléctrico | Araba | Ayuntamiento de Vitoria-Gasteiz | **En directo** (GTFS-RT) |
| **Álavabus** | Autobús Interurbano | Araba | Diputación Foral de Álava | **Según horario** (GTFS estático oficial) |
| **Funicular de Artxanda** | Funicular | Bizkaia | Funicular de Artxanda S.A. | **Según horario** (Frecuencia 15 min) |
| **Autobuses La Unión** | Autobús Interurbano | Álava / Bizkaia | La Unión / Moveuskadi | **Según horario** (Horarios oficiales estáticos) |

---

## 2. Live Activities Kit (Seguimiento en Pantalla de Bloqueo)

Se implementó un kit de pantalla de bloqueo desacoplado y reutilizable en Flutter, Android nativo (Kotlin) e iOS nativo (Swift).

### 2.1 Modelo de Datos Unificado (`LiveTripState`)
Sincronizado entre Dart (`lib/domain/models/live_trip_models.dart`), Kotlin (`TransitLiveService.kt`), Swift (`LiveTripWidgetAttributes.swift`) y Edge Functions en TypeScript (`supabase/functions/live-trip-push/index.ts`):
- `tripId`, `operatorId`, `mode`, `lineId`, `lineName`, `lineColor`
- `origin`, `destination`, `currentStop`, `nextStop`
- `stopsRemaining`, `progress` (0.0 a 1.0)
- `arrivalTime` (marca de tiempo absoluta en milisegundos para renderizado autónomo de cronómetros por el SO sin drenar la batería del terminal)
- `status`: `scheduled | tracking | arriving | at_stop | delayed | disrupted | ended`
- `isRealtime`, `delaySeconds`, `instruction`, `updatedAt`

### 2.2 Android Nativo
- **Servicio:** `android/app/src/main/kotlin/com/bizkaia/transit/live/TransitLiveService.kt`.
- **Servicio Foreground:** `foregroundServiceType="specialUse"` en Android 14+ con canal de notificación permanente `barik_live_trip` (`IMPORTANCE_LOW` para evitar alertas audibles en cada actualización).
- **Visibilidad:** `VISIBILITY_PUBLIC` para mostrarse en la pantalla de bloqueo.
- **Cuenta atrás:** Uso de `NotificationCompat.Builder.setChronometerCountDown(true)` y `setUsesChronometer(true)` con la marca de tiempo absoluta de llegada.
- **Acciones:** Acción rápida "Terminar viaje" (`ACTION_STOP_LIVE_TRIP`) directa desde la notificación.

### 2.3 iOS Nativo (ActivityKit & Dynamic Island)
- **Atributos:** `ios/LiveTripWidget/LiveTripWidgetAttributes.swift`.
- **Live Activity:** `ios/LiveTripWidget/LiveTripWidgetLiveActivity.swift`.
- **Dynamic Island:**
  - *Compact:* Indicador de línea en leading y cuenta atrás de minutos en trailing.
  - *Minimal:* Badge circular con color oficial del operador y minutos restantes.
  - *Expanded:* Cabecera con origen y destino, vía escénica interactiva, barra de progreso y cronómetro relativo con `Text(timerInterval: ...)`.
- **Pantalla de bloqueo:** Tarjeta con fondo oscuro `Midnight (#0B0D14)`, insignia del operador, barra de progreso con gradiente y próxima parada.
- **Guía de integración Xcode:** Detallada en `docs/ios-live-activities-setup.md`.

### 2.4 Simulador en Dispositivo
- Disponible en la app mediante la ruta `/simulator` o el botón de transmisión en la barra superior.
- Permite alternar instantáneamente entre los 7 estados (`scheduled`, `tracking`, `arriving`, `at_stop`, `delayed`, `disrupted`, `ended`) y observar la actualización instantánea de la notificación del sistema.

### 2.5 Backend Supabase y Edge Function
- **Migración:** `supabase/migrations/20261102000000_multi_operator_and_live_trip_sessions.sql`.
  - Tablas: `live_trip_sessions`, `operators_catalog`, `service_alerts`.
  - Políticas RLS: los usuarios solo pueden actualizar o consultar sus propias sesiones; alertas y catálogo de lectura pública.
- **Edge Function:** `supabase/functions/live-trip-push/index.ts`.
  - Agrupación por viaje para consultar la fuente GTFS-RT una única vez independientemente de cuántos usuarios sigan la misma expedición (ahorro en consumo del plan gratuito de Supabase).
  - Envío dual: APNs (token de Live Activity) y FCM para terminales Android.

---

## 3. Experiencia Visual y Motion Design

### 3.1 Tokens de Diseño Extraídos de la Referencia
- **Fondo primario:** `--fondo: #0B0D14` (Midnight Deep).
- **Superficie de tarjetas:** `--superficie: #151822` con borde sutil `rgba(245, 247, 255, 0.08)`.
- **Superficie elevada:** `--elevada: #1C202D` con esquinas redondeadas de 22px (`BorderRadius.circular(22)`).
- **Curva de transición:** `Cubic(0.23, 1, 0.32, 1)` para animaciones orgánicas de 280ms a 380ms.
- **Colores de estado:**
  - En directo: `#2BB081` con chip "En directo" y pulso de actividad.
  - Retraso: `#FFB84D` con indicación `+X min`.
  - Sin tiempo real: `#9198AD` etiquetado formalmente como "Según horario" (nunca "horario teórico").
  - Incidencia / Avería: `#FF4D4D`.

### 3.2 Componentes Nuevos
- `AmbientGlowBackground`: Halo ambiental sutil que adopta el color temático del operador activo.
- `ScenicProgressTrack` (`trayecto-hero__via`): Vía escénica con estaciones intermedias, vehículo en posición de progreso y efecto de ondas expansivas.
- `DepartureHeroCard`: Tarjeta destacada de próxima salida con botón de acción directa "Seguir en pantalla de bloqueo".
- `NearbyTransitScreen` ("Cerca de ti"): Radar de paradas de todos los operadores del territorio seleccionado con tarjeta desplegable de horarios.
- `RoutePlannerScreen` ("Tu ruta paso a paso"): Planificador multimodal con desglose de transbordos y tramos a pie.
- `ServiceAlertsScreen` ("Incidencias"): Feed consolidado de avisos oficiales de tráfico y afecciones de servicio en Euskadi.

---

## 4. Auditoría de Calidad y Tests

- **Flutter Analyze:** 0 errores, 0 advertencias. Código verificado con análisis estricto (`strict-casts`, `strict-inference`, `strict-raw-types`).
- **Flutter Test:** 32 tests unitarios y de componentes ejecutados con éxito.
- **Regla Estricta de Texto:** Ninguna vista, modelo o notificación contiene la expresión genérica "horario teórico"; toda expedición sin seguimiento satelital se presenta como "Según horario".
- **Privacidad y Autenticación:** Se eliminó cualquier soporte para correo/contraseña en favor exclusivo de inicio de sesión con Google (y Apple en iOS).

---

## 5. Parámetros Externos y Credenciales Requeridas del Usuario

Para habilitar el envío remoto de actualizaciones en segundo plano vía APNs y FCM cuando la aplicación no está en ejecución, se deben configurar los siguientes secretos en el panel de Supabase (`supabase secrets set`):

1. **Apple Push Notification service (APNs) para iOS:**
   - `APNS_KEY_ID`: ID de 10 caracteres de la clave APNs generada en Apple Developer.
   - `APNS_TEAM_ID`: ID del equipo de desarrollador de Apple (10 caracteres alfanuméricos).
   - `APNS_BUNDLE_ID`: `com.bizkaia.transit`.
   - `APNS_PRIVATE_KEY`: Contenido del archivo de clave privada `.p8`.
2. **Firebase Cloud Messaging (FCM) para Android:**
   - `FCM_PROJECT_ID`: ID del proyecto de Firebase.
   - `FCM_SERVICE_ACCOUNT_JSON`: Credenciales JSON de la cuenta de servicio de Firebase con rol "Firebase Cloud Messaging API".
