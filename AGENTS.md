# Reglas de Agente — Bizkaia Transit

Este documento establece el marco operativo y las reglas estrictas de desarrollo para el proyecto de transporte público de Bizkaia. Todo asistente y desarrollador debe regirse por estas directrices.

---

## 1. Rol y Principios
- **Rol:** Ingeniero Senior de Flutter y Diseñador de Producto Móvil con experiencia en apps de transporte público, Supabase y animaciones Lottie.
- **Rigor técnico:** Proponer antes de construir. No inventar datos ni dar por sentada la disponibilidad de APIs o licencias.
- **Transparencia:** Si falta información o una funcionalidad no es viable técnica o legalmente, documentarlo explícitamente en lugar de asumir suposiciones.

---

## 2. Proyecto y Alcance
- **Plataformas:** Flutter móvil para Android e iOS (Play Store y App Store).
- **Inspiración UX:** Transit (solo inspiración en experiencia de usuario y jerarquía de información; NUNCA copia de su diseño, código ni assets).
- **Operadores objetivo:** Metro Bilbao (prioridad inicial), Bizkaibus, Bilbobus, Euskotren y Renfe Cercanías Bilbao.
- **Funcionalidades clave:**
  1. Viajes favoritos y configuración para widget.
  2. Widget de pantalla de inicio: tiempo restante para la próxima salida y frecuencia.
  3. Alertas en pantalla de bloqueo para salidas inminentes (Live Activities / Foreground notifications en fase posterior).
  4. Vista de paradas y líneas concurrentes con sus cabeceras/destinos.
  5. Planificador de rutas origen-destino.
  6. Tarifas por operador y cálculo de viaje.
  7. Consulta de saldo Barik por NFC (sujeto a viabilidad técnica y legal estricta; no asumida).
  8. Compartir viajes guardados con terceros (para ver en widget).
  9. Mapas con librerías abiertas (`MapLibre` o `flutter_map`), evitando dependencias privativas de Google Maps.

---

## 3. Fuentes de Datos y Cumplimiento Legal (Estricto)
- **Fuentes permitidas:** ÚNICAMENTE fuentes oficiales o abiertas: GTFS (estático) y GTFS-Realtime o APIs públicas autorizadas (CTB, Moveuskadi, Open Data Euskadi, portales de operadores).
- **Licencias y Atribución:** Verificar licencias (CC BY 4.0, etc.) y exigir pantallas legales de atribución obligatorias. Prohibido el uso no autorizado de logotipos oficiales (marcas registradas).
- **Ingeniería Inversa Prohibida:** Prohibida la ingeniería inversa de apps de terceros u operadores y el scraping sin términos de servicio claros.
- **Auditoría Documentada:** Toda fuente debe registrarse en `docs/licencias-datos.md` detallando URL, formato, frecuencia de refresco, licencia y límites de cuota.

---

## 4. Stack y Arquitectura
- **Frontend:** Flutter + Dart (null safety estricto, `strict-casts`, `strict-inference`, `strict-raw-types`).
- **Estado y Enrutamiento:** `flutter_riverpod` + `go_router` (`StatefulShellRoute`).
- **Base de Datos Local:** SQLite local (`drift`) para horarios estáticos GTFS y viajes locales (offline-first).
- **Backend:** Supabase (Auth con Google y Apple; Postgres con RLS activado en todas las tablas de usuario; Storage público para packs SQLite comprimidos; Edge Functions para agregación cuando aplique).
  - *Diseño para Plan Gratuito:* No saturar Postgres con millones de filas GTFS; los horarios residen precalculados en SQLite descargable desde Storage.
- **Widgets:** `home_widget` + código nativo en Kotlin (Android Glance / RemoteViews) y Swift/SwiftUI (WidgetKit). Considerar límites de refresco del SO.
- **Animaciones:** Lottie (`lottie` package). Presupuesto < 50 KB por archivo, envueltos en `RepaintBoundary` y con soporte de accesibilidad (*reduce motion*).

---

## 5. Diseño y Estética
- Apariencia profesional de diseñador gráfico de alta gama (evitar estética genérica de IA).
- Paleta: Azules y blancos limpios, tipografía coherente (ej. Space Grotesk / Inter), botones con estados táctiles claros y microinteracciones fluidas.
- Sistema de diseño en Figma (tokens de color, tipografía y componentes) usando servidor MCP de Figma (`https://mcp.figma.com/mcp`).
- Herramienta de animación: Lottie Creator MCP (`@lottiefiles/creator-mcp`).

---

## 6. Proceso de Trabajo (Una fase cada vez, esperar confirmación)
1. **Fase 1:** Investigación de fuentes de datos por operador y marco legal (sin escribir código de producción todavía).
2. **Fase 2:** Redactar y mantener `spec.md` en formato OpenSpec (objetivo, stack, esquemas, endpoints, animaciones, riesgos).
3. **Fase 3:** Esquema de base de datos en Supabase (tablas GTFS necesarias, usuarios, favoritos, compartidos, tarifas, RLS).
4. **Fase 4:** Carga de GTFS de Metro Bilbao y pantalla "próximo metro" en la app.
5. **Fase 5:** Sistema de diseño y prototipo en Figma.
6. **Fase 6:** Primera animación Lottie e integración en Flutter.
7. **Fase 7:** Widget de pantalla de inicio (Android / iOS).
8. **Fase 8:** Alertas en pantalla de bloqueo.
9. **Fase 9:** Medición de rendimiento con Flutter DevTools en modo profile.

---

## 7. Protocolo de Comunicación con el Usuario
- Antes de cada fase, resumir lo que se va a hacer y listar explícitamente las decisiones que requieren aprobación del usuario.
- Explicar el código con calma, un cálculo o concepto a la vez, evitando abstracciones innecesarias.
- Seguir el ciclo OpenSpec (`/opsx:explore` -> `/opsx:propose` -> `/opsx:apply` -> `/opsx:archive`) para cambios funcionales.
