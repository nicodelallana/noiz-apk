# Proxy de vehículos en directo

`GET /api/vehicles` devuelve en un solo JSON los vehículos en directo de Bizkaia para el mapa de la app.

## Por qué hace falta

- Los feeds oficiales son GTFS-RT en protobuf y **ningún servidor manda cabeceras CORS**, así que la versión web no puede leerlos directamente.
- Con un único endpoint, la app consulta una respuesta pequeña (unos 66 KB) en lugar de tres feeds.
- La respuesta se guarda 20 s en la CDN, así que a los operadores les llegan como mucho unas 3 peticiones por minuto, haya los usuarios que haya.

## Qué se muestra (verificado el 3 nov 2026)

| Operador | Feed | Qué hay |
|---|---|---|
| Bizkaibus | `baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedVehiculos.pb` | **GPS real** (`kind: "gps"`) |
| Metro Bilbao | `ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-vehicle-positions.pb` | Tren situado en la **última estación** detectada (`kind: "station"`), no GPS |
| Renfe Cercanías Bilbao | `gtfsrt.renfe.com/vehicle_positions.pb` (nacional, se filtra a Bizkaia) | Por estación (`kind: "station"`) |
| Bilbobus, Euskotren | — | Sin posiciones publicadas ahora: no se muestran |

- Las posiciones con más de 3 minutos se descartan, para no mostrar nunca como directo un dato viejo.
- Índice oficial de todos los feeds: `opendata.euskadi.eus/transport/moveuskadi/data-index-gtfs-rt.json`.

Licencia: CC BY 4.0 (CTB, Diputación Foral de Bizkaia y Renfe). La atribución va en el JSON (`attribution`) y la app la enseña.

## Nombres de línea, colores y destinos

Los feeds en directo solo traen identificadores (`trip_id`, `stop_id`). Los nombres salen del GTFS estático oficial y se guardan en `api/_data/lookups.json`, generado con:

```bash
python3 build_lookups.py <carpeta con gtfs_metro/ gtfs_bzk/ gtfs_renfe/>
```

Solo se leen `routes.txt`, `trips.txt` y `stops.txt` de:

| Carpeta | GTFS oficial |
|---|---|
| `gtfs_metro` | `ctb-gtfs.s3.eu-south-2.amazonaws.com/metrobilbao.zip` |
| `gtfs_bzk` | `ctb-gtfs.s3.eu-south-2.amazonaws.com/bizkaibus.zip` |
| `gtfs_renfe` | `ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip` |

Hay que **regenerarlo cuando un operador publique horarios nuevos**. El de Bizkaibus vale del 27 oct al 27 dic de 2026. Si un viaje no aparece en la tabla, el vehículo se sigue mostrando, pero con el nombre del operador en vez de la línea.

## Despliegue

- **Ahora:** función de Vercel, junto a la vista previa web (`noiz-glass-vista-previa/publicar.sh` copia `api/` y `package.json`).
- **Después:** según la parte II del spec, esto debería ir a una Edge Function de Supabase. En la app solo cambia `LIVE_VEHICLES_URL` (`--dart-define`).
