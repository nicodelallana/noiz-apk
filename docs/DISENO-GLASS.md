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
| `blur: false` | En `GlassSurface` / `GlassButton`, para controles que van encima de otro cristal (botones de una hoja): basta con un desenfoque. |
| `SurfaceCard` | Tarjeta sólida de contenido (radio 24, filo de 1 px, `onTap` opcional, `accent:` para el borde de color). |
| `LineBadge` | Insignia de línea con el color del operador. |
| `SectionHeader` | Título de sección estilo iOS con subtítulo y acción opcional. |
| `DepartureStatus` | "En directo", "Según horario" o "+N min". |
| `CountdownText` | Minutos con dígitos tabulares que "ruedan" al cambiar; 0 se muestra como "Ya". |
| `Motion` | `smooth` (0,5 / 1), `snappy` (0,35 / 0,85), `bouncy` (0,3 / 0,6) y `sheet` (0,45 / 0,88). Cada uno da `.duration` y `.curve`. `Motion.reduced(context)` indica si hay que reducir el movimiento. |
| `AuroraBackground` | Fondo del shell, a 12 fps. Pásale `animate: false` en pantallas empujadas. |

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

## Reglas de rendimiento

- Como mucho unos 5 desenfoques vivos por pantalla. El contenido que hace scroll no lleva desenfoque.
- No metas cristal dentro de `Opacity` ni de `FadeTransition`, porque rompe el desenfoque. Para aparecer, anima el contenido, no el cristal.
- El shell envuelve las pestañas en un `BackdropGroup`. Los cristales que se solapan (una hoja sobre la barra) usan su propio desenfoque; las hojas modales van en el navegador raíz.
- El cambio de pestaña es instantáneo, como en iOS. Lo que se anima es la entrada del contenido.
- Las pantallas empujadas usan la transición de iOS en todas las plataformas: la de Android desvanece la página saliente, y con ella el cristal del shell.

## Pantallas

- **Shell:** barra cápsula flotante (62 → 50 al hacer scroll hacia abajo) con una "gota" de cristal que se desliza entre pestañas, el aviso numérico de avisos cercanos en "Alertas" y el botón de modo como círculo de cristal aparte. Tiene un degradado en el borde inferior para que se lea el contenido.
- Las páginas de pestaña llevan `Scaffold` transparente y dejan unos 120 px de margen inferior para la barra. Las pantallas empujadas (parada, licencias) pintan su propio `AuroraBackground(animate: false)`.
