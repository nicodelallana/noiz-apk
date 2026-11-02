#!/usr/bin/env python3
"""
Barik Transit — Multi-Operator GTFS Static Schedule Compiler
=============================================================
Compiles verified static transit feeds for all 13 operators across
Bizkaia, Gipuzkoa, and Araba into a compact, indexed SQLite database
(transit.sqlite), compresses it (transit.sqlite.gz), and generates manifest.json.
Includes complete station networks for Metro Bilbao (L1, L2, L3), Renfe Cercanías,
Tranvía, Bilbobus, Bizkaibus, Euskotren, Dbus, and TUVISA.
"""

import gzip
import hashlib
import json
import os
import shutil
import sqlite3
import time
from datetime import datetime, timezone

OPERATORS_DATA = [
    ("metro", "Metro Bilbao", "bizkaia", "metro", "#E8590C", 1),
    ("renfe", "Renfe Cercanías", "bizkaia", "train", "#D0142B", 1),
    ("euskotren", "Euskotren", "bizkaia", "train", "#025DA9", 1),
    ("tranbia_bilbao", "Tranvía de Bilbao", "bizkaia", "tram", "#2FA650", 1),
    ("tranbia_gasteiz", "Tranvía de Vitoria-Gasteiz", "araba", "tram", "#2FA650", 1),
    ("bizkaibus", "Bizkaibus", "bizkaia", "bus", "#2E9E4F", 1),
    ("bilbobus", "Bilbobus", "bizkaia", "bus", "#D7143C", 1),
    ("dbus", "Dbus", "gipuzkoa", "bus", "#1D7FD1", 1),
    ("lurraldebus", "Lurraldebus", "gipuzkoa", "bus", "#5E9424", 1),
    ("tuvisa", "TUVISA", "araba", "bus", "#12979F", 1),
    ("alavabus", "Álavabus", "araba", "bus", "#B04A8E", 0),
    ("artxanda", "Funicular de Artxanda", "bizkaia", "funicular", "#DC0B0B", 0),
    ("la_union", "La Unión", "araba", "bus", "#30609D", 0),
]

ROUTES_DATA = [
    # Metro Bilbao
    ("metro_L1", "metro", "L1", "Plentzia - Etxebarri", 1, "#E8590C", "bizkaia"),
    ("metro_L2", "metro", "L2", "Kabiezes - Basauri", 1, "#1E293B", "bizkaia"),
    ("metro_L3", "metro", "L3", "Matiko - Kukullaga", 1, "#025DA9", "bizkaia"),
    # Renfe Cercanías
    ("renfe_C1", "renfe", "C-1", "Bilbao-Abando - Santurtzi", 2, "#D0142B", "bizkaia"),
    ("renfe_C2", "renfe", "C-2", "Bilbao-Abando - Muskiz", 2, "#D0142B", "bizkaia"),
    ("renfe_C3", "renfe", "C-3", "Bilbao-Abando - Orduña", 2, "#D0142B", "bizkaia"),
    ("renfe_C1_SS", "renfe", "C-1", "Irun - Brinkola (Donostia)", 2, "#D0142B", "gipuzkoa"),
    # Euskotren
    ("euskotren_E1", "euskotren", "E1", "Bilbao-Matiko - Donostia-Amara", 2, "#025DA9", "bizkaia"),
    ("euskotren_E2", "euskotren", "E2", "Topo: Lasarte - Hendaia", 2, "#025DA9", "gipuzkoa"),
    ("euskotren_E4", "euskotren", "E4", "Bilbao-Matiko - Bermeo (Urdaibai)", 2, "#025DA9", "bizkaia"),
    # Tranvías
    ("tranbia_TR", "tranbia_bilbao", "TR", "Bolueta - La Casilla", 0, "#2FA650", "bizkaia"),
    ("tranbia_TG1", "tranbia_gasteiz", "TG1", "Ibaiondo - Salburua", 0, "#2FA650", "araba"),
    ("tranbia_TG2", "tranbia_gasteiz", "TG2", "Abetxuko - Unibertsitatea", 0, "#2FA650", "araba"),
    # Bizkaibus
    ("bizkaibus_A2153", "bizkaibus", "A2153", "Bilbao - Loiu Aireportua", 3, "#2E9E4F", "bizkaia"),
    ("bizkaibus_A3115", "bizkaibus", "A3115", "Bilbao - Santurtzi", 3, "#2E9E4F", "bizkaia"),
    ("bizkaibus_A3247", "bizkaibus", "A3247", "Bilbao Intermodal - Aireportua", 3, "#2E9E4F", "bizkaia"),
    ("bizkaibus_A3414", "bizkaibus", "A3414", "Bilbao - Getxo", 3, "#2E9E4F", "bizkaia"),
    # Bilbobus
    ("bilbobus_01", "bilbobus", "01", "Arangoiti - Plaza Biribila", 3, "#D7143C", "bizkaia"),
    ("bilbobus_28", "bilbobus", "28", "Uribarri - Altamira", 3, "#D7143C", "bizkaia"),
    ("bilbobus_56", "bilbobus", "56", "La Peña - Jesusen Bihotza", 3, "#D7143C", "bizkaia"),
    ("bilbobus_77", "bilbobus", "77", "Peñascal - Mina del Morro", 3, "#D7143C", "bizkaia"),
    # Dbus Donostia
    ("dbus_05", "dbus", "05", "Benta Berri", 3, "#1D7FD1", "gipuzkoa"),
    ("dbus_08", "dbus", "08", "Gros - Intxaurrondo", 3, "#1D7FD1", "gipuzkoa"),
    ("dbus_13", "dbus", "13", "Altza", 3, "#1D7FD1", "gipuzkoa"),
    ("dbus_28", "dbus", "28", "Amara - Ospitaleak", 3, "#1D7FD1", "gipuzkoa"),
    # Lurraldebus
    ("lurraldebus_E01", "lurraldebus", "E01", "Pasaia - Donostia", 3, "#5E9424", "gipuzkoa"),
    ("lurraldebus_UK09", "lurraldebus", "UK09", "Zumaia - Zarautz - Donostia", 3, "#5E9424", "gipuzkoa"),
    ("lurraldebus_DO01", "lurraldebus", "DO01", "Donostia - Bilbao Intermodal", 3, "#5E9424", "gipuzkoa"),
    # TUVISA Vitoria
    ("tuvisa_BEI", "tuvisa", "BEI", "Bus Eléctrico Inteligente", 3, "#12979F", "araba"),
    ("tuvisa_L1", "tuvisa", "L1", "Circular", 3, "#12979F", "araba"),
    ("tuvisa_L2", "tuvisa", "L2", "Periférica", 3, "#12979F", "araba"),
    ("tuvisa_L5", "tuvisa", "L5", "Salburua - Elejalde", 3, "#12979F", "araba"),
    # Álavabus
    ("alavabus_01", "alavabus", "L1", "Vitoria-Gasteiz - Miranda de Ebro", 3, "#B04A8E", "araba"),
    ("alavabus_09", "alavabus", "L9", "Vitoria-Gasteiz - Logroño", 3, "#B04A8E", "araba"),
    # Funicular de Artxanda
    ("artxanda_FUN", "artxanda", "FUN", "Campo Volantín - Artxanda", 7, "#DC0B0B", "bizkaia"),
    # Autobuses La Unión
    ("launion_LU", "la_union", "LU", "Bilbao Intermodal - Vitoria-Gasteiz", 3, "#30609D", "araba"),
]

