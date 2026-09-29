# SPEC — Bizkaia Transit (nombre provisional)

> App móvil (Android + iOS) para consultar transporte público de Bizkaia de un vistazo: viajes guardados, widgets, incidencias, planificador y, a futuro, saldo Barik.
> Documento vivo. Fecha de redacción: 29-09-2026. Las URLs y límites marcados **[VERIFICADO]** se comprobaron en fuentes oficiales o repositorios activos al redactar; los marcados **[POR VERIFICAR]** son inferencias que hay que confirmar con una petición real antes de programar sobre ellos.

---

## 0. Cómo usar este documento con OpenSpec

Este fichero es la **fuente de contexto** del proyecto. Para trabajar con OpenSpec (Fission-AI):

1. Instala el CLI: `npm install -g @fission-ai/openspec@latest` y ejecuta `openspec init` en la raíz del repo.
2. Copia las secciones 1–4 y 13 al fichero de contexto del proyecto que genere `openspec init` (`openspec/project.md` o `openspec/config.yaml`, según versión).
3. Las capacidades de la sección 12 están escritas en formato OpenSpec (`### Requirement:` + `#### Scenario:`). Cada una pasa a `openspec/specs/<capacidad>/spec.md`.
4. Flujo de trabajo por funcionalidad, dentro de tu asistente de IA: `/opsx:explore` (pensar) → `/opsx:propose <nombre>` (crea `openspec/changes/<nombre>/` con `proposal.md`, `specs/`, `design.md`, `tasks.md`) → revisar → `/opsx:apply` (implementar) → `/opsx:archive` (fusiona los deltas en `openspec/specs/`).
5. Regla: **ninguna funcionalidad se programa sin un change de OpenSpec aprobado.**

---

## 1. Visión y objetivos

**Problema.** Consultar cuándo pasa el metro o el bus obliga a abrir el móvil, buscar y elegir origen/destino, algo incómodo con lluvia, prisa o las manos ocupadas.

**Solución.** Una app que guarda tus trayectos habituales y los muestra en un **widget de pantalla de inicio** con la siguiente salida, sin abrir nada. Además: planificador ("quiero ir de A a B, ¿qué línea cojo?"), incidencias, compartir trayectos y (fase posterior) comprobar si el saldo Barik llega para el viaje.

**Trayecto de referencia para pruebas:** Metro Bilbao L2, Bagatza ⇄ Kabiezes (en tu mensaje figura "Bagacha"; la estación de L2 en Barakaldo se llama Bagatza). Segundo caso de prueba: Barakaldo → Mungia (requiere planificador multimodal).

**Objetivos medibles (v1.0)**
- Widget con la próxima salida en < 1 s desde que el usuario ve la pantalla (datos precalculados en local).
- Funciona **sin conexión** con horarios teóricos.
- Coste de infraestructura mensual: 0 € en fase de lanzamiento (con las salvedades de la sección 9).
- Cobertura v1: Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe Cercanías Bilbao.

**Fuera de alcance v1:** pagos, recarga de Barik, billete digital, mapas de navegación a pie, cuentas con email/contraseña.

---

## 2. Fases

| Fase | Contenido |
|---|---|
| **MVP (0.x)** | Metro Bilbao completo (horarios GTFS + tiempo real CTB + avisos). Login Google. Viajes guardados. Widget Android + iOS. Animaciones Lottie básicas. |
| **v1.0** | Bizkaibus, Bilbobus, Euskotren, Renfe. Incidencias unificadas. Planificador con líneas directas. Compartir viaje por código. Saldo Barik **manual** + cálculo de suficiencia con tarifas. |
| **v1.x** | Planificador con transbordos. Notificaciones ("sal ya de casa"). Live Activities (iOS) / notificación persistente (Android). |
| **v2** | Lectura NFC de Barik (solo tras análisis legal/técnico, ver §8). Enlaces universales para compartir. |

---

## 3. Stack tecnológico

**Lenguaje y framework:** Dart (null safety, `strict-casts`, `strict-inference`, `strict-raw-types`) + Flutter (canal `stable`, versión fijada en `.fvmrc` con FVM). Widgets nativos en **Kotlin** (Android) y **Swift/SwiftUI** (iOS).

| Necesidad | Librería / servicio | Notas |
|---|---|---|
| Backend | **Supabase** (Auth + Postgres + Storage + Edge Functions) | Plan Free al inicio, ver §9 |
| Cliente Supabase | `supabase_flutter` | |
| Login Google | `google_sign_in` + `supabase.auth.signInWithIdToken` | Flujo nativo; ver §7 |
| Login Apple | `sign_in_with_apple` | Probablemente obligatorio en iOS (§7) |
| Estado | `flutter_riverpod` (+ `riverpod_generator`) | |
| Navegación | `go_router` con `StatefulShellRoute` | Una rama por transporte |
| BD local | `drift` (SQLite) | Horarios GTFS offline |
| HTTP | `dio` (timeouts, reintentos, cache ETag/If-Modified-Since) | |
| Protobuf GTFS-RT | bindings Dart de `gtfs-realtime.proto` (paquete de pub.dev o generados con `protoc`) | Decodificar en un `Isolate` |
| Widgets | `home_widget` + código nativo | Datos vía App Group (iOS) / SharedPreferences (Android) |
| Animaciones | `lottie` | Ver §11 |
| Segundo plano | `workmanager` (Android) + `BGTaskScheduler` (iOS) | |
| NFC (fase v2) | `nfc_manager` | Solo lectura |
| Deep links | `app_links` | |
| Modelos | `freezed` + `json_serializable` | |
| Errores/telemetría | Firebase Crashlytics **o** Sentry | Sin datos personales |
| Tests | `flutter_test`, `mocktail`, `integration_test` | |
| Calidad | `very_good_analysis` (lints) | |
| CI/CD | GitHub Actions (+ Fastlane o Codemagic para tiendas) | |

