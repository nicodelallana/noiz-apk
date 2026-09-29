# Contexto del Proyecto — Bizkaia Transit

## 1. Visión y objetivos

**Problema.** Consultar cuándo pasa el metro o el bus obliga a abrir el móvil, buscar y elegir origen/destino, algo incómodo con lluvia, prisa o las manos ocupadas.

**Solución.** Una app que guarda tus trayectos habituales y los muestra en un **widget de pantalla de inicio** con la siguiente salida, sin abrir nada. Además: planificador ("quiero ir de A a B, ¿qué línea cojo?"), incidencias, compartir trayectos y (fase posterior) comprobar si el saldo Barik llega para el viaje.

**Trayecto de referencia para pruebas:** Metro Bilbao L2, Bagatza ⇄ Kabiezes (en Barakaldo la estación de L2 se llama Bagatza). Segundo caso de prueba: Barakaldo → Mungia (requiere planificador multimodal).

**Objetivos medibles (v1.0)**
- Widget con la próxima salida en < 1 s desde que el usuario ve la pantalla (datos precalculados en local).
- Funciona **sin conexión** con horarios teóricos.
- Coste de infraestructura mensual: 0 € en fase de lanzamiento.
- Cobertura v1: Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe Cercanías Bilbao.

**Fuera de alcance v1:** pagos, recarga de Barik, billete digital, mapas de navegación a pie, cuentas con email/contraseña.

---

## 2. Fases

| Fase | Contenido |
|---|---|
| **MVP (0.x)** | Metro Bilbao completo (horarios GTFS + tiempo real CTB + avisos). Login Google. Viajes guardados. Widget Android + iOS. Animaciones Lottie básicas. |
| **v1.0** | Bizkaibus, Bilbobus, Euskotren, Renfe. Incidencias unificadas. Planificador con líneas directas. Compartir viaje por código. Saldo Barik **manual** + cálculo de suficiencia con tarifas. |
| **v1.x** | Planificador con transbordos. Notificaciones ("sal ya de casa"). Live Activities (iOS) / notificación persistente (Android). |
| **v2** | Lectura NFC de Barik (solo tras análisis legal/técnico). Enlaces universales para compartir. |

---

## 3. Stack tecnológico

**Lenguaje y framework:** Dart (null safety, `strict-casts`, `strict-inference`, `strict-raw-types`) + Flutter (canal `stable`, versión fijada en `.fvmrc` con FVM). Widgets nativos en **Kotlin** (Android) y **Swift/SwiftUI** (iOS).

| Necesidad | Librería / servicio | Notas |
|---|---|---|
| Backend | **Supabase** (Auth + Postgres + Storage + Edge Functions) | Plan Free al inicio |
| Cliente Supabase | `supabase_flutter` | |
| Login Google | `google_sign_in` + `supabase.auth.signInWithIdToken` | Flujo nativo |
| Login Apple | `sign_in_with_apple` | Obligatorio en iOS si se ofrece login social |
| Estado | `flutter_riverpod` (+ `riverpod_generator`) | |
| Navegación | `go_router` con `StatefulShellRoute` | Una rama por transporte |
| BD local | `drift` (SQLite) | Horarios GTFS offline |
| HTTP | `dio` (timeouts, reintentos, cache ETag/If-Modified-Since) | |
| Protobuf GTFS-RT | bindings Dart de `gtfs-realtime.proto` | Decodificar en un `Isolate` |
| Widgets | `home_widget` + código nativo | Datos vía App Group (iOS) / SharedPreferences (Android) |
| Animaciones | `lottie` | Sobrio, < 50 KB, accesible |
| Segundo plano | `workmanager` (Android) + `BGTaskScheduler` (iOS) | |
| NFC (fase v2) | `nfc_manager` | Solo lectura |
| Deep links | `app_links` | |
| Modelos | `freezed` + `json_serializable` | |
| Errores/telemetría | Firebase Crashlytics **o** Sentry | Sin datos personales |
| Tests | `flutter_test`, `mocktail`, `integration_test` | |
| Calidad | `very_good_analysis` (lints) | |
| CI/CD | GitHub Actions (+ Fastlane o Codemagic) | |

Regla: **no añadir dependencias sin justificarlo en el `design.md` del change.** Fijar versiones con `pubspec.lock`.

---

## 4. Arquitectura

```
                 ┌──────────────── GitHub Actions (cron nocturno) ────────────────┐
 Feeds estáticos │ descarga GTFS → valida → filtra Bizkaia → compacta → SQLite    │
 (5 operadores)─▶│ → sube a Supabase Storage + manifest.json (versión + hash)     │
                 │ → ping "keep-alive" a Supabase                                  │
                 └────────────────────────────────┬───────────────────────────────┘
                                                  ▼
 ┌──────────────┐   descarga pack   ┌────────────────────────────┐
 │  App Flutter │◀──────────────────│ Supabase Storage (público) │
 │  (drift)     │                   └────────────────────────────┘
 │              │   auth/datos usuario ┌───────────────────────────┐
 │              │◀────────────────────▶│ Supabase Auth + Postgres  │ (RLS)
 │              │                      └───────────────────────────┘
 │              │   tiempo real (protobuf, directo desde el móvil)
 │              │◀───────────────────── CTB S3 / baliabideak.bizkaia.eus / Renfe
 └──────┬───────┘
        │ App Group / SharedPreferences
        ▼
 Widget Android (Kotlin)    Widget iOS (WidgetKit)
```