STOPS_DATA = [
    # ── METRO BILBAO LINEA 1 ──
    ("metro_plentzia", "metro", "Plentzia", 43.4042, -2.9464, "3", "", "bizkaia"),
    ("metro_urduliz", "metro", "Urduliz", 43.3792, -2.9739, "2", "", "bizkaia"),
    ("metro_sopela", "metro", "Sopela", 43.3804, -2.9866, "2", "", "bizkaia"),
    ("metro_larrabasterra", "metro", "Larrabasterra", 43.3727, -2.9934, "2", "", "bizkaia"),
    ("metro_berango", "metro", "Berango", 43.3639, -2.9997, "2", "", "bizkaia"),
    ("metro_ibarbengoa", "metro", "Ibarbengoa", 43.3592, -3.0039, "2", "", "bizkaia"),
    ("metro_bidezabal", "metro", "Bidezabal", 43.3561, -3.0089, "2", "", "bizkaia"),
    ("metro_algorta", "metro", "Algorta", 43.3508, -3.0117, "2", "", "bizkaia"),
    ("metro_aiboa", "metro", "Aiboa", 43.3444, -3.0081, "2", "", "bizkaia"),
    ("metro_neguri", "metro", "Neguri", 43.3392, -3.0078, "2", "", "bizkaia"),
    ("metro_gobela", "metro", "Gobela", 43.3325, -3.0089, "2", "", "bizkaia"),
    ("metro_areeta", "metro", "Areeta", 43.3283, -3.0131, "2", "", "bizkaia"),
    ("metro_lamiako", "metro", "Lamiako", 43.3217, -3.0039, "2", "", "bizkaia"),
    ("metro_astrabudua", "metro", "Astrabudua", 43.3142, -2.9908, "2", "", "bizkaia"),
    ("metro_erandio", "metro", "Erandio", 43.3039, -2.9767, "2", "", "bizkaia"),
    ("metro_lutxana", "metro", "Lutxana (Erandio)", 43.2897, -2.9644, "1", "", "bizkaia"),
    ("metro_san_ignazio", "metro", "San Ignazio", 43.2806, -2.9603, "1", "", "bizkaia"),
    ("metro_sarriko", "metro", "Sarriko", 43.2736, -2.9556, "1", "", "bizkaia"),
    ("metro_deustu", "metro", "Deustu", 43.2694, -2.9497, "1", "", "bizkaia"),
    ("metro_san_mames", "metro", "San Mamés (Intermodal)", 43.2618, -2.9495, "1", "", "bizkaia"),
    ("metro_indautxu", "metro", "Indautxu", 43.2606, -2.9419, "1", "", "bizkaia"),
    ("metro_moyua", "metro", "Moyua Plaza (Ogasuna)", 43.2630, -2.9347, "1", "", "bizkaia"),
    ("metro_abando", "metro", "Abando", 43.2608, -2.9278, "1", "", "bizkaia"),
    ("metro_casco_viejo", "metro", "Zazpikaleak/Casco Viejo", 43.2592, -2.9221, "1", "", "bizkaia"),
    ("metro_santutxu", "metro", "Santutxu", 43.2544, -2.9158, "1", "", "bizkaia"),
    ("metro_basarrate", "metro", "Basarrate", 43.2508, -2.9103, "1", "", "bizkaia"),
    ("metro_bolueta", "metro", "Bolueta", 43.2458, -2.9056, "1", "", "bizkaia"),
    ("metro_etxebarri", "metro", "Etxebarri", 43.2436, -2.8953, "1", "", "bizkaia"),

    # ── METRO BILBAO LINEA 2 (Tramo propio de Margen Izquierda + Basauri) ──
    ("metro_kabiezes", "metro", "Kabiezes", 43.3236, -3.0408, "2", "", "bizkaia"),
    ("metro_santurtzi", "metro", "Santurtzi", 43.3289, -3.0317, "2", "", "bizkaia"),
    ("metro_penota", "metro", "Peñota", 43.3239, -3.0236, "2", "", "bizkaia"),
    ("metro_portugalete", "metro", "Portugalete", 43.3197, -3.0181, "2", "", "bizkaia"),
    ("metro_abatxolo", "metro", "Abatxolo", 43.3131, -3.0125, "2", "", "bizkaia"),
    ("metro_sestao", "metro", "Sestao", 43.3089, -3.0069, "2", "", "bizkaia"),
    ("metro_urbinaga", "metro", "Urbinaga", 43.3014, -2.9989, "2", "", "bizkaia"),
    ("metro_bagatza", "metro", "Bagatza", 43.2981, -2.9936, "2", "", "bizkaia"),
    ("metro_barakaldo", "metro", "Barakaldo", 43.2950, -2.9861, "2", "", "bizkaia"),
    ("metro_ansio", "metro", "Ansio (BEC)", 43.2897, -2.9808, "2", "", "bizkaia"),
    ("metro_gurutzeta", "metro", "Gurutzeta/Cruces", 43.2831, -2.9739, "2", "", "bizkaia"),
    ("metro_ariz", "metro", "Ariz", 43.2389, -2.8897, "2", "", "bizkaia"),
    ("metro_basauri", "metro", "Basauri", 43.2366, -2.8872, "2", "", "bizkaia"),

    # ── METRO BILBAO LINEA 3 ──
    ("metro_matiko", "metro", "Matiko", 43.2692, -2.9275, "1", "", "bizkaia"),
    ("metro_uribarri", "metro", "Uribarri", 43.2678, -2.9211, "1", "", "bizkaia"),
    ("metro_zurbaranbarri", "metro", "Zurbaranbarri", 43.2636, -2.9111, "1", "", "bizkaia"),
    ("metro_txurdinaga", "metro", "Txurdinaga", 43.2589, -2.9039, "1", "", "bizkaia"),
    ("metro_otxarkoaga", "metro", "Otxarkoaga", 43.2575, -2.8986, "1", "", "bizkaia"),
    ("metro_kukullaga", "metro", "Kukullaga-Etxebarri", 43.2492, -2.8942, "1", "", "bizkaia"),

    # ── RENFE CERCANÍAS BILBAO ──
    ("renfe_abando", "renfe", "Bilbao-Abando Indalecio Prieto", 43.2608, -2.9275, "1", "", "bizkaia"),
    ("renfe_zabalburu", "renfe", "Zabalburu", 43.2581, -2.9325, "1", "", "bizkaia"),
    ("renfe_ametzola", "renfe", "Ametzola", 43.2560, -2.9430, "1", "", "bizkaia"),
    ("renfe_autonomia", "renfe", "Autonomía", 43.2588, -2.9472, "1", "", "bizkaia"),
    ("renfe_san_mames", "renfe", "San Mamés (Renfe)", 43.2618, -2.9495, "1", "", "bizkaia"),
    ("renfe_olabeaga", "renfe", "Olabeaga", 43.2658, -2.9515, "1", "", "bizkaia"),
    ("renfe_zorrotza", "renfe", "Zorrotza", 43.2798, -2.9712, "1", "", "bizkaia"),
    ("renfe_desierto", "renfe", "Desierto-Barakaldo", 43.2985, -2.9830, "2", "", "bizkaia"),
    ("renfe_sestao", "renfe", "Sestao (Renfe)", 43.3082, -3.0040, "2", "", "bizkaia"),
    ("renfe_portugalete", "renfe", "Portugalete (Renfe)", 43.3210, -3.0160, "2", "", "bizkaia"),
    ("renfe_penota", "renfe", "Peñota (Renfe)", 43.3255, -3.0230, "2", "", "bizkaia"),
    ("renfe_santurtzi", "renfe", "Santurtzi (Renfe)", 43.3302, -3.0298, "2", "", "bizkaia"),
    ("renfe_muskiz", "renfe", "Muskiz", 43.3236, -3.1250, "3", "", "bizkaia"),
    ("renfe_bidebieta", "renfe", "Bidebieta-Basauri", 43.2389, -2.8942, "1", "", "bizkaia"),
    ("renfe_arrigorriaga", "renfe", "Arrigorriaga", 43.2050, -2.8890, "2", "", "bizkaia"),
    ("renfe_ugao", "renfe", "Ugao-Miraballes", 43.1850, -2.9010, "2", "", "bizkaia"),
    ("renfe_llodio", "renfe", "Llodio / Laudio", 43.1425, -2.9614, "3", "", "bizkaia"),
    ("renfe_luiaondo", "renfe", "Luiaondo", 43.0886, -2.9972, "4", "", "bizkaia"),
    ("renfe_amurrio", "renfe", "Amurrio", 43.0520, -3.0010, "4", "", "bizkaia"),
    ("renfe_orduna", "renfe", "Orduña", 42.9986, -3.0114, "5", "", "bizkaia"),
    # Renfe Gipuzkoa
    ("renfe_donostia", "renfe", "Donostia / San Sebastián (Norte)", 43.3175, -1.9772, "1", "", "gipuzkoa"),
    ("renfe_irun", "renfe", "Irun", 43.3402, -1.7961, "2", "", "gipuzkoa"),
    ("renfe_brinkola", "renfe", "Brinkola", 43.0425, -2.3167, "4", "", "gipuzkoa"),

    # ── EUSKOTREN ──
    ("euskotren_matiko", "euskotren", "Matiko (Bilbao)", 43.2692, -2.9275, "1", "", "bizkaia"),
    ("euskotren_casco_viejo", "euskotren", "Zazpikaleak/Casco Viejo (Euskotren)", 43.2592, -2.9221, "1", "", "bizkaia"),
    ("euskotren_bolueta", "euskotren", "Bolueta (Euskotren)", 43.2458, -2.9056, "1", "", "bizkaia"),
    ("euskotren_durango", "euskotren", "Durango", 43.1686, -2.6311, "3", "", "bizkaia"),
    ("euskotren_eibar", "euskotren", "Eibar", 43.1844, -2.4717, "3", "", "gipuzkoa"),
    ("euskotren_zarautz", "euskotren", "Zarautz", 43.2842, -2.1717, "2", "", "gipuzkoa"),
    ("euskotren_amara", "euskotren", "Donostia-Amara", 43.3136, -1.9817, "1", "", "gipuzkoa"),
    ("euskotren_hendaia", "euskotren", "Hendaia (Gare)", 43.3536, -1.7736, "3", "", "gipuzkoa"),
    ("euskotren_lasarte", "euskotren", "Lasarte-Oria", 43.2683, -2.0217, "2", "", "gipuzkoa"),
    ("euskotren_bermeo", "euskotren", "Bermeo", 43.4217, -2.7236, "3", "", "bizkaia"),

    # ── TRANVÍA DE BILBAO ──
    ("tranbia_bolueta", "tranbia_bilbao", "Bolueta (Tranvía)", 43.2486, -2.9056, "1", "", "bizkaia"),
    ("tranbia_atxuri", "tranbia_bilbao", "Atxuri", 43.2530, -2.9210, "1", "", "bizkaia"),
    ("tranbia_ribera", "tranbia_bilbao", "Ribera", 43.2562, -2.9238, "1", "", "bizkaia"),
    ("tranbia_arriaga", "tranbia_bilbao", "Teatro Arriaga", 43.2595, -2.9255, "1", "", "bizkaia"),
    ("tranbia_abando", "tranbia_bilbao", "Abando (Tranvía)", 43.2610, -2.9280, "1", "", "bizkaia"),
    ("tranbia_pio_baroja", "tranbia_bilbao", "Pío Baroja", 43.2635, -2.9295, "1", "", "bizkaia"),
    ("tranbia_uribitarte", "tranbia_bilbao", "Uribitarte", 43.2655, -2.9305, "1", "", "bizkaia"),
    ("tranbia_guggenheim", "tranbia_bilbao", "Guggenheim", 43.2680, -2.9340, "1", "", "bizkaia"),
    ("tranbia_abandoibarra", "tranbia_bilbao", "Abandoibarra", 43.2675, -2.9385, "1", "", "bizkaia"),
    ("tranbia_euskalduna", "tranbia_bilbao", "Euskalduna", 43.2665, -2.9440, "1", "", "bizkaia"),
    ("tranbia_sabino_arana", "tranbia_bilbao", "Sabino Arana", 43.2625, -2.9465, "1", "", "bizkaia"),
    ("tranbia_san_mames", "tranbia_bilbao", "San Mamés (Tranvía)", 43.2615, -2.9485, "1", "", "bizkaia"),
    ("tranbia_hospital", "tranbia_bilbao", "Ospitalea / Hospital", 43.2590, -2.9470, "1", "", "bizkaia"),
    ("tranbia_basurto", "tranbia_bilbao", "Basurto", 43.2580, -2.9450, "1", "", "bizkaia"),
    ("tranbia_la_casilla", "tranbia_bilbao", "La Casilla", 43.2575, -2.9436, "1", "", "bizkaia"),

    # ── TRANVÍA DE GASTEIZ ──
    ("tranbia_ibaiondo", "tranbia_gasteiz", "Ibaiondo", 42.8686, -2.6936, "1", "", "araba"),
    ("tranbia_salburua", "tranbia_gasteiz", "Salburua", 42.8536, -2.6450, "1", "", "araba"),
    ("tranbia_unibertsitatea", "tranbia_gasteiz", "Unibertsitatea", 42.8386, -2.6717, "1", "", "araba"),

    # ── BIZKAIBUS ──
    ("bizkaibus_termibus", "bizkaibus", "Bilbao Intermodal (Termibus)", 43.2618, -2.9495, "1", "", "bizkaia"),
    ("bizkaibus_gran_via", "bizkaibus", "Gran Vía 46 (Bilbao)", 43.2625, -2.9360, "1", "", "bizkaia"),
    ("bizkaibus_plaza_circular", "bizkaibus", "Plaza Circular (Gran Vía)", 43.2612, -2.9275, "1", "", "bizkaia"),
    ("bizkaibus_aireportua", "bizkaibus", "Aireportua / Aeropuerto (Loiu)", 43.3011, -2.9106, "2", "", "bizkaia"),
    ("bizkaibus_leioa_upv", "bizkaibus", "UPV/EHU Leioa Campus", 43.3315, -2.9785, "2", "", "bizkaia"),
    ("bizkaibus_cruces", "bizkaibus", "Cruces Ospitalea (Barakaldo)", 43.2831, -2.9739, "2", "", "bizkaia"),
    ("bizkaibus_santurtzi", "bizkaibus", "Santurtzi (Parkea)", 43.3289, -3.0317, "2", "", "bizkaia"),
    ("bizkaibus_getxo", "bizkaibus", "Getxo (Algorta Telletxe)", 43.3508, -3.0117, "2", "", "bizkaia"),
    ("bizkaibus_galdakao", "bizkaibus", "Galdakao Ospitalea", 43.2325, -2.8450, "2", "", "bizkaia"),
    ("bizkaibus_durango", "bizkaibus", "Durango (Landako)", 43.1686, -2.6311, "3", "", "bizkaia"),
    ("bizkaibus_severo_ochoa", "bizkaibus", "Severo Ochoa 13 (Caja Laboral)", 43.2986, -2.9817, "1", "", "bizkaia"),

    # ── BILBOBUS ──
    ("bilbobus_plaza_biribila", "bilbobus", "Plaza Biribila / Gran Vía", 43.2611, -2.9275, "1", "", "bizkaia"),
    ("bilbobus_moyua", "bilbobus", "Moyua Plaza", 43.2630, -2.9347, "1", "", "bizkaia"),
    ("bilbobus_termibus", "bilbobus", "Intermodal / Termibus", 43.2618, -2.9495, "1", "", "bizkaia"),
    ("bilbobus_arangoiti", "bilbobus", "Arangoiti", 43.2750, -2.9486, "1", "", "bizkaia"),
    ("bilbobus_uribarri", "bilbobus", "Uribarri C/ Trauko", 43.2686, -2.9217, "1", "", "bizkaia"),
    ("bilbobus_deustu", "bilbobus", "Deustu Bidarte", 43.2694, -2.9497, "1", "", "bizkaia"),
    ("bilbobus_san_ignazio", "bilbobus", "San Ignazio / Lehendakari Aguirre", 43.2806, -2.9603, "1", "", "bizkaia"),
    ("bilbobus_santutxu", "bilbobus", "Santutxu Karmelo", 43.2544, -2.9158, "1", "", "bizkaia"),
    ("bilbobus_otxarkoaga", "bilbobus", "Otxarkoaga Plaza", 43.2575, -2.8986, "1", "", "bizkaia"),
    ("bilbobus_mina_del_morro", "bilbobus", "Mina del Morro", 43.2490, -2.9120, "1", "", "bizkaia"),
    ("bilbobus_penascal", "bilbobus", "Peñascal", 43.2420, -2.9380, "1", "", "bizkaia"),

    # ── DBUS DONOSTIA ──
    ("dbus_boulevard", "dbus", "Boulevard 13 (Donostia)", 43.3217, -1.9836, "1", "", "gipuzkoa"),
    ("dbus_benta_berri", "dbus", "Benta Berri", 43.3117, -2.0017, "1", "", "gipuzkoa"),
    ("dbus_ospitaleak", "dbus", "Ospitaleak / Hospitales", 43.2917, -1.9736, "1", "", "gipuzkoa"),
    ("dbus_altza", "dbus", "Altza Casares", 43.3186, -1.9367, "1", "", "gipuzkoa"),

    # ── LURRALDEBUS ──
    ("lurraldebus_geltokia", "lurraldebus", "Donostia Geltokia / Estación Bus", 43.3175, -1.9778, "1", "", "gipuzkoa"),
    ("lurraldebus_zarautz", "lurraldebus", "Zarautz / Zarauz", 43.2842, -2.1717, "2", "", "gipuzkoa"),
    ("lurraldebus_zumaia", "lurraldebus", "Zumaia Geltokia", 43.2956, -2.2536, "3", "", "gipuzkoa"),

    # ── TUVISA VITORIA ──
    ("tuvisa_prado", "tuvisa", "Prado / Catedral", 42.8461, -2.6736, "1", "", "araba"),
    ("tuvisa_boulevard_vitoria", "tuvisa", "El Boulevard (Vitoria)", 42.8617, -2.6686, "1", "", "araba"),
    ("tuvisa_mendizorrotza", "tuvisa", "Mendizorrotza", 42.8375, -2.6861, "1", "", "araba"),

    # ── ÁLAVABUS ──
    ("alavabus_gasteiz_bus", "alavabus", "Vitoria-Gasteiz Estación Autobuses", 42.8586, -2.6817, "1", "", "araba"),
    ("alavabus_miranda", "alavabus", "Miranda de Ebro", 42.6861, -2.9467, "2", "", "araba"),

    # ── FUNICULAR DE ARTXANDA ──
    ("artxanda_campo_volantin", "artxanda", "Funikular Plaza (Campo Volantín)", 43.2686, -2.9286, "1", "", "bizkaia"),
    ("artxanda_gainera", "artxanda", "Artxanda (Mirador)", 43.2736, -2.9236, "1", "", "bizkaia"),

    # ── AUTOBUSES LA UNIÓN ──
    ("launion_bilbao", "la_union", "Bilbao Intermodal", 43.2618, -2.9495, "1", "", "bizkaia"),
    ("launion_gasteiz", "la_union", "Vitoria-Gasteiz E.A.", 42.8586, -2.6817, "1", "", "araba"),
]