Regla: **no añadir dependencias sin justificarlo en el `design.md` del change.** Fijar versiones con `pubspec.lock` y revisar con `dart pub outdated` cada mes.

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

1. **Los horarios viven en el móvil, no en Postgres.** Un GTFS de `stop_times` puede ocupar cientos de MB y el plan Free da 500 MB de base de datos. Postgres solo guarda datos de usuario (perfil, viajes guardados, códigos de compartir). Un job nocturno genera un paquete SQLite compacto y lo publica en Storage (1 GB en Free; medir el tamaño real en la primera ejecución).
2. **El tiempo real se consulta directamente desde el móvil.** Las apps nativas no sufren CORS (el bucket S3 de CTB no envía cabeceras CORS, lo que solo afecta a navegadores). Si más adelante hay muchos usuarios, se interpone una Edge Function con caché de 10–15 s para no saturar a CTB.
3. **Modelo "teórico + corrección".** El widget muestra siempre el horario teórico local; si hay retraso conocido lo superpone. Así nunca queda vacío sin red.
4. **Arquitectura por capas:** `presentation` (widgets, controladores Riverpod) → `domain` (casos de uso, entidades) → `data` (repositorios, fuentes remotas/locales). Un *adapter* por operador que normaliza a un modelo común (`Stop`, `Route`, `Trip`, `Departure`, `Alert`).

---

## 5. Fuentes de datos: endpoints y cómo conseguirlos

Punto de entrada común: **CTB (Consorcio de Transportes de Bizkaia)** en `https://data.ctb.eus` (CKAN, licencia **CC BY 4.0**, contacto `datactb@cotrabi.eus`) y **Open Data Euskadi / Moveuskadi** en `https://opendata.euskadi.eus`. Casi todo es GTFS / GTFS-RT, así que basta **una** canalización para los cinco operadores. Ningún endpoint pide API key, salvo que se indique.

### 5.1 Metro Bilbao

| Qué | Endpoint | Estado |
|---|---|---|
| Catálogo de datasets | `GET https://cms.metrobilbao.eus/get/open_data/{lang}` (`es`, `eu`, `en`) — devuelve JSON con horarios, tarifas, estaciones, noticias, notas de prensa, avisos, memorias | [VERIFICADO] |
| Horarios GTFS (zip) | `GET https://cms.metrobilbao.eus/get/open_data/horarios/es` | [VERIFICADO] |
| Tarifas (CSV) | `GET https://cms.metrobilbao.eus/get/open_data/tickets/{lang}` — cabeceras: `_id, ticket_id, code, areas, price, age, periodicity, …` | [VERIFICADO] (la lista de columnas está truncada en la guía; descargar y leer la cabecera completa) |
| Estaciones (JSON) | `GET https://cms.metrobilbao.eus/get/open_data/json/estaciones/{lang}` con parámetros `fields=stop_id,stop_name,stop_lat,stop_lon`, `sort=stop_name`, `filter[stop_name][op]=like&filter[stop_name][value]=…`, `filter[bbox]=lon_min,lat_min,lon_max,lat_max`. Caché: `max-age=60` | [VERIFICADO] |
| Noticias / notas de prensa (JSON) | `GET …/get/open_data/json/noticias/{lang}` y `…/notas_prensa/{lang}` | [VERIFICADO] |
| Avisos | Figura en el catálogo (`avisos`); la ruta JSON `…/json/avisos/{lang}` devuelve 200 OK | [VERIFICADO] |
| Guía oficial de la API | `https://www.metrobilbao.eus/es/open-data/dataset/api-guide` | [VERIFICADO] |
| Tiempo real (protobuf, vía CTB) | `https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-vehicle-positions.pb` | [VERIFICADO] |
| | `…/metro-bilbao-trip-updates.pb` y `…/metro-bilbao-service-alerts.pb` (comprobados: 200 OK con payload GTFS-RT) | [VERIFICADO] |
| Ficha del dataset RT | `https://data.ctb.eus/dataset/metro-bilbao-online` | [VERIFICADO] |

**Particularidades (importantes):**
- El GTFS tiene **una sola ruta (`MB`) para L1 y L2**. La línea hay que **inferirla** por las estaciones que sirve el viaje: si toca alguna estación entre Lutxana y Plentzia → L1; entre Gurutzeta y Kabiezes → L2; los servicios cortos de tronco: L2 si van a/desde Basauri o Ariz, si no L1. (Algunos L1 nacen en Basauri: no clasificar solo por Basauri/Ariz.)
- Horas GTFS superiores a `24:00:00` (p. ej. `24:26:00`) pertenecen al día de servicio **anterior**. Toda consulta debe mirar el servicio de hoy **y** el de ayer, con la zona horaria `Europe/Madrid` (cuidado con los cambios de hora).
- Los `trip_id` del tiempo real coinciden con el GTFS estático; el retraso = `predicción − horario`. Descartar predicciones incoherentes (tiempos no crecientes a lo largo de la ruta). Los viajes con `schedule_relationship = CANCELED` se ocultan y las paradas `SKIPPED` se tachan.
- El feed de posiciones suele listar pocos trenes; **no son posiciones de señalización**, son estimaciones.

### 5.2 Bizkaibus (interurbano)

