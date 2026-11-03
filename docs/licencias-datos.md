# Auditoría de Licencias de Datos y Atribución Legal

> Documento vivo de cumplimiento legal para el proyecto **Bizkaia Transit / Moveuskadi Platform** conforme a la directiva técnica estricta.
> Fecha de revisión: Noviembre de 2026.

---

## 1. Resumen de Licencias y Catálogo Oficial por Fuente

| Fuente / Catálogo | Endpoint / Portal | Formatos | Frecuencia Refresco | Licencia Declarada | Atribución Requerida | Límites / Restricciones |
|---|---|---|---|:---:|:---:|---|
| **Moveuskadi (Gobierno Vasco)** | `https://opendata.euskadi.eus/transport/moveuskadi/data-index.json` | JSON Index (35 operadores, 195 recursos) | Dinámico (cada 15 min) | **CC BY 4.0** | Sí | Reutilización comercial permitida; no scrapings abusivos |
| **Moveuskadi GTFS Static** | `opendata.euskadi.eus/transport/moveuskadi/*/gtfs_*.zip` | GTFS Static ZIP (35 feeds) | Semanal / Mensual | **CC BY 4.0** | Sí | Descargas condicionales HTTP ETag/Last-Modified |
| **Moveuskadi GTFS-RT** | `opendata.euskadi.eus/transport/moveuskadi/*/*.pb` | Protocol Buffers (66 feeds) | 15s - 60s | **CC BY 4.0** | Sí | Caché en aislamiento de backend; no DDOS |
| **Moveuskadi SIRI XML** | `opendata.euskadi.eus/transport/moveuskadi/*/*.xml` | SIRI XML (64 feeds) | 30s - 120s | **CC BY 4.0** | Sí | Parseo seguro con defusedxml |
| **Moveuskadi NeTEx** | `opendata.euskadi.eus/transport/moveuskadi/*/netex_*.zip` | NeTEx XML ZIP (30 feeds) | Periódica | **CC BY 4.0** | Sí | Extracción segura Zip-Slip protected |
| **GeoEuskadi Límites Territoriales** | `https://www.geo.euskadi.eus/cartografia/DatosDescarga/Limites/TERRITORIOS_5000_ETRS89.zip` | ESRI Shapefile (EPSG:25830) | Anual | **CC BY 4.0** | Sí | Transformación estricta a WGS84 EPSG:4326 |
| **Consorcio de Transportes de Bizkaia (CTB)** | `data.ctb.eus` | GTFS / REST | Semanal / Tiempo real | **CC BY 4.0** | Sí | Prohibido el uso de logotipos sin autorización |
| **Metro Bilbao** | `metrobilbao.eus` / Moveuskadi | GTFS / GTFS-RT | Semanal / 30s RT | Reutilización abierta | Sí | **Logo protegido:** isotipo no utilizable en apps comerciales |
| **Renfe Cercanías** | `data.renfe.com` / Moveuskadi | GTFS | Mensual | Reutilización sector público (Ley 37/2007) | Sí | Marcas registradas Renfe / Cercanías protegidas |

### 1.1 Fuentes en tiempo real usadas por la app (verificadas el 3 nov 2026)

Todas se consumen a través del proxy `tools/vehicle-proxy`. El proxy guarda cada respuesta en la CDN (20 s para vehículos y salidas, 60 s para incidencias), así que a cada fuente le llegan como mucho unas 3 peticiones por minuto, haya los usuarios que haya. La atribución se muestra en la app: en la hoja del vehículo, en la explicación del directo y en Incidencias.

| Fuente | URL | Formato | Refresco observado | Uso en la app | Licencia |
|---|---|---|---|---|---|
| Metro Bilbao · posiciones | `ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-vehicle-positions.pb` | GTFS-RT | ~60 s | Mapa (tren por estación) | CC BY 4.0 (CTB) |
| Metro Bilbao · previsiones | `…/metro-bilbao-trip-updates.pb` | GTFS-RT | ~30–60 s | Salidas en directo | CC BY 4.0 (CTB) |
| Metro Bilbao · incidencias | `…/metro-bilbao-service-alerts.pb` | GTFS-RT | ~60 s | Incidencias | CC BY 4.0 (CTB) |
| Bizkaibus · posiciones | `baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedVehiculos.pb` | GTFS-RT | 60–70 s (datos con ~80 s de retraso) | Mapa (GPS) | CC BY 4.0 |
| Bizkaibus · incidencias | `…/FeedAlerts.pb` | GTFS-RT | ~5 min | Incidencias | CC BY 4.0 |
| Euskotren y tranvías · previsiones | `opendata.euskadi.eus/transport/moveuskadi/euskotren/gtfsrt_euskotren_trip_updates.pb` | GTFS-RT | 2–4 min | Salidas (en directo solo si el tren ha salido o trae retraso) | CC BY (Moveuskadi) |
| Euskotren · incidencias | `…/gtfsrt_euskotren_alerts.pb` | GTFS-RT | — (vacío el 3 nov) | Incidencias | CC BY (Moveuskadi) |
| Renfe Cercanías · posiciones | `gtfsrt.renfe.com/vehicle_positions.pb` | GTFS-RT | 15–20 s | Mapa (por estación, filtrado a Bizkaia) | CC BY 4.0 (data.renfe.com) |
| Renfe Cercanías · incidencias | `gtfsrt.renfe.com/alerts.pb` | GTFS-RT | Desactualizado (~27 días el 3 nov) | Se descarta si tiene más de 6 h | CC BY 4.0 |

