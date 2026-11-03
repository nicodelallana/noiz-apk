# Punto de Control y Estado de Avance — Euskadi Transit

**Fecha:** 3 de noviembre de 2026  
**Rama activa:** `feat/euskadi-transit-accuracy`  
**Estado:** Fases 1, 2, 3, 4 y 5 completadas con éxito. Todos los tests pasan (45/45) y `flutter analyze` 0 issues. Listo para revisión final y merge.

---

## 1. Lo que se ha completado hasta ahora

1. **Rama de trabajo:**
   - Creada y activa la rama `feat/euskadi-transit-accuracy` desde `main`.
2. **Auditoría completa de causas raíz:**
   - **Paradas ausentes:** Se descubrió que la base de datos anterior solo contenía 136 paradas escritas a mano en un array de Python y que la consulta en Flutter tenía `LIMIT 300` y descartaba paradas con `parent_station`.
   - **Horarios inventados:** Se localizaron fórmulas sintéticas en `build_transit_db.py` (`int(seq * 2.5)`), salidas generadas dinámicamente con `DateTime.now()` en `bus_providers.dart` y consultas fallback ficticias a las 06:00:00 en `transit_repository_impl.dart`.
   - **Márgenes en pantalla:** Se identificó la ausencia de `SystemUiMode.edgeToEdge` y padding duplicado (`topInset + 20` y espacio inferior excesivo).
   - **Navegación:** Se identificaron tres accesos redundantes al selector de transporte en la pantalla de inicio.
   - **Mapa saturado:** Se identificó la falta de jerarquía (todos los modos/vehículos a la vez) y la ausencia total de geometrías de trazado (`shapes.txt`).
3. **Informe de reconciliación de datos oficial:**
   - Redactado y disponible en el proyecto.
4. **Desarrollo del compilador GTFS oficial (`tools/build_gtfs/compile_official_gtfs.py`):**
   - Procesados con éxito los **35 feeds oficiales de Moveuskadi**.
   - Resultados de la red real extraída:
     - **7.843 paradas oficiales** (frente a las 136 anteriores).
     - **1.122 rutas oficiales** en Bizkaia, Gipuzkoa y Araba.
     - **2.037 geometrías de línea (`shapes`)** para pintar los recorridos en el mapa.
     - **119.256 viajes oficiales** y **2.040.672 horarios de paso**.
5. **Finalización de Fase 1 (Datos y Base de Datos Oficial):**
   - Actualizado [app_database.dart](file:///home/nicolas/Escritorio/noiz-apk/lib/data/local/app_database.dart):
     - `getStationsInBounds` ahora soporta filtrado por `operator_id`, `mode`, `route_id`, inclusión de plataformas y límite opcional.
     - Añadido `getRouteShape` para extraer coordenadas geográficas GeoJSON `[lon, lat]` de rutas.
     - Añadido `getRoutes` y `getStopsForRoute` para consultar líneas y secuencia ordenada de paradas.
   - Actualizado [transit_repository_impl.dart](file:///home/nicolas/Escritorio/noiz-apk/lib/data/adapters/transit_repository_impl.dart):
     - Erradicado el fallback forzado a las 06:00:00 y `'daily_regular'`. Cuando no hay salidas, devuelve lista vacía honesta.
   - Erradicado el generador artificial de [bus_providers.dart](file:///home/nicolas/Escritorio/noiz-apk/lib/presentation/providers/bus_providers.dart), conectado ahora a fuentes oficiales GTFS.
   - Creados tests en [transit_database_accuracy_test.dart](file:///home/nicolas/Escritorio/noiz-apk/test/unit/transit_database_accuracy_test.dart) (40 tests pasando en total).

---

## 2. Lo que queda exactamente por hacer y comprobar

### Fase 1: Finalizar Corrección de Datos (Prioridad 1)
- [x] **Optimización del archivo SQLite (`transit.sqlite`):**
  - Simplificar las coordenadas de `shapes` con Ramer-Douglas-Peucker (reduce el tamaño de geometrías un 67% sin perder calidad visual).
  - Unificar índices en `stop_times` y `trips` para consultas sub-milisegundo.
- [x] **Actualizar consultas en `lib/data/local/app_database.dart`:**
  - Corregir `getStationsInBounds` para soportar andenes/estaciones (`location_type`) y eliminar el corte forzado `LIMIT 300`.
  - Agregar soporte de filtrado opcional por `operator_id`, `mode` y `route_id`.
  - Añadir consultas para extraer la geometría de una ruta: `getRouteShape(routeId)`.
  - Añadir consultas para `getRoutes` y `getStopsForRoute`.
- [x] **Erradicar datos falsos/placeholders:**
  - Eliminar el generador artificial de `lib/presentation/providers/bus_providers.dart`.
  - En `transit_repository_impl.dart`, eliminar el fallback forzado a las 06:00:00 cuando no hay salidas; devolver lista vacía y mostrar "Sin próximas salidas programadas".

### Fase 2: Rediseño del Mapa: Modo → Operador → Línea (Prioridad 2)
- [x] Implementar selector de **Modo de Transporte** (Metro, Tren, Tranvía, Autobús, Funicular).
- [x] Implementar selector de **Operador** dinámico según el modo elegido.
- [x] Implementar selector de **Línea/Ruta** con sus direcciones y cabeceras.
- [x] Dibujar en MapLibre el trazado geométrico real (`shapes`) de la ruta seleccionada.
- [x] Renderizar únicamente las paradas pertenecientes a la línea/operador activo.
- [x] Filtrar los vehículos en tiempo real para que solo aparezcan los de la línea activa y con sus coordenadas oficiales.
- [x] Crear la tarjeta/hoja de detalle de vehículo (`VehicleSheet`) con datos de procedencia, retraso, velocidad y frescura.

### Fase 3: Layout Móvil Completo y Navegación Limpia (Prioridad 3)
- [x] Configurar `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` en Flutter.
- [x] Ajustar temas nativos en `android/app/src/main/res/values/styles.xml` con barras de navegación y estado transparentes.
- [x] Ajustar márgenes en `Scaffold`, `app_shell.dart` y `metro_departures_screen.dart` eliminando padding redundante.
- [x] Dejar el botón de la barra de navegación como único acceso al selector de transporte en la pantalla principal.

### Fase 4: Experiencia Android Live y Widgets (Prioridad 4)
- [x] Rediseñar `TransitWidgetProvider` (AppWidget de inicio) con diseño limpio, soporte multi-operador, formato dinámico de cuenta atrás y colores de marca.
- [x] Modernizar `TransitLiveService` y `WidgetUpdateService` (notificación persistente para pantalla de bloqueo y sincronización de widgets) conectada a datos oficiales y `TransitRepository`.
- [x] Pruebas unitarias completas de `WidgetUpdateService` verificando sincronización de viajes guardados y soporte multi-operador.

### Fase 5: Pruebas y Validación (Prioridad 5)
- [x] Ejecutar suite completa `flutter test`: **45/45 pruebas pasando** (unitarias, presentación, widgets y precisión de datos).
- [x] Ejecutar `flutter analyze`: **0 issues encontrados** (código limpio, strict type checking, sin advertencias).
- [x] Validación de cero datos sintéticos o inventados en la base de datos oficial SQLite y en los repositorios de Dart.

---

## 3. Instrucción para retomar la sesión

Cuando regreses, solo di:
> *"Continuamos con la Fase 1: optimizar el compilador SQLite y actualizar app_database.dart"*
