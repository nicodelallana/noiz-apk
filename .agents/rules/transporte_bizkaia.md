# Directrices Operativas del Proyecto Bizkaia Transit

Estas directrices proceden del pliego original del proyecto (`docs/prompt-app-transporte-bizkaia.md`).

## Reglas Innegociables
1. **Fuentes Oficiales y Licencias:** Solo consumir datos oficiales (GTFS, GTFS-RT, APIs abiertas). Citar atribuciones obligatorias y registrar licencias en `docs/licencias-datos.md`. No hacer scraping ni ingeniería inversa.
2. **Offline-First y Límites Supabase Free:** Los horarios GTFS residen en SQLite local preempaquetado (`drift`), no en PostgreSQL remoto. Supabase se reserva para Auth, viajes de usuario, sincronización y tarifas.
3. **Una Fase Cada Vez:** No avanzar a la siguiente fase sin validación expresa del usuario. Antes de comenzar cada fase, plantear el resumen de tareas y las decisiones pendientes.
4. **Diseño y Calidad Visual:** Paleta de azules y blancos, tipografía cuidada, sin estilos genéricos de IA. Integración con Figma MCP y Lottie Creator MCP.
5. **Rendimiento:** Animaciones de menos de 50 KB, renderizadas dentro de `RepaintBoundary`. Medición obligatoria con DevTools en Profile.
