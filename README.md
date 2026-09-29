# Bizkaia Transit (nombre provisional)

> App móvil (Android + iOS) para consultar transporte público de Bizkaia de un vistazo: viajes guardados, widgets, incidencias, planificador y, a futuro, saldo Barik.

## 🚀 Visión general

- **Widgets de pantalla de inicio (Android e iOS):** Próxima salida en < 1 s con datos precalculados en local.
- **Offline-first:** Funcionamiento completo sin conexión con horarios teóricos almacenados en SQLite (`drift`).
- **Tiempo real directo:** Consultas directas a feeds GTFS-RT (CTB, Bizkaibus, Renfe) sin intermediación de servidor para evitar cuellos de botella y costes.
- **Coste de infraestructura inicial 0 €:** Supabase Free (Auth + Postgres RLS + Storage público para packs GTFS) + GitHub Actions para ETL nocturno.
- **Operadores soportados (v1.0):** Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe Cercanías Bilbao.

## 🛠️ Stack Tecnológico

- **Framework:** Flutter (canal `stable`, FVM) + Dart (null safety estricto, `very_good_analysis`)
- **Widgets nativos:** Kotlin (Android Glance / RemoteViews) y SwiftUI (iOS WidgetKit)
- **Backend:** Supabase (Auth, PostgreSQL con RLS, Storage)
- **Base de datos local:** SQLite vía `drift`
- **Estado y Navegación:** `flutter_riverpod` + `go_router` (`StatefulShellRoute`)
- **Red y Protobuf:** `dio` + bindings Dart de GTFS-Realtime (decodificación en `Isolate`)

## 📐 Desarrollo guiado por especificaciones (OpenSpec)

Este proyecto utiliza **OpenSpec** para gobernar los cambios y especificaciones de arquitectura y capacidades:

- Especificación completa del proyecto: [`spec.md`](spec.md)
- Contexto de OpenSpec: [`openspec/project.md`](openspec/project.md) y [`openspec/config.yaml`](openspec/config.yaml)
- Especificaciones de capacidades: [`openspec/specs/`](openspec/specs/)
  - `auth`
  - `transit-data`
  - `realtime`
  - `saved-trips`
  - `widget`
  - `trip-planner`
  - `alerts`
  - `sharing`
  - `barik-balance`
  - `ui-navigation`

> **Regla fundamental:** Ninguna funcionalidad se programa sin un change de OpenSpec propuesto, revisado y aprobado.

### Flujo de trabajo con OpenSpec

1. **Explorar / idear:** `/opsx:explore` o `openspec change <nombre>`
2. **Proponer cambio:** `/opsx:propose <nombre>` (genera `proposal.md`, `specs/`, `design.md`, `tasks.md`)
3. **Revisar y aprobar:** validación con `openspec validate <nombre>`
4. **Implementar:** `/opsx:apply` siguiendo las tareas
5. **Archivar:** `/opsx:archive <nombre>` para consolidar deltas en las especificaciones maestras

## 📋 Próximos pasos (Changes sugeridos)

1. `bootstrap-project` — Repositorio, lints (`very_good_analysis`), estructura base y CI.
2. `verify-data-feeds` — Tarea T0: script `tools/verify_feeds.sh` y registro de licencias en `docs/licencias-datos.md`.
3. `gtfs-pipeline` — Pipeline nocturno de empaquetado SQLite y almacenamiento en Storage.
4. `metro-departures` — Adaptador de Metro Bilbao, clasificación L1/L2 y pantalla inicial de salidas.