| Qué | Endpoint | Estado |
|---|---|---|
| Trip updates (GTFS-RT) | `https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedTripUpdates.pb` | [VERIFICADO] |
| Alertas (GTFS-RT) | `https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedAlerts.pb` | [VERIFICADO] |
| Posiciones (GTFS-RT) | `https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedVehiculos.pb` | [VERIFICADO] |
| SIRI (XML): alertas / posiciones / trip updates | `https://ctb-siri.s3.eu-south-2.amazonaws.com/bizkaibus-service-alerts.xml`, `…/bizkaibus-vehicle-positions.xml`, `…/bizkaibus-trip-updates.xml` | [VERIFICADO] (usar GTFS-RT; SIRI solo como respaldo) |
| Horarios GTFS / NeTEx | Dataset `https://data.ctb.eus/en/dataset/horarios-lineas-bizkaibus` (recurso `bizkaibus.zip`, licencia CC BY 4.0) | [VERIFICADO] la ficha; **copiar la URL directa del recurso desde la página** |
| Copia Moveuskadi (FTP) | `ftp://ftp.geo.euskadi.net/cartografia/Transporte/Moveuskadi/Bizkaibus/google_transit.zip` | [POR VERIFICAR] (dato de un repositorio de terceros; el FTP puede estar obsoleto) |

Bizkaibus es el operador con **trip updates** además de posiciones: es la mejor fuente de "en cuánto pasa mi bus".

### 5.3 Bilbobus (urbano de Bilbao)

| Qué | Endpoint | Estado |
|---|---|---|
| Horarios GTFS | Ficha: `https://opendata.euskadi.eus/catalogo/-/gtfs-informacion-autobuses-bilbobus/` (Ayuntamiento de Bilbao, actualización diaria) | [VERIFICADO] (copiar la URL del recurso ZIP desde la ficha) |
| Posiciones (GTFS-RT) | `https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/bilbobus-vehicle-positions.pb` | [VERIFICADO] |
| Ficha en el portal de Bilbao | `https://www.bilbao.eus/opendata/datos/bilbobus-gtfs-rt` | [VERIFICADO] |
| Trip updates / alertas | No localizados | [NO DISPONIBLE] — solo hay posiciones |

**Consecuencia de diseño:** para Bilbobus no hay predicción de llegada publicada. Mostrar horario teórico + posición del bus en mapa; opcionalmente estimar ETA (fase v1.x) con la distancia por trazado a la parada. Etiquetar en UI "horario teórico".

### 5.4 Euskotren (tren, tranvía, funicular, "línea 3" del metro)

| Qué | Endpoint | Estado |
|---|---|---|
| Horarios GTFS | Dataset `https://data.ctb.eus/es/dataset/horarios-servicios-euskotren` (recurso `Euskotren_gtfs.zip`) | [VERIFICADO] |
| Copia Moveuskadi | `ftp://ftp.geo.euskadi.net/cartografia/Transporte/Moveuskadi/Euskotren/google_transit.zip` | [POR VERIFICAR] |
| Tiempo real | No confirmado. Buscar en `https://data.ctb.eus/dataset/?tags=Tiempo+real` y preguntar a `datactb@cotrabi.eus` | [POR VERIFICAR] |

Un proyecto de terceros indica que la línea 3 del metro (Euskotren) tiene feeds en el mismo formato en `data.ctb.eus`, pero sin nombres de fichero verificados. **Tarea de investigación #1 antes de la v1.0.**

### 5.5 Renfe Cercanías Bilbao

| Qué | Endpoint | Estado |
|---|---|---|
| GTFS estático (Cercanías nacional) | `https://ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip` — filtrar el núcleo de Bilbao | [VERIFICADO] (lo usa un cliente de terceros activo) |
| Copia Moveuskadi | `ftp://ftp.geo.euskadi.net/cartografia/Transporte/Moveuskadi/Renfe/cercanias/google_transit.zip` | [POR VERIFICAR] |
| Tiempo real GTFS-RT | Raíz `https://gtfsrt.renfe.com/` (posiciones, trip updates, alertas). Nombres exactos de fichero de Cercanías | [POR VERIFICAR] — se sabe que existe `trip_updates_LD.json` para larga/media distancia; confirmar los `.pb` de Cercanías con una petición real |
| Portal alternativo | NAP (Punto de Acceso Nacional, `nap.transportes.gob.es`); en una consulta anterior se indicó que exigía iniciar sesión | [POR VERIFICAR] |

> **Corrección respecto a mi mensaje anterior:** dije que el GTFS-RT de Renfe en NAP exigía login y que no había confirmado más. Ahora hay evidencia de un servidor de tiempo real propio (`gtfsrt.renfe.com`) usado por clientes de terceros. Sigue pendiente confirmar el acceso libre y los nombres de fichero de Cercanías y sus condiciones de reutilización.

### 5.6 Moveuskadi (Gobierno Vasco) — respaldo y cobertura de terceros

Conjunto de datos `Moveuskadi. Datos de la red de transporte público de Euskadi` en Open Data Euskadi: datos **estáticos y en tiempo real** de metro, tranvía, autobuses urbanos e interurbanos, trenes autonómicos, cercanías, funiculares y puente colgante. Sirve como (a) respaldo si un feed de CTB cae y (b) fuente de operadores menores (Puente Bizkaia, Funicular de Artxanda, La Unión, urbanos de Barakaldo/Leioa/Erandio/Sopela/Etxebarri/Bermeo…). En CTB existen datasets de tiempo real separados para varios de ellos (La Unión, Bermibusa, Erandiobusa, Kbus…).

URL: `https://opendata.euskadi.eus/catalogo/-/moveuskadi-datos-de-la-red-de-transporte-publico-de-euskadi-operadores-horarios-paradas-calendario-tarifas-etc/`

### 5.7 Tarifas y zonas

- Metro: CSV de tarifas (§5.1) con precio, zonas (`areas`), tipo de billete y edad.
- Sistema Barik / CTB (zonal, común a Metro, Euskotren, Bizkaibus, Bilbobus, Kbus, Lejoan Busa, Sopelbus, Galdabusa y funiculares): consultar `https://www.ctb.eus/es/como-funciona-barik`. No se ha localizado un dataset abierto de tarifas del sistema completo → **para v1 solo se calcula el coste en Metro**; el resto, "tarifa no disponible" o tabla manual mantenida en el repo con fecha de vigencia.

### 5.8 Licencias y atribución