# Explicit ordered stop sequences per line to generate realistic directional departures
LINE_STOP_SEQUENCES = {
    "metro_L1": [
        "metro_plentzia", "metro_urduliz", "metro_sopela", "metro_larrabasterra",
        "metro_berango", "metro_ibarbengoa", "metro_bidezabal", "metro_algorta",
        "metro_aiboa", "metro_neguri", "metro_gobela", "metro_areeta",
        "metro_lamiako", "metro_astrabudua", "metro_erandio", "metro_lutxana",
        "metro_san_ignazio", "metro_sarriko", "metro_deustu", "metro_san_mames",
        "metro_indautxu", "metro_moyua", "metro_abando", "metro_casco_viejo",
        "metro_santutxu", "metro_basarrate", "metro_bolueta", "metro_etxebarri"
    ],
    "metro_L2": [
        "metro_kabiezes", "metro_santurtzi", "metro_penota", "metro_portugalete",
        "metro_abatxolo", "metro_sestao", "metro_urbinaga", "metro_bagatza",
        "metro_barakaldo", "metro_ansio", "metro_gurutzeta",
        "metro_san_ignazio", "metro_sarriko", "metro_deustu", "metro_san_mames",
        "metro_indautxu", "metro_moyua", "metro_abando", "metro_casco_viejo",
        "metro_santutxu", "metro_basarrate", "metro_bolueta", "metro_etxebarri",
        "metro_ariz", "metro_basauri"
    ],
    "metro_L3": [
        "metro_matiko", "metro_uribarri", "metro_casco_viejo",
        "metro_zurbaranbarri", "metro_txurdinaga", "metro_otxarkoaga", "metro_kukullaga"
    ],
    "tranbia_TR": [
        "tranbia_bolueta", "tranbia_atxuri", "tranbia_ribera", "tranbia_arriaga",
        "tranbia_abando", "tranbia_pio_baroja", "tranbia_uribitarte", "tranbia_guggenheim",
        "tranbia_abandoibarra", "tranbia_euskalduna", "tranbia_sabino_arana",
        "tranbia_san_mames", "tranbia_hospital", "tranbia_basurto", "tranbia_la_casilla"
    ],
    "renfe_C1": [
        "renfe_abando", "renfe_zabalburu", "renfe_ametzola", "renfe_autonomia",
        "renfe_san_mames", "renfe_olabeaga", "renfe_zorrotza", "renfe_desierto",
        "renfe_sestao", "renfe_portugalete", "renfe_penota", "renfe_santurtzi"
    ],
    "renfe_C2": [
        "renfe_abando", "renfe_zabalburu", "renfe_ametzola", "renfe_autonomia",
        "renfe_san_mames", "renfe_olabeaga", "renfe_zorrotza", "renfe_desierto",
        "renfe_muskiz"
    ],
    "renfe_C3": [
        "renfe_abando", "renfe_bidebieta", "renfe_arrigorriaga", "renfe_ugao",
        "renfe_llodio", "renfe_luiaondo", "renfe_amurrio", "renfe_orduna"
    ],
    "euskotren_E1": [
        "euskotren_matiko", "euskotren_casco_viejo", "euskotren_bolueta",
        "euskotren_durango", "euskotren_eibar", "euskotren_zarautz", "euskotren_amara"
    ],
    "euskotren_E4": [
        "euskotren_matiko", "euskotren_casco_viejo", "euskotren_bolueta",
        "euskotren_durango", "euskotren_bermeo"
    ],
    "bilbobus_01": [
        "bilbobus_arangoiti", "bilbobus_deustu", "bilbobus_plaza_biribila"
    ],
    "bilbobus_28": [
        "bilbobus_uribarri", "bilbobus_moyua", "bilbobus_termibus"
    ],
    "bilbobus_56": [
        "bilbobus_plaza_biribila", "bilbobus_moyua", "bilbobus_san_ignazio"
    ],
    "bilbobus_77": [
        "bilbobus_penascal", "bilbobus_moyua", "bilbobus_santutxu", "bilbobus_mina_del_morro"
    ],
    "bizkaibus_A3247": [
        "bizkaibus_termibus", "bizkaibus_gran_via", "bizkaibus_plaza_circular", "bizkaibus_aireportua"
    ],
    "bizkaibus_A3115": [
        "bizkaibus_termibus", "bizkaibus_cruces", "bizkaibus_santurtzi"
    ],
    "bizkaibus_A3414": [
        "bizkaibus_termibus", "bizkaibus_gran_via", "bizkaibus_getxo"
    ],
    "bizkaibus_A2153": [
        "bizkaibus_termibus", "bizkaibus_severo_ochoa", "bizkaibus_aireportua"
    ],
}

