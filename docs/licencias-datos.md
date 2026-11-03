# Auditoría de Licencias de Datos y Atribución Legal

> Documento vivo de cumplimiento legal para el proyecto **Bizkaia Transit** conforme a las secciones 5.8 y 13.5 de la especificación técnica.
> Fecha de revisión: 29 de septiembre de 2026.

---

## 1. Resumen de Licencias por Operador

| Operador / Fuente | Portal | Licencia Declarada | Uso Comercial | Requiere Atribución | Restricciones de Marca / Logo |
|---|---|---|:---:|:---:|---|
| **Consorcio de Transportes de Bizkaia (CTB)** | `data.ctb.eus` | **CC BY 4.0** | Sí | Sí | No usar logotipos oficiales sin autorización |
| **Bizkaibus** | `baliabideak.bizkaia.eus` / CTB | **CC BY 4.0** | Sí | Sí | Marca de Diputación Foral de Bizkaia protegida |
| **Bilbobus** | `bilbao.eus` / Open Data Euskadi | **CC BY 4.0** | Sí | Sí | Marca del Ayuntamiento de Bilbao protegida |
| **Euskotren** | `data.ctb.eus` / Moveuskadi | **CC BY 4.0** | Sí | Sí | Marca de Eusko Trenbideak protegida |
| **Moveuskadi (Gob. Vasco)** | `opendata.euskadi.eus` | **CC BY 4.0** | Sí | Sí | Licencia estándar de Open Data Euskadi |
| **Metro Bilbao** | `metrobilbao.eus` | Reutilización abierta | Sí | Sí | **Logo no libre:** prohibido el uso del isotipo oficial |
| **Renfe Cercanías** | `ssl.renfe.com` / Ministerio de Transportes | Reutilización sector público (Ley 37/2007) | Sí | Sí | Marca Renfe / Cercanías protegida |

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

La aplicación móvil debe incluir en la pantalla de información legal y créditos (*Ajustes → Acerca de*) las siguientes menciones obligatorias en español, euskera e inglés:

### Español
> **Fuentes de datos:**
> - Datos de horarios, tiempo real y paradas facilitados por el **Consorcio de Transportes de Bizkaia (CTB)**, bajo licencia [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
> - Datos abiertos de **Metro Bilbao S.A.**, **Bizkaibus** (Diputación Foral de Bizkaia), **Bilbobus** (Ayuntamiento de Bilbao), **Euskotren** (Eusko Trenbideak) y **Moveuskadi** (Gobierno Vasco).
> - Horarios de Cercanías facilitados por **Renfe Viajeros / Ministerio de Transportes y Movilidad Sostenible**.
>
> **Aviso de responsabilidad:**
> Esta aplicación es un proyecto independiente y de código abierto. No está afiliada, respaldada ni patrocinada por el Consorcio de Transportes de Bizkaia, Metro Bilbao, Renfe ni ningún otro operador de transporte público. Los horarios y tiempos de llegada son estimaciones sujetas a condiciones de tráfico y operativas.

### Euskera
> **Datu-iturburuak:**
> - Ordutegiak, denbora erreala eta geltokiak **Bizkaiko Garraio Partzuergoak (BGP/CTB)** emandakoak, [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) lizentziapean.
> - **Metro Bilbao S.A.**, **Bizkaibus** (Bizkaiko Foru Aldundia), **Bilbobus** (Bilboko Udala), **Euskotren** (Eusko Trenbideak) eta **Moveuskadi** (Eusko Jaurlaritza) datu irekiak.
> - Aldirietako ordutegiak **Renfe Viajeros / Garraio eta Mugikortasun Jasangarriaren Ministerioak** emandakoak.
>
> **Erantzukizun-oharra:**
> Aplikazio hau independentea da eta kode irekikoa da. Ez du inolako harreman ofizialik Bizkaiko Garraio Partzuergoarekin, Metro Bilbaorekin edo Renferekin.

### English
> **Data Sources:**
> - Transit schedules, real-time feeds, and stop information provided by **Consorcio de Transportes de Bizkaia (CTB)** under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
> - Open data from **Metro Bilbao S.A.**, **Bizkaibus**, **Bilbobus**, **Euskotren**, and **Moveuskadi**.
> - Cercanías commuter train schedules provided by **Renfe Viajeros / Ministry of Transport and Sustainable Mobility**.
>
> **Disclaimer:**
> This application is an independent open-source project and is not affiliated with, endorsed by, or sponsored by CTB, Metro Bilbao, Renfe, or any public transit authority. Real-time arrival predictions are estimates subject to operational conditions.

---

## 3. Protocolo de Revisión Periódica

1. **Chequeo Semanal Automatizado:** El script `tools/verify_feeds.sh` se ejecuta en GitHub Actions para verificar la vigencia de los endpoints.
2. **Revisión de Términos:** Ante cualquier cambio en las fichas de `data.ctb.eus` o `opendata.euskadi.eus`, se auditarán posibles modificaciones de licencias y se registrarán en el historial de este documento.