- CTB, Bizkaibus, Euskotren y Bilbobus: **CC BY 4.0** → mostrar atribución ("Datos: Consorcio de Transportes de Bizkaia / Metro Bilbao / Ayuntamiento de Bilbao / Gobierno Vasco…") en *Ajustes → Acerca de*.
- Metro Bilbao y Renfe: **revisar términos de reutilización antes de publicar en tiendas.** No usar logotipos de operadores sin permiso (un proyecto de terceros indica que el logo de Metro Bilbao no está bajo licencia libre).
- Guardar en el repo `docs/licencias-datos.md` con la fecha y la URL de cada aviso legal consultado.

### 5.9 Verificación previa obligatoria (tarea T0)

Script `tools/verify_feeds.sh` que, para cada URL de §5, comprueba: código HTTP, `Content-Type`, tamaño, cabecera `Last-Modified`/`ETag`, y decodifica los `.pb` mostrando `header.timestamp` y nº de entidades. Debe ejecutarse en CI semanalmente y abrir un issue si algo cambia. Ninguna URL "por verificar" pasa a código de producción sin este chequeo.

---

## 6. Modelo de datos (Supabase / Postgres)

Solo datos del usuario. Todo con **RLS activado**.

```sql
-- Perfil (1:1 con auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (char_length(display_name) <= 60),
  created_at timestamptz not null default now()
);

-- Viajes guardados
create table public.saved_trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  operator text not null check (operator in
    ('metro','bizkaibus','bilbobus','euskotren','renfe')),
  origin_stop_id text not null,
  dest_stop_id text not null,
  route_id text,                 -- opcional: línea preferida
  direction_id smallint check (direction_id in (0,1)),
  widget_enabled boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index on public.saved_trips (user_id, sort_order);

-- Códigos para compartir
create table public.trip_shares (
  code text primary key check (code ~ '^[A-Z2-9]{8}$'),
  trip_id uuid not null references public.saved_trips(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now()
);

-- Ajustes (saldo Barik manual, idioma, unidades)
create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  barik_balance_cents int check (barik_balance_cents >= 0),
  barik_balance_updated_at timestamptz,
  language text default 'es' check (language in ('es','eu','en'))
);

alter table public.profiles       enable row level security;
alter table public.saved_trips    enable row level security;
alter table public.trip_shares    enable row level security;
alter table public.user_settings  enable row level security;

create policy "own profile"  on public.profiles      for all using (id = auth.uid())      with check (id = auth.uid());
create policy "own trips"    on public.saved_trips   for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own shares"   on public.trip_shares   for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "own settings" on public.user_settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());
```

**Canjear un código de compartir** NO se hace leyendo `trip_shares` desde el cliente (RLS lo impide y expondría datos). Se hace con una función `security definer` que devuelve solo los campos del viaje y no el `user_id`:

```sql
create or replace function public.redeem_trip_share(p_code text)
returns table (name text, operator text, origin_stop_id text,
               dest_stop_id text, route_id text, direction_id smallint)
language sql security definer set search_path = public as $$
  select t.name, t.operator, t.origin_stop_id, t.dest_stop_id, t.route_id, t.direction_id
  from trip_shares s join saved_trips t on t.id = s.trip_id
  where s.code = upper(p_code) and s.expires_at > now();
$$;
revoke all on function public.redeem_trip_share(text) from public;
grant execute on function public.redeem_trip_share(text) to authenticated;
```

El receptor obtiene una **copia** (no un enlace vivo) que inserta en sus propios `saved_trips`. Limitar la tasa de canje (5/min por usuario) para evitar fuerza bruta de códigos: espacio de 32^8 ≈ 10^12, suficiente junto con expiración y límite.

Migraciones: `supabase/migrations/*.sql` versionadas en git, aplicadas con Supabase CLI (`supabase db push`), nunca editando a mano en el panel de producción.

---

## 7. Autenticación (Google) y requisitos de tiendas

**Flujo:** `google_sign_in` obtiene `idToken` → `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: …, accessToken: …)`.

Configuración necesaria:
1. Google Cloud Console → pantalla de consentimiento OAuth (externa) y **tres** IDs de cliente: Web (el que se pega en Supabase), Android (con SHA-1 de debug **y** de la clave de subida/Play App Signing) e iOS.
2. Supabase → Authentication → Providers → Google: Client ID (web) y secret; activar la opción de comprobación de nonce si se usa iOS.
3. iOS: `GIDClientID` y URL scheme invertido en `Info.plist`.

**Requisitos de tiendas a prever desde el diseño:**
- **Apple, guideline 4.8 (Login Services):** si se ofrece login con un tercero (Google), normalmente se exige ofrecer también una alternativa equivalente que proteja la privacidad, como *Sign in with Apple*. **Verificar el texto vigente de la guideline antes de enviar; planificar `sign_in_with_apple` por defecto.**
- **Eliminación de cuenta dentro de la app:** exigida por Apple y por Google Play. Implementar una Edge Function (con `service_role`, solo en servidor) que borre el usuario en `auth.users`; el `on delete cascade` limpia el resto.
- **Google Play:** formulario *Data safety*; **Apple:** *Privacy nutrition labels* y `PrivacyInfo.xcprivacy`.
- **Política de privacidad y términos** públicos (URL) — obligatorios en ambas tiendas.
- **RGPD:** datos personales mínimos (email y nombre de Google), base legal = ejecución del servicio, derecho de acceso/supresión, región del proyecto Supabase en la UE (`eu-*`).
- Cuenta de desarrollador: Google Play (pago único, 25 USD) y Apple Developer Program (99 USD/año) — [POR VERIFICAR importes vigentes].

---

## 8. Saldo de la Barik

**Hechos verificados**
- La app oficial "Barik NFC" (hoy sustituida por "App Barik") del CTB consulta el contenido de **cualquier tarjeta Barik** al acercarla, incluye los últimos 30 movimientos, y funciona en Android e iOS con NFC.
- No se ha localizado documentación pública del formato de datos de la tarjeta ni una API de saldo.