**Decisiones clave**
1. **Los horarios viven en el móvil, no en Postgres.** SQLite compacto en Supabase Storage (1 GB en Free). Postgres solo guarda datos de usuario con RLS.
2. **El tiempo real se consulta directamente desde el móvil.** Sin CORS en nativo. Edge Function de caché solo si hay saturación futura.
3. **Modelo "teórico + corrección".** El widget muestra siempre el horario teórico local; si hay retraso conocido lo superpone. Nunca vacío sin red.
4. **Arquitectura por capas:** `presentation` → `domain` → `data`. Un *adapter* por operador que normaliza a un modelo común (`Stop`, `Route`, `Trip`, `Departure`, `Alert`).

---

## 13. Convenciones del proyecto (skills / guías para el agente)

### 13.1 Dart y Flutter
- `analysis_options.yaml` con `very_good_analysis` y `strict-*`. `dart format` y `flutter analyze` sin avisos en CI.
- Nada de lógica de negocio en widgets; nada de `BuildContext` en capas `domain/data`.
- Widgets `const` cuando se pueda; listas con `ListView.builder`; separar `build` grandes en widgets, no en métodos.
- Inmutabilidad (`freezed`), errores tipados (`sealed class Result`), sin `dynamic` ni `!` sin justificación.
- Trabajo pesado (decodificar protobuf, parsear GTFS, consultas grandes) en `Isolate`/`compute`.
- Fechas siempre en UTC internamente; convertir a `Europe/Madrid` solo para mostrar y para el día de servicio (paquete `timezone`).
- i18n con `flutter_localizations` + ARB (`es`, `eu`, `en`); ningún texto de UI hardcodeado.
- Tests: unitarios para adapters GTFS (fixtures reales, incluidos día siguiente, DST, viajes cancelados), *golden tests* de widgets clave, `integration_test` del flujo login → guardar → widget de datos.

### 13.2 Git
- Repo con `main` protegida. Trunk-based: ramas cortas `feat/…`, `fix/…`, `chore/…`, PR obligatorio con CI verde.
- **Conventional Commits** (`feat(widget): …`, `fix(gtfs): …`). Versionado SemVer + `CHANGELOG.md` generado.
- Un change de OpenSpec = una rama = un PR. El PR enlaza el `proposal.md`.
- `.gitignore`: `env/*.json`, `*.jks`, `key.properties`, `GoogleService-Info.plist`, `.dart_tool/`, builds.
- Pre-commit: `gitleaks` (secretos), `dart format`, `dart analyze`. Nunca `git push --force` sobre `main`.
- Etiquetas de release `vX.Y.Z` disparan el build de tiendas.

### 13.3 Animaciones
- Toda animación nueva pasa por: ¿aporta información o feedback?, ¿< 50 KB?, ¿respeta *reduce motion*?, ¿licencia registrada?
- Duraciones: micro-interacciones 150–300 ms, transiciones de pantalla ≤ 400 ms; curvas `Curves.easeOutCubic`.

### 13.4 Supabase
- Todo cambio de esquema = migración SQL versionada. Prohibido el `service_role` en la app.
- RLS **habilitado en toda tabla** y probado con tests (`supabase test db` / pgTAP): un usuario A no puede leer ni modificar datos del usuario B.
- Funciones `security definer` con `set search_path = public` y `revoke … from public`.
- Consultas con `select` explícito de columnas y `limit`; índices en columnas de filtro.
- Edge Functions: validar entrada (Zod/Valibot), CORS restrictivo, límites de tasa, sin logs de datos personales.
- Realtime de Supabase **no se usa** para transporte (el tiempo real viene de los feeds).

### 13.5 Ciberseguridad y buenas prácticas
- Referencia: **OWASP MASVS/MASTG** para móvil y OWASP Top 10 para APIs.
- Solo HTTPS (`usesCleartextTraffic=false` en Android, ATS en iOS).
- Tokens de sesión en almacenamiento seguro (Keychain / EncryptedSharedPreferences).
- Ofuscación de release: `flutter build … --obfuscate --split-debug-info=…` y R8/ProGuard.
- Sin datos sensibles en logs ni analytics no consentidos.
- Validar y **limitar** todo dato externo: feeds GTFS/GTFS-RT como entrada no confiable.
- Widgets/App Group: no guardar tokens en el contenedor compartido, solo datos de horarios.
- Deep links: validar esquema y parámetros (nunca ejecutar acciones destructivas).

### 13.6 Idioma del código y documentación
- Código, identificadores y commits en **inglés**; UI y documentación de usuario en es/eu/en; documentación interna del proyecto en español.
