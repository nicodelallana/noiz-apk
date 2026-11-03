"""Command line interface for Moveuskadi ingestion platform."""

import argparse
import sys
import uvicorn
from rich.console import Console
from rich.table import Table

from src.catalog.discovery import CatalogueDiscoveryService
from src.config import settings
from src.downloader.manager import DownloadManager
from src.normalizer.pipeline import IngestionPipeline
from src.processors.shp import ShapefileProcessor
from src.utils.logging import logger

console = Console()


def cmd_discover():
    """Discovers and displays the Moveuskadi JSON index."""
    console.print("[bold blue]Starting Moveuskadi Catalogue Discovery...[/bold blue]")
    discovery = CatalogueDiscoveryService()
    snapshot, catalogs = discovery.fetch_catalogue()

    table = Table(title=f"Moveuskadi Discovered Operators ({snapshot.total_operators} Operators, {snapshot.total_resources} Resources)")
    table.add_column("Operator Name", style="bold green")
    table.add_column("Slug", style="cyan")
    table.add_column("Formats", style="magenta")
    table.add_column("Count", justify="right")

    for op in sorted(catalogs.values(), key=lambda x: x.original_name):
        table.add_row(
            op.original_name,
            op.slug,
            ", ".join(op.available_formats),
            str(len(op.resources))
        )

    console.print(table)


def cmd_import_boundaries():
    """Downloads and imports official GeoEuskadi territorial boundaries."""
    console.print("[bold green]Downloading GeoEuskadi Territorial Boundaries (TERRITORIOS_5000_ETRS89)...[/bold green]")
    dm = DownloadManager()
    res = dm.download_resource(
        url=settings.GEOEUSKADI_TERRITORIOS_URL,
        target_filename="TERRITORIOS_5000_ETRS89.zip",
        expected_format="SHP",
        subfolder="boundaries"
    )
    if not res.success:
        console.print(f"[red]Failed downloading boundaries: {res.error_message}[/red]")
        sys.exit(1)

    console.print(f"[green]Downloaded: {res.file_path} ({res.file_size_bytes} bytes)[/green]")
    shp = ShapefileProcessor()
    count = shp.import_euskadi_territorial_boundaries(res.file_path)
    console.print(f"[bold green]Imported {count} territorial boundaries into PostGIS.[/bold green]")


def cmd_run_api():
    """Starts the FastAPI monitoring server."""
    console.print(f"[bold cyan]Starting API server on {settings.API_HOST}:{settings.API_PORT}...[/bold cyan]")
    uvicorn.run("src.api.app:app", host=settings.API_HOST, port=settings.API_PORT, reload=False)


def main():
    parser = argparse.ArgumentParser(description="Moveuskadi Transport Ingestion Platform CLI")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    subparsers.add_parser("discover", help="Discover and display live Moveuskadi operators and resources")
    subparsers.add_parser("import-boundaries", help="Download and import GeoEuskadi territorial boundaries into PostGIS")
    subparsers.add_parser("run-api", help="Start the FastAPI monitoring server")
    subparsers.add_parser("run-all", help="Start FastAPI monitoring server with automated scheduler")

    args = parser.parse_args()

    if args.command == "discover":
        cmd_discover()
    elif args.command == "import-boundaries":
        cmd_import_boundaries()
    elif args.command in ("run-api", "run-all"):
        cmd_run_api()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