**Decisión por fases**
1. **v1.0 — saldo manual.** El usuario introduce su saldo (`user_settings.barik_balance_cents`). La app calcula "¿me llega?" con la tarifa del Metro (§5.1). Mostrar la fecha de la última actualización y avisar de que puede estar desfasado.
2. **v2 — lectura NFC solo si pasa esta puerta:** (a) identificar la tecnología de la tarjeta con una lectura de solo metadatos (ATQA/SAK/historic bytes) usando una tarjeta propia; (b) confirmar por escrito con el CTB (`datactb@cotrabi.eus` / atención al cliente) que la lectura de saldo por terceros es aceptable; (c) revisar el riesgo legal de la ingeniería inversa (propiedad intelectual, cláusulas de la tarjeta) con asesoría profesional; (d) si las claves de acceso no son públicas, **no implementar**.
3. **Alternativa legítima:** botón "Abrir App Barik" (deep link/tienda) para que el usuario consulte el saldo con la app oficial y lo copie a mano.

**iOS:** leer NFC requiere entitlement *Near Field Communication Tag Reading* y capacidad de lectura del tipo de tarjeta; algunas tecnologías no son legibles con CoreNFC. Android: permiso `android.permission.NFC` y `nfc_manager`. Ninguno de los dos se activa hasta la fase v2.

**Nunca:** escribir en la tarjeta, recargar, guardar el UID de la tarjeta en el servidor sin consentimiento explícito.

---

## 9. Infraestructura y costes (Supabase Free)

Límites del plan Free **[VERIFICADO en la página de precios y en comparativas de 2026]**: 50.000 usuarios activos mensuales (MAU), base de datos de 500 MB, 1 GB de almacenamiento, 5 GB de egress, hasta 2 proyectos activos, 500.000 invocaciones de Edge Functions, y **proyectos pausados tras 1 semana de inactividad**; sin copias de seguridad diarias ni SLA. Pro cuesta 25 USD/mes.

Aclaración a tu duda inicial: los "50.000" son **usuarios activos al mes**, no registros. Con solo datos de usuario (tablas de §6) el límite de 500 MB no será tu problema; los límites reales serán la **pausa por inactividad** y la **ausencia de backups**.

**Mitigaciones**
- **Keep-alive:** workflow de GitHub Actions cada 2–3 días que hace un `GET` autenticado con la clave `anon` a la REST API (`/rest/v1/profiles?select=id&limit=1`). Nota: GitHub desactiva los workflows programados de repos públicos tras 60 días sin actividad; añadir un commit automático mensual o usar un servicio de cron externo como segundo respaldo. Un `pg_cron` interno **no** cuenta como actividad externa fiable.
- **Backups propios:** `pg_dump` semanal desde Actions a un almacenamiento privado (cifrado) — los datos de usuario son pequeños.
- **Umbral de paso a Pro:** cuando la app tenga usuarios reales que dependan de ella a diario (la pausa sería un fallo de servicio), o al acercarse a 40.000 MAU / 400 MB.
- **La app debe degradar bien:** si Supabase no responde, el widget y los horarios siguen funcionando (datos locales); los viajes guardados se cachean en local.

**Entornos:** `dev` (proyecto Supabase local con Docker vía `supabase start`), `staging` (opcional; recuerda el límite de 2 proyectos activos) y `prod`.

**Secretos:** nunca en el repo. Claves `anon` y URL en `--dart-define-from-file=env/prod.json` (el fichero, en `.gitignore`); `service_role` solo en GitHub Secrets y Edge Functions.

**Pipeline nocturno de datos (`.github/workflows/build-gtfs.yml`)**
1. Descargar los ZIP de §5 con `If-Modified-Since`.
2. Validar (MobilityData GTFS Validator) y fallar si hay errores graves.
3. Filtrar a Bizkaia, eliminar columnas no usadas, calcular `route_id → línea real` (regla L1/L2 de §5.1).
4. Generar `transit.sqlite` (+ versión comprimida) y `manifest.json` `{version, sha256, bytes, generated_at, sources:{…}}`.
5. Publicar en Supabase Storage (bucket público de solo lectura).
6. La app comprueba `manifest.json` al abrir y descarga el delta/paquete completo solo si cambió el `sha256`.

---

## 10. Widgets (Android e iOS)

**Principio:** un widget no ejecuta Dart de forma fiable. La app **precalcula** y guarda en almacenamiento compartido las próximas *N* salidas (p. ej. 12 h) de cada viaje con `widget_enabled`, y el widget nativo solo pinta esos datos según la hora actual.

- **Datos compartidos:** `home_widget` → `SharedPreferences` (Android) / `UserDefaults(suiteName:)` con **App Group** (iOS). JSON versionado: `{v:1, generated_at, trips:[{id, name, from, to, line, departures:[{sched, rt_delay_s?}]}]}`.
- **Android:** `AppWidgetProvider` (RemoteViews o Jetpack Glance), tamaños 2×1 y 4×2, `updatePeriodMillis` respetando el mínimo del sistema, más `WorkManager` periódico (mínimo 15 min) para refrescar el tiempo real. Al tocar → deep link al detalle del viaje.
- **iOS:** extensión **WidgetKit** en SwiftUI. Un `TimelineProvider` con una **entrada por cada salida** (la hora avanza sin consumir presupuesto de refresco) y `Timeline(policy: .after(...))`. Tamaños `systemSmall`/`systemMedium`, más Lock Screen (`accessoryRectangular`). iOS limita la frecuencia de recarga: el retraso en tiempo real es *best-effort*; se marca "horario teórico" si el dato tiene más de 5 min.
- **Estados obligatorios:** sin viajes guardados, sin sesión, datos caducados, servicio interrumpido (alerta activa).
- **Accesibilidad:** contraste AA, tamaños dinámicos, etiquetas para lector de pantalla ("Próximo metro a Kabiezes en 4 minutos").

