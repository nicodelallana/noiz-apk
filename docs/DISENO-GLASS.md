# Noiz · sistema visual "glass"

Rediseño en la rama `redesign/glass`. Toma como referencia el lenguaje Liquid Glass de Apple (iOS 26), las guías de interfaz de Apple (Materials, Tab bars, Sheets) y apps como Apple Maps, Transit y Citymapper. Es inspiración: no se copian sus diseños, iconos ni marcas.

## Principios

1. **El cristal solo va en la navegación.** Llevan glass la barra de pestañas, los botones flotantes, las hojas (sheets), las píldoras sobre el mapa y los filtros fijos. El contenido (tarjetas de salidas, avisos, filas de ajustes) va en superficies **sólidas** (`SurfaceCard`). No se pone cristal sobre cristal.
2. **Fondo oscuro con aurora.** `AuroraBackground` pinta tres brillos (teal, índigo y el color del operador elegido) que derivan muy despacio. El cristal necesita algo detrás que refractar.
3. **Un único color de acento:** azul `AppColors.accent` (#0A84FF). Los colores de operador se usan solo en insignias de línea, puntos del mapa, el brillo del fondo y el botón de modo.
4. **El estado se dice con palabras.** "En directo" lleva un punto verde que late; "Según horario" va en gris sin icono; los retrasos aparecen en ámbar con "+N min". El color nunca va solo.
5. **El movimiento tiene sentido.** Se usan muelles (springs) al estilo de SwiftUI y, con "reducir movimiento" activado, todo pasa a fundidos de 150 ms.

## Piezas (lib/presentation/widgets/glass/)

| Pieza | Uso |
|---|---|
| `GlassSurface(kind:, radius:, padding:, tint:)` | Material glass: desenfoque σ22 con saturación ×1,7, tinte oscuro, borde con degradado, brillo superior y sombra doble. Usa esquinas continuas (superelipse). |
| `GlassKind.regular` | Por defecto. |
| `GlassKind.overMap` | Sobre el mapa. En web el mapa es un elemento HTML que no se puede desenfocar, así que se usa un tinte denso (0,88). En Android el desenfoque sí funciona. |
| `GlassKind.clear` | Cristal fino para fondos ricos (onboarding). |
| `GlassButton` | Cristal pulsable: escala a 0,96 con muelle y vibración ligera. `tint:` lo convierte en la acción principal. Sin `onPressed` se atenúa el contenido, no el cristal. |
| `blur: true` | En `GlassSurface` / `GlassButton`, activa el desenfoque real. Por defecto está apagado; ver las reglas de rendimiento. |
| `SurfaceCard` | Tarjeta sólida de contenido (radio 24, filo de 1 px, `onTap` opcional, `accent:` para el borde de color). |
| `LineBadge` | Insignia de línea con el color del operador. |
| `SectionHeader` | Título de sección estilo iOS con subtítulo y acción opcional. |
| `DepartureStatus` | "En directo", "Según horario" o "+N min". |
| `CountdownText` | Minutos con dígitos tabulares que "ruedan" al cambiar; 0 se muestra como "Ya". |
| `Motion` | `smooth` (0,5 / 1), `snappy` (0,35 / 0,85), `bouncy` (0,3 / 0,6) y `sheet` (0,45 / 0,88). Cada uno da `.duration` y `.curve`. `Motion.reduced(context)` indica si hay que reducir el movimiento. |
| `AuroraBackground` | Fondo del shell, estático (solo anima el cambio de color de operador). Las pantallas empujadas pintan el suyo. |

## Tipografía (`AppTypography`)

Inter, en cortes estáticos generados desde la fuente variable (licencia OFL, en `assets/fonts/Inter/`). Es la alternativa licenciable a SF Pro, que solo puede usarse en plataformas de Apple.

| Estilo | Tamaño | Uso |
|---|---|---|
| `displayMedium` | 34 | Título grande |
| `titleLarge` | 22 | Título de sección |
| `titleMedium` | 17 | Cabecera de fila / destino |
| `bodyMedium` | 15 | Texto |
| `bodySmall` | 13 | Nota |
| `labelSmall` | 10 | Etiqueta de pestaña |

`AppTypography.countdown` es el número grande (72, InterDisplay 800); `countdownSmall` es su versión de 28 y `time` sirve para horas. Todos usan cifras tabulares.

Colores de texto: `darkTextPrimary` (100 %), `darkTextSecondary` (60 %) y `darkTextTertiary` (30 %).

## Formas

Todas las esquinas son continuas (`RoundedSuperellipseBorder` / `ClipRSuperellipse`):

| Elemento | Radio |
|---|---|
| Barras y botones | 999 (cápsula) |
| Hojas | 32–40 |
| Tarjetas | 24 |
| Filas | 12–14 |
| Insignias | 7–10 |

Los elementos anidados son concéntricos: radio interior = radio exterior − padding.

## Reglas de rendimiento (medidas)

Medido con Chrome automatizado: móvil de 390×844 a 3×, CPU 4 veces más lenta (un móvil de gama media) y scroll real de Inicio.

| Medida | Antes | Después |
|---|---|---|
| CPU en reposo (4 s sin tocar) | ~1.170 ms | 0–1 ms |
| Fotogramas de más de 25 ms al hacer scroll | 49–59 | 0–3 |
| Peor tirón | 133–183 ms | 17–33 ms (una vez, 83) |
| CPU durante el scroll | 6,1 s | 1,9 s |

- **El desenfoque es opcional (`blur: true`).** Solo lo llevan los elementos que tienen contenido moviéndose detrás: la barra de pestañas, el botón de modo, las hojas, las barras fijadas, los botones flotantes y los controles sobre el mapa. Sobre la aurora, que es un degradado suave, desenfocar no se nota pero cuesta una pasada completa en cada fotograma.
- **En web no hay desenfoque ni sombras.** Flutter web no tiene caché de rasterizado: en cada fotograma de scroll repinta cada desenfoque y cada sombra, y entre los dos eran la mitad de los tirones. En su lugar se usa un tinte denso (0,92) donde pasa contenido por debajo. En Android e iOS se mantiene el desenfoque real.
- **Superelipses solo en nativo.** `continuousShape()` / `ContinuousClip` (en `widgets/glass/shapes.dart`) dan una superelipse en Android e iOS y un rectángulo redondeado en web. La superelipse es un trazado que se dibuja de nuevo en cada fotograma; el rectángulo redondeado se dibuja directamente. A estos radios no se distinguen. Fue la segunda mayor mejora.
- **La aurora es estática.** Cualquier repintado del fondo invalida todo el cristal que tiene encima: animada, la app consumía CPU en reposo. Solo se anima el cambio de color al cambiar de operador.
- **Las pestañas se mantienen vivas** (`StatefulShellRoute.indexedStack`). Al volver al mapa no se recrea MapLibre.
- **No hay mapa dentro del scroll.** Inicio enlaza a la pestaña Mapa: un mapa embebido es una vista de plataforma que hay que recomponer en cada fotograma.
- No se usa `InkSparkle` (compila un shader al primer toque); se usa `InkRipple`.
- No metas cristal dentro de `Opacity` ni de `FadeTransition`. El cambio de pestaña es instantáneo, como en iOS, y las pantallas empujadas usan la transición de iOS en todas las plataformas.
- **Pendiente:** el renderizador WebAssembly de Flutter sería todavía más rápido, pero `flutter_secure_storage` 9 usa `dart:html` y no compila con `--wasm`. Hace falta actualizarlo a la versión 10.

## Pantallas

- **Shell:** barra cápsula flotante (62 → 50 al hacer scroll hacia abajo) con una "gota" de cristal que se desliza entre pestañas, el aviso numérico de avisos cercanos en "Alertas" y el botón de modo como círculo de cristal aparte. Tiene un degradado en el borde inferior para que se lea el contenido.
- Las páginas de pestaña llevan `Scaffold` transparente y dejan unos 120 px de margen inferior para la barra. Las pantallas empujadas (parada, licencias) pintan su propio `AuroraBackground(animate: false)`.
- **Mapa en directo:**
  - Capa GeoJSON de vehículos con datos de `tools/vehicle-proxy`: los de GPS (Bizkaibus) van como punto relleno con borde blanco y los situados por estación (Metro, Renfe) como anillo del color de la línea.
  - Etiqueta con la línea desde zoom 13.
  - Los vehículos se deslizan unos 1,1 s hacia cada nueva posición (con "reducir movimiento" saltan) y no se animan saltos de más de 3 km.
  - La capa consulta cada 20 s solo mientras la pestaña está visible y la app en primer plano.
  - Una píldora de cristal "En directo · N vehículos" permite ocultarlos y explica qué significa cada marca.