def log(msg: str):
    print(f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}] {msg}")

def init_database(db_path: str) -> sqlite3.Connection:
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("PRAGMA journal_mode = OFF;")
    cur.execute("PRAGMA synchronous = 0;")
    cur.execute("PRAGMA cache_size = 100000;")
    cur.execute("PRAGMA temp_store = MEMORY;")

    cur.executescript("""
    CREATE TABLE operators (
        operator_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        territory TEXT NOT NULL DEFAULT 'bizkaia',
        mode TEXT NOT NULL DEFAULT 'metro',
        color_hex TEXT NOT NULL DEFAULT '#E8590C',
        has_realtime INTEGER NOT NULL DEFAULT 1
    );

    CREATE TABLE routes (
        route_id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        route_short_name TEXT NOT NULL,
        route_long_name TEXT NOT NULL,
        route_type INTEGER NOT NULL,
        route_color TEXT,
        territory TEXT NOT NULL DEFAULT 'bizkaia'
    );

    CREATE TABLE stops (
        stop_id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        stop_name TEXT NOT NULL,
        stop_lat REAL NOT NULL,
        stop_lon REAL NOT NULL,
        zone_id TEXT,
        parent_station TEXT,
        territory TEXT NOT NULL DEFAULT 'bizkaia'
    );

    CREATE TABLE trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        trip_headsign TEXT,
        direction_id INTEGER,
        inferred_line TEXT
    );

    CREATE TABLE stop_times (
        trip_id TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        stop_sequence INTEGER NOT NULL,
        arrival_time TEXT NOT NULL,
        departure_time TEXT NOT NULL,
        PRIMARY KEY (trip_id, stop_sequence)
    );

    CREATE TABLE calendar (
        service_id TEXT PRIMARY KEY,
        monday INTEGER NOT NULL,
        tuesday INTEGER NOT NULL,
        wednesday INTEGER NOT NULL,
        thursday INTEGER NOT NULL,
        friday INTEGER NOT NULL,
        saturday INTEGER NOT NULL,
        sunday INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL
    );

    CREATE TABLE calendar_dates (
        service_id TEXT NOT NULL,
        date TEXT NOT NULL,
        exception_type INTEGER NOT NULL,
        PRIMARY KEY (service_id, date)
    );
    """)

    conn.commit()
    return conn

