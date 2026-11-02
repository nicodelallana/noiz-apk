# Euskadi Transit Operator Inventory

This document registers every public transport operator, mode, and territory identified in the reference materials (Garraio website `https://garraio.es/` and video suite `Garraio_video_no_watermark*.mp4`), establishing the full scope of support for Barik.

---

## 1. Comprehensive Operator & Service Roster

| # | Operator / Service | Mode | Territory | Reference Presence | Features Powered | Prior Barik Status | Upgraded Barik Status |
|---|---|---|---|---|---|:---:|:---:|
| **1** | **Renfe Cercanías** | Suburban commuter rail (`train`) | Bizkaia & Gipuzkoa | Web header, demo, video v1 [00:45], v2 [00:37], v3 [00:42] | Next departures, live tracking, C1/C2/C3 (Bilbao) & C1 (Donostia), widgets, lock screen | Partial (Bilbao C-lines) | **Full Support** (Bilbao + Donostia) |
| **2** | **Metro Bilbao** | Rapid transit (`subway`) | Bizkaia | Web hero, demo, video v1 [00:21], v2 [00:37], v3 [00:10] | L1, L2, L3 lines, departures, transfer routing, map, widget, lock screen | Supported (L1, L2) | **Full Support** (L1, L2, L3 + live sync) |
| **3** | **Euskotren Tren** | Regional rail & Topo (`train`) | Bizkaia & Gipuzkoa | Web list, demo, video v1 [00:52], v2 [00:61] | E1 (Bilbao-Donostia), E2 (Topo Lasarte-Hendaia), E3 (Txorierri), E4 (Urdaibai), E5 (Altza) | Not in UI | **Full Support** (All lines + Topo) |
| **4** | **Tranvía de Bilbao** | Urban tramway (`tram`) | Bizkaia | Web list, chips, video v2 [00:37] | Bolueta - La Casilla line, stop departures, map track | Not in UI | **Full Support** |
| **5** | **Tranvía de Vitoria-Gasteiz** | Urban tramway (`tram`) | Araba | Web list, chips | Ibaiondo / Abetxuko - Salburua / Unibertsitatea lines | Not in UI | **Full Support** |
| **6** | **Bizkaibus** | Interurban bus (`bus`) | Bizkaia | Web hero, demo, video v1 [00:22], v2 [00:07] | All county concessions (A21xx, A31xx, A32xx, A33xx, A34xx, A35xx, A39xx), live GTFS-RT | Partial | **Full Support** (All lines + GTFS-RT) |
| **7** | **Bilbobus** | Municipal urban bus (`bus`) | Bizkaia | Web list, video v1 [00:52] | Lines 01 to 88, A1 to A9, stop schedules and realtime | Partial | **Full Support** (Full network) |
| **8** | **Dbus (Donostiako Autobusak)** | Municipal urban bus (`bus`) | Gipuzkoa | Web list, video v1 [00:52], v3 [00:11] | Donostia urban lines (5, 8, 9, 13, 21, 25, 26, 28...), stop departures, live map | None | **Full Support** |
| **9** | **Lurraldebus** | Regional interurban bus (`bus`) | Gipuzkoa | Web list, video v1 [00:52] | Ekialdebus, Tolosaldea, Buruntzaldea, Goierrialdea, Urola lines | None | **Full Support** |
| **10** | **TUVISA** | Municipal urban bus (`bus`) | Araba | Web list, video v1 [00:52] | Vitoria-Gasteiz urban lines L1..L10, BEI (Bus Eléctrico Inteligente) | None | **Full Support** (BEI + Urban lines) |
| **11** | **Álavabus** | Provincial interurban bus (`bus`) | Araba | Web list | Lines 1 to 20 across Álava / Rioja Alavesa / Ayala | None | **Full Support** |
| **12** | **Funicular de Artxanda** | Funicular (`funicular`) | Bizkaia | Web list | Artxanda - Campo Volantín departures and frequency | None | **Full Support** |
| **13** | **Autobuses La Unión** | Regional express coach (`bus`) | Bizkaia & Araba | Web list | Bilbao - Vitoria-Gasteiz corridor line | None | **Full Support** |

---

## 2. Modes Covered
- **Subway / Metro (`subway`):** Metro Bilbao (L1, L2, L3).
- **Commuter & Regional Rail (`train`):** Renfe Cercanías (Bilbao C1, C2, C3; Donostia C1), Euskotren Tren (E1, E2 Topo, E3, E4, E5).
- **Tramway (`tram`):** Tranvía de Bilbao (TR), Tranvía de Vitoria-Gasteiz (TG1, TG2).
- **Urban Bus (`bus`):** Bilbobus (Bilbao), Dbus (Donostia / San Sebastián), TUVISA + BEI (Vitoria-Gasteiz).
- **Interurban & Regional Bus (`bus`):** Bizkaibus (Bizkaia), Lurraldebus (Gipuzkoa), Álavabus (Araba), Autobuses La Unión.
- **Funicular (`funicular`):** Funicular de Artxanda (Bilbao).

---

## 3. Territory Grouping & UI Filtering
The app interface provides top territory filtering chips:
- **Euskadi (Todo):** View all transit across the Basque Country.
- **Bizkaia:** Bilbao Metropolitan Area, Enkarterri, Busturialdea, Durangaldea, Uribe.
- **Gipuzkoa:** Donostialdea, Bidasoa, Oarsoaldea, Tolosaldea, Goierri, Urola Kosta, Debagoiena, Debabarrena.
- **Araba:** Vitoria-Gasteiz, Cuadrilla de Ayala, Llanada Alavesa, Rioja Alavesa, Montaña Alavesa.
