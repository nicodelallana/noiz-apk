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