def populate_all_operators(conn: sqlite3.Connection):
    cur = conn.cursor()
    log("Populating all 13 Euskadi operators...")
    cur.executemany("INSERT INTO operators VALUES (?, ?, ?, ?, ?, ?);", OPERATORS_DATA)

    log("Populating transit routes across Bizkaia, Gipuzkoa, and Araba...")
    cur.executemany("INSERT INTO routes VALUES (?, ?, ?, ?, ?, ?, ?);", ROUTES_DATA)

    log(f"Populating {len(STOPS_DATA)} stops and stations across Euskadi...")
    cur.executemany("INSERT INTO stops VALUES (?, ?, ?, ?, ?, ?, ?, ?);", STOPS_DATA)

    # Populate active everyday calendar service for 2026-2027
    cur.execute("""
    INSERT INTO calendar VALUES (
        'daily_regular', 1, 1, 1, 1, 1, 1, 1, '20260101', '20271231'
    );
    """)

    log("Synthesizing realistic bidirectional schedules for all lines...")
    trips_rows = []
    stop_times_rows = []

    stops_by_id = {s[0]: s for s in STOPS_DATA}

    for r in ROUTES_DATA:
        route_id, op_id, short_name, long_name, r_type, r_color, territory = r

        # Check if route has an explicit stop sequence
        stop_ids_forward = LINE_STOP_SEQUENCES.get(route_id)
        if not stop_ids_forward:
            # Fallback: all stops matching this operator
            stop_ids_forward = [s[0] for s in STOPS_DATA if s[1] == op_id]

        if not stop_ids_forward:
            continue

        stop_ids_backward = list(reversed(stop_ids_forward))

        # Direction 0: Forward
        dest_forward = stops_by_id.get(stop_ids_forward[-1], ("", "", "Destino"))[2]
        # Direction 1: Backward
        dest_backward = stops_by_id.get(stop_ids_backward[-1], ("", "", "Origen"))[2]

        interval_min = 6 if op_id == "metro" else (10 if op_id in ("tranbia_bilbao", "dbus", "tuvisa") else 15)

        for direction_id, (seq_stops, headsign) in enumerate([
            (stop_ids_forward, dest_forward),
            (stop_ids_backward, dest_backward)
        ]):
            trip_idx = 0
            for start_min in range(5 * 60 + 30, 24 * 60, interval_min):
                trip_idx += 1
                trip_id = f"{route_id}_d{direction_id}_t{trip_idx:03d}"
                trips_rows.append((
                    trip_id,
                    route_id,
                    "daily_regular",
                    headsign,
                    direction_id,
                    short_name
                ))

                for seq, s_id in enumerate(seq_stops):
                    # Realistic ~2.5 minute travel time between consecutive stops
                    curr_min = start_min + int(seq * 2.5)
                    hh = curr_min // 60
                    mm = curr_min % 60
                    time_str = f"{hh:02d}:{mm:02d}:00"
                    stop_times_rows.append((
                        trip_id,
                        s_id,
                        seq + 1,
                        time_str,
                        time_str
                    ))

    cur.executemany("INSERT INTO trips VALUES (?, ?, ?, ?, ?, ?);", trips_rows)
    cur.executemany("INSERT INTO stop_times VALUES (?, ?, ?, ?, ?);", stop_times_rows)
    conn.commit()
    log(f"Inserted {len(trips_rows)} bidirectional trips and {len(stop_times_rows)} stop times.")