---

## 11. Animaciones con Lottie

- Paquete `lottie`. Animaciones en `assets/lottie/*.json` (ligeras, < 50 KB cada una; preferir `.lottie` comprimido si el paquete lo soporta en la versión fijada).
- **Uso sobrio** — dan vida, no ralentizan:
  | Momento | Animación |
  |---|---|
  | Splash / carga inicial de horarios | Vagón de metro entrando en estación |
  | Cargando salidas | Puntos/línea de ruta pulsando |
  | Estado vacío (sin viajes guardados) | Andén vacío con reloj |
  | Guardar viaje | Check con estrella (una sola reproducción) |
  | Sin conexión | Cable desconectado |
  | Incidencia/alerta | Icono de aviso con leve rebote |
  | Login correcto | Confeti mínimo |
- **Reglas técnicas:** un `AnimationController` por pantalla (no por elemento), `repeat: false` salvo cargas, pre-cachear con `LottieBuilder.asset` + `frameRate: FrameRate.composition`, envolver en `RepaintBoundary`, no animar listas largas.
- **Accesibilidad:** si `MediaQuery.disableAnimationsOf(context)` es `true` → mostrar el primer o último fotograma estático.
- **Licencias:** usar solo animaciones propias o de LottieFiles con licencia que permita uso comercial; guardar la atribución y la licencia de cada archivo en `assets/lottie/LICENSES.md`.
- **Widgets nativos** (§10) no usan Lottie.

---

## 12. Capacidades (formato OpenSpec)

Cada bloque siguiente va a `openspec/specs/<capacidad>/spec.md`.

### Capacidad: `auth`

### Requirement: Inicio de sesión con Google
The system SHALL allow a user to sign in or create an account using their Google account, with no password.

#### Scenario: Primer inicio de sesión
- **WHEN** a new user completes Google sign-in
- **THEN** a session is created and a row in `profiles` exists for that user

#### Scenario: Cancelación
- **WHEN** the user dismisses the Google dialog
- **THEN** the app stays on the login screen without an error dialog

### Requirement: Alternativa Sign in with Apple en iOS
The system SHALL offer Sign in with Apple on iOS wherever Google sign-in is offered, unless store policy verification concludes it is not required.

### Requirement: Eliminación de cuenta
The system SHALL let the user delete their account and all associated data from within the app.

#### Scenario: Borrado confirmado
- **WHEN** the user confirms deletion
- **THEN** the auth user, profile, saved trips, shares and settings are removed and the session is closed

### Capacidad: `transit-data`

### Requirement: Datos de horarios offline
The system SHALL keep the latest downloaded schedule pack locally and use it when there is no network.

#### Scenario: Sin conexión
- **WHEN** the device is offline
- **THEN** next departures are computed from the local schedule and labelled "horario teórico"

### Requirement: Día de servicio correcto
The system SHALL resolve departures using the service day rules of GTFS, including times beyond 24:00:00 and Europe/Madrid time.

#### Scenario: Madrugada
- **WHEN** the current time is 00:26 and a trip is scheduled at 24:26:00 of the previous service day
- **THEN** that trip is included as an upcoming departure

### Requirement: Clasificación L1/L2 de Metro Bilbao
The system SHALL derive the metro line of each trip from the stations it serves, since the source feed has a single route.

### Requirement: Atribución de datos
The system SHALL display the data attributions required by each source's licence in Settings → About.

### Capacidad: `realtime`

### Requirement: Retrasos en tiempo real
The system SHALL overlay real-time delays from GTFS-RT trip updates on scheduled departures when the feed is fresh (timestamp < 2 minutes for buses, < 1 minute for metro).

#### Scenario: Feed caído
- **WHEN** a real-time feed returns an error or stale data
- **THEN** scheduled times are shown with a "sin tiempo real" indicator and no crash occurs

### Requirement: Viajes cancelados y paradas omitidas
The system SHALL hide canceled trips and mark skipped stops.

### Capacidad: `saved-trips`

### Requirement: Guardar un viaje
The system SHALL let an authenticated user save a trip defined by operator, origin stop and destination stop, with a name.

#### Scenario: Guardar Bagatza → Kabiezes
- **WHEN** the user saves origin "Bagatza" and destination "Kabiezes" on Metro Bilbao
- **THEN** the trip appears in "Mis viajes" and, if enabled, in the widget

### Requirement: Sincronización y caché local
The system SHALL cache saved trips locally and sync them with the backend when online.

### Requirement: Aislamiento de datos
The system SHALL ensure each user can only read and modify their own saved trips (enforced by row-level security).

### Capacidad: `widget`

### Requirement: Widget de próximas salidas
The system SHALL provide a home-screen widget on Android and iOS that shows the next departures of the user's saved trips without opening the app.

#### Scenario: Widget con dos viajes
- **WHEN** the user has two trips with widget enabled
- **THEN** the widget shows both with their next departure time and remaining minutes

### Requirement: Funcionamiento sin abrir la app
The system SHALL keep the widget correct for at least 12 hours without the app being opened.

### Requirement: Estados de error del widget
The system SHALL show explicit states for no trips, signed-out, stale data and active service disruption.

### Capacidad: `trip-planner`

### Requirement: Sugerir líneas para un origen y destino
The system SHALL, given an origin and a destination, list the transit options (operator, line, next departures) that connect them.

#### Scenario: Barakaldo → Mungia
- **WHEN** the user searches from a stop in Barakaldo to a stop in Mungia
- **THEN** the app lists direct options if any exist, otherwise options with transfers (from v1.x), each with duration and next departure

### Requirement: Búsqueda de paradas
The system SHALL search stops by name (accent- and case-insensitive, Spanish and Basque names) and by proximity.