Quedan fuera:
- **Bilbobus:** todos sus feeds en tiempo real están vacíos, y CTB lista sus posiciones como **CC BY-NC 4.0** (no comercial): habría que revisarlo antes de usarlas.
- **Renfe · previsiones:** solo da la próxima parada de cada tren, que no basta para listar las salidas de una estación. Hace falta su GTFS estático (parte II del spec).

Índice oficial de feeds: `opendata.euskadi.eus/transport/moveuskadi/data-index-gtfs-rt.json`.

---

## 2. Textos Obligatorios de Atribución (Ajustes → Acerca de)

La aplicación móvil incluye en la pantalla de información legal y créditos (*Ajustes → Acerca de*) las siguientes menciones obligatorias en español, euskera e inglés:

### Español
> **Fuentes de datos:**
> - Datos de red, horarios, tiempo real y paradas facilitados a través de **Moveuskadi** y **Open Data Euskadi** (Gobierno Vasco), bajo licencia [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
> - Límites administrativos oficiales facilitados por la Infraestructura de Datos Espaciales de Euskadi (**geoEuskadi**).
> - Datos abiertos del **Consorcio de Transportes de Bizkaia (CTB)**, **Metro Bilbao S.A.**, **Bizkaibus** (Diputación Foral de Bizkaia), **Bilbobus** (Ayuntamiento de Bilbao), **Euskotren** (Eusko Trenbideak), **Dbus** (CTSS Donostia), **TUVISA** (Ayuntamiento de Vitoria-Gasteiz), **Álavabus** (Diputación Foral de Álava) y **Lurraldebus** (Diputación Foral de Gipuzkoa).
> - Horarios de Cercanías facilitados por **Renfe Viajeros / Ministerio de Transportes y Movilidad Sostenible**.
>
> **Aviso de responsabilidad:**
> Esta aplicación es un proyecto independiente y de código abierto. No está afiliada, respaldada ni patrocinada por el Gobierno Vasco, el Consorcio de Transportes de Bizkaia, Metro Bilbao, Renfe ni ningún otro operador de transporte público. Los horarios y tiempos de llegada en directo son estimaciones sujetas a condiciones de tráfico y operativas.

### Euskera
> **Datu-iturburuak:**
> - Sareko datuak, ordutegiak, denbora erreala eta geltokiak **Moveuskadi** eta **Open Data Euskadi** (Eusko Jaurlaritza) bidez emandakoak, [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) lizentziapean.
> - Administrazio-muga ofizialak Euskadiko Datu Espazialen Azpiegiturak (**geoEuskadi**) emandakoak.
> - **Bizkaiko Garraio Partzuergoa (BGP/CTB)**, **Metro Bilbao S.A.**, **Bizkaibus** (Bizkaiko Foru Aldundia), **Bilbobus** (Bilboko Udala), **Euskotren** (Eusko Trenbideak), **Dbus** (CTSS Donostia), **TUVISA** (Gasteizko Udala), **ArabaBus** (Arabako Foru Aldundia) eta **Lurraldebus** (Gipuzkoako Foru Aldundia) datu irekiak.
> - Aldirietako ordutegiak **Renfe Viajeros / Garraio eta Mugikortasun Jasangarriaren Ministerioak** emandakoak.
>
> **Erantzukizun-oharra:**
> Aplikazio hau independentea da eta kode irekikoa da. Ez du inolako harreman ofizialik Eusko Jaurlaritzarekin, Bizkaiko Garraio Partzuergoarekin, Metro Bilbaorekin edo Renferekin.

### English
> **Data Sources:**
> - Transit network schedules, real-time telemetry, and stop locations provided through **Moveuskadi** and **Open Data Euskadi** (Basque Government) under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
> - Official administrative territorial boundaries provided by **geoEuskadi** (Spatial Data Infrastructure of the Basque Country).
> - Open data from **Consorcio de Transportes de Bizkaia (CTB)**, **Metro Bilbao S.A.**, **Bizkaibus**, **Bilbobus**, **Euskotren**, **Dbus**, **TUVISA**, **Álavabus**, and **Lurraldebus**.
> - Cercanías commuter train schedules provided by **Renfe Viajeros / Ministry of Transport and Sustainable Mobility**.
>
> **Disclaimer:**
> This application is an independent open-source project and is not affiliated with, endorsed by, or sponsored by the Basque Government, CTB, Metro Bilbao, Renfe, or any public transit authority. Real-time arrival predictions are estimates subject to operational conditions.