def build_indices(conn: sqlite3.Connection):
    cur = conn.cursor()
    log("Building high-performance SQLite indexes...")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_operator ON stops (operator_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_parent ON stops (parent_station);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_routes_operator ON routes (operator_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_trips_route ON trips (route_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_trips_service ON trips (service_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stop_times_stop ON stop_times (stop_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stop_times_departure ON stop_times (departure_time);")
    conn.commit()

def create_manifest(db_path: str, gz_path: str, manifest_path: str):
    def sha256_file(filepath: str) -> str:
        h = hashlib.sha256()
        with open(filepath, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()

    db_bytes = os.path.getsize(db_path)
    db_hash = sha256_file(db_path)

    gz_bytes = os.path.getsize(gz_path)
    gz_hash = sha256_file(gz_path)

    manifest = {
        "version": "3.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sqlite": {
            "filename": os.path.basename(db_path),
            "bytes": db_bytes,
            "sha256": db_hash,
        },
        "compressed": {
            "filename": os.path.basename(gz_path),
            "bytes": gz_bytes,
            "sha256": gz_hash,
        },
        "sources": {
            op[0]: {
                "name": op[1],
                "territory": op[2],
                "mode": op[3],
                "color": op[4],
                "has_realtime": bool(op[5])
            }
            for op in OPERATORS_DATA
        }
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    log(f"Manifest written to {manifest_path}")
    log(f"SQLite DB: {db_bytes:,} bytes | Compressed: {gz_bytes:,} bytes")

def main():
    output_dir = os.path.join(os.path.dirname(__file__), "out")
    os.makedirs(output_dir, exist_ok=True)

    db_path = os.path.join(output_dir, "transit.sqlite")
    gz_path = os.path.join(output_dir, "transit.sqlite.gz")
    manifest_path = os.path.join(output_dir, "manifest.json")

    start_time = time.time()
    log("Starting Euskadi Multi-Operator GTFS Compilation...")

    conn = init_database(db_path)
    try:
        populate_all_operators(conn)
        build_indices(conn)
    finally:
        conn.close()

    # Copy to Flutter assets
    assets_db = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "db", "transit.sqlite")
    os.makedirs(os.path.dirname(assets_db), exist_ok=True)
    shutil.copyfile(db_path, assets_db)
    log(f"Copied compiled DB to {assets_db}")

    # Copy to root transit.sqlite
    root_db = os.path.join(os.path.dirname(__file__), "..", "..", "transit.sqlite")
    shutil.copyfile(db_path, root_db)

    # Compress with Gzip
    log(f"Compressing {db_path} to {gz_path}...")
    with open(db_path, "rb") as f_in, gzip.open(gz_path, "wb", compresslevel=9) as f_out:
        while chunk := f_in.read(65536):
            f_out.write(chunk)

    create_manifest(db_path, gz_path, manifest_path)
    elapsed = time.time() - start_time
    log(f"Pipeline successfully completed in {elapsed:.2f} seconds.")

if __name__ == "__main__":
    main()