### Capacidad: `alerts`

### Requirement: Incidencias unificadas
The system SHALL show current service alerts from all operators, filterable by operator and by the user's saved trips.

#### Scenario: Alerta en un viaje guardado
- **WHEN** an active alert affects a line or stop used by a saved trip
- **THEN** the trip card and its widget show an alert indicator

### Capacidad: `sharing`

### Requirement: Compartir un viaje por código
The system SHALL let a user generate a short-lived code for a saved trip, and another user redeem it to get their own copy.

#### Scenario: Código caducado
- **WHEN** a user redeems a code older than its expiry
- **THEN** the app shows "código caducado" and creates nothing

### Requirement: Privacidad al compartir
The system SHALL NOT reveal the owner's identity or email to the person redeeming the code.

### Capacidad: `barik-balance`

### Requirement: Saldo manual
The system SHALL let the user enter their Barik balance manually and show its last-update date.

### Requirement: ¿Me llega el saldo?
The system SHALL show whether the stored balance covers a trip's fare when the fare is available from Metro Bilbao tariff data.

#### Scenario: Saldo insuficiente
- **WHEN** balance is 0,90 € and the fare is 1,80 €
- **THEN** the app shows the shortfall and does not claim certainty about real-time card contents

### Requirement: Lectura NFC (fase v2, condicionada)
The system SHALL read the Barik balance via NFC only after the legal and technical gate in section 8 has been passed.

### Capacidad: `ui-navigation`

### Requirement: Navegación por transporte
The system SHALL organise screens by transport mode (Metro, Bizkaibus, Bilbobus, Euskotren, Renfe) with a consistent structure: departures, lines, stops, alerts.

### Requirement: Idiomas
The system SHALL support Spanish, Basque and English, defaulting to the device language.

### Requirement: Animaciones respetuosas
The system SHALL disable non-essential animations when the OS "reduce motion" setting is on.

---

## 13. Convenciones del proyecto (skills / guías para el agente)

Esta sección es el "skill pack" que el asistente de IA debe respetar en todo change.

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
- `.gitignore`: `env/*.json`, `*.jks`, `key.properties`, `GoogleService-Info.plist` si contiene claves privadas, `.dart_tool/`, builds.
- Pre-commit: `gitleaks` (secretos), `dart format`, `dart analyze`. Nunca `git push --force` sobre `main`.
- Etiquetas de release `vX.Y.Z` disparan el build de tiendas.

### 13.3 Animaciones
- Ver §11. Toda animación nueva pasa por: ¿aporta información o feedback?, ¿< 50 KB?, ¿respeta *reduce motion*?, ¿licencia registrada?
- Duraciones: micro-interacciones 150–300 ms, transiciones de pantalla ≤ 400 ms; curvas `Curves.easeOutCubic`.

### 13.4 Supabase
- Todo cambio de esquema = migración SQL versionada. Prohibido el `service_role` en la app.
- RLS **habilitado en toda tabla** y probado con tests (`supabase test db` / pgTAP): un usuario A no puede leer ni modificar datos del usuario B.
- Funciones `security definer` con `set search_path = public` y `revoke … from public`.
- Consultas con `select` explícito de columnas y `limit`; índices en columnas de filtro.
- Edge Functions: validar entrada (Zod/Valibot), CORS restrictivo, límites de tasa, sin logs de datos personales.
- Realtime de Supabase **no se usa** para transporte (el tiempo real viene de los feeds); evita consumir conexiones del plan Free.

### 13.5 Ciberseguridad y buenas prácticas
- Referencia: **OWASP MASVS/MASTG** para móvil y OWASP Top 10 para APIs.
- Solo HTTPS (ATS en iOS, `usesCleartextTraffic=false` en Android). Considerar *certificate pinning* únicamente para Supabase y con plan de rotación (riesgo de bloquear la app).
- Tokens de sesión en almacenamiento seguro (Keychain / EncryptedSharedPreferences) — `supabase_flutter` con `flutter_secure_storage` como almacén local.
- Ofuscación de release: `flutter build … --obfuscate --split-debug-info=…` y R8/ProGuard en Android. Subir símbolos a Crashlytics/Sentry.
- Sin datos sensibles en logs. Sin analytics con identificadores personales; si se añade analítica, con consentimiento.
- Validar y **limitar** todo dato externo: los feeds GTFS/GTFS-RT son entrada no confiable (tamaño máximo de descarga, timeouts, límite de entidades, manejo de protobuf corrupto).
- Sin WebViews con contenido remoto salvo necesidad; si las hay, lista blanca de dominios.
- Dependencias: Dependabot + `dart pub outdated` mensual; revisar licencias.
- Widgets/App Group: no guardar tokens en el contenedor compartido, solo datos de horarios.
- Deep links: validar el esquema y los parámetros (nunca ejecutar acciones destructivas por un enlace).
- Respuesta a incidentes: `SECURITY.md` con contacto; procedimiento de rotación de claves de Supabase y Google.

### 13.6 Idioma del código y documentación
- Código, identificadores y commits en **inglés**; UI y documentación de usuario en es/eu/en; documentación interna del proyecto en español.

---

## 14. Calidad, observabilidad y rendimiento

- **Rendimiento:** arranque en frío < 2 s en gama media; consulta "próximas salidas" < 100 ms sobre SQLite indexado (`stop_id`, `service_id`, `departure_time`).
- **Batería:** refrescos en segundo plano mínimos; el widget usa horario local.
- **Crashes y errores:** Crashlytics o Sentry; *breadcrumbs* sin datos personales.
- **Salud de feeds:** panel/log en CI con la disponibilidad y frescura de cada feed (§5.9). Mostrar en la app un estado "tiempo real no disponible para X".
- **Pruebas manuales antes de release:** cambio de hora (marzo/octubre), festivos, madrugada, modo avión, batería baja, tamaños de fuente grandes, TalkBack/VoiceOver.

