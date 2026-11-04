#!/usr/bin/env python3
"""
Barik Transit — Multi-Operator GTFS Static Schedule Compiler
=============================================================
Compiles official Moveuskadi GTFS Static feeds for all transport operators
across Bizkaia, Gipuzkoa, and Araba into a compact, indexed SQLite database
(transit.sqlite), compresses it (transit.sqlite.gz), and generates manifest.json.
"""

import sys
import os

# Delegate directly to compile_all_gtfs
sys.path.insert(0, os.path.dirname(__file__))
from compile_all_gtfs import main

if __name__ == "__main__":
    main()