---

## 15. Publicación en tiendas (lista de comprobación)

- [ ] Nombre y marca sin infringir las de los operadores; sin logos ajenos.
- [ ] Iconos, capturas (móvil y tablet), descripción en es/eu/en.
- [ ] Política de privacidad y términos publicados.
- [ ] Google Play: *Data safety*, clasificación de contenido, prueba cerrada (según requisitos vigentes para cuentas nuevas), *Play App Signing*.
- [ ] Apple: cuenta de desarrollador, `PrivacyInfo.xcprivacy`, App Group y entitlement del widget, Sign in with Apple, cuenta demo para revisión.
- [ ] Eliminación de cuenta accesible en la app.
- [ ] Atribuciones de datos en *Acerca de*.
- [ ] Disclaimer: "App no oficial; no está afiliada a los operadores. Los horarios pueden variar."

---

## 16. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Feed de tiempo real cae o cambia de URL | Sin retrasos | Fallback a horario teórico; verificación semanal (§5.9); respaldo Moveuskadi |
| Bilbobus sin trip updates | Sin "en X min" real | Etiqueta "teórico"; ETA estimado en v1.x |
| Renfe/Euskotren RT no abiertos | Cobertura parcial | Lanzar con lo verificado; documentar en la UI qué operadores tienen tiempo real |
| Pausa de Supabase Free | App de cuentas inaccesible | Keep-alive doble + datos locales + plan de paso a Pro |
| Rechazo de Apple por login | Retraso de lanzamiento | Incluir Sign in with Apple desde el inicio |
| Restricciones de widgets iOS | Retraso desactualizado | Timeline precalculada, etiquetado de frescura |
| Lectura NFC de Barik | Legal/técnico | Puerta de decisión en §8; saldo manual mientras tanto |
| Cambios de licencia/datos | Retirada de datos | Revisar avisos legales; contacto con CTB; guardar copia de términos |
| Tamaño del paquete GTFS | Descarga lenta | Compactar, comprimir, delta por operador; medir en primer build |
| Cambios de GTFS (IDs de parada) | Viajes guardados rotos | Guardar también el nombre de la parada y reconciliar por nombre+coordenadas |

---

## 17. Preguntas abiertas / tareas de investigación

1. **T0:** ejecutar `verify_feeds.sh` y completar la columna "estado" de §5 (Renfe RT, Euskotren RT, `metro-bilbao-trip-updates.pb`, avisos de Metro).
2. Confirmar con `datactb@cotrabi.eus`: nombres y condiciones de los feeds de Euskotren y Renfe; si hay datos de tarifas del sistema Barik completo.
3. Confirmar los términos de reutilización de Metro Bilbao y Renfe para apps comerciales/gratuitas en tiendas.
4. Decidir el nombre de la app (comprobar marca y disponibilidad en tiendas).
5. Decidir si el planificador con transbordos se implementa con un algoritmo propio (RAPTOR/CSA sobre SQLite) o con un servicio externo (OpenTripPlanner autoalojado tiene coste de servidor).
6. Decidir el dominio para enlaces universales / política de privacidad (un dominio propio es necesario para *App Links / Universal Links*).
7. ¿Modelo de negocio? (gratuita, donaciones, Pro). Ojo: las tiendas y algunos términos de datos limitan ciertos usos comerciales.
8. Comprobar si hay que permitir uso sin cuenta (viajes guardados solo locales) para reducir fricción y MAU.

---

## 18. Estructura de repositorio propuesta

```
/
├─ lib/
│  ├─ core/           (config, errores, tiempo, red)
│  ├─ data/           (adapters por operador, gtfs/, realtime/, supabase/)
│  ├─ domain/         (entidades, casos de uso)
│  ├─ presentation/   (pantallas por transporte, widgets, tema, lottie)
│  └─ l10n/
├─ android/app/src/main/kotlin/…/widget/
├─ ios/TransitWidget/          (extensión WidgetKit)
├─ assets/lottie/ (+ LICENSES.md)
├─ supabase/{migrations,functions,tests}/
├─ tools/{verify_feeds.sh,build_gtfs/}
├─ openspec/{specs,changes,…}
├─ docs/{licencias-datos.md,arquitectura.md}
├─ .github/workflows/{ci.yml,build-gtfs.yml,keepalive.yml,release.yml}
├─ env/*.example.json
├─ SECURITY.md  CHANGELOG.md  README.md  spec.md
```

---

## 19. Primeros changes de OpenSpec sugeridos (orden)

1. `bootstrap-project` — repo, lints, CI, entornos, estructura.
2. `verify-data-feeds` — script T0 y `docs/licencias-datos.md`.
3. `gtfs-pipeline` — job nocturno → SQLite → Storage → manifest.
4. `metro-departures` — adapter Metro + clasificación L1/L2 + pantalla de salidas.
5. `auth-google` (+ `auth-apple`, `account-deletion`).
6. `saved-trips` — modelo, RLS, sincronización.
7. `widget-android` y `widget-ios`.
8. `realtime-overlay` — retrasos CTB para Metro.
9. `lottie-foundation` — animaciones base y accesibilidad.
10. `bizkaibus-adapter`, `bilbobus-adapter`, `euskotren-adapter`, `renfe-adapter`.
11. `alerts-unified`, `sharing-codes`, `barik-manual-balance`, `trip-planner-direct`.

---

*Fuentes principales consultadas: guía de la API de Metro Bilbao; portal de datos abiertos del CTB (data.ctb.eus); Open Data Euskadi / Moveuskadi; fichas de Bilbobus en Open Data Euskadi y bilbao.eus; documentación y repositorio de OpenSpec (Fission-AI); páginas de precios de Supabase y comparativas de 2026; ficha de la app Barik NFC (CTB, App Store y Google Play); repositorios de terceros que consumen los feeds de CTB y Renfe.*
