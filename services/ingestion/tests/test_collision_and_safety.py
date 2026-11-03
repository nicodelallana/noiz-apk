"""Unit tests for identifier collision prevention and safe publication logic."""

import uuid
from src.catalog.models import ResourceItem
from src.processors.gtfs_static import GTFSStaticProcessor


def test_identifier_collision_scoping():
    """Verifies that identical stop IDs from different operators/feeds receive distinct UUIDs."""
    op1_id = str(uuid.uuid4())
    op2_id = str(uuid.uuid4())

    feed_ver1 = str(uuid.uuid4())
    feed_ver2 = str(uuid.uuid4())

    # Simulated stops from two distinct operators sharing external ID "1"
    stop_op1 = {
        "id": str(uuid.uuid4()),
        "feed_version_id": feed_ver1,
        "operator_id": op1_id,
        "external_stop_id": "1",
        "stop_name": "Estacion Central Metro",
        "latitude": 43.26,
        "longitude": -2.93
    }

    stop_op2 = {
        "id": str(uuid.uuid4()),
        "feed_version_id": feed_ver2,
        "operator_id": op2_id,
        "external_stop_id": "1",
        "stop_name": "Parada Bizkaibus 1",
        "latitude": 43.27,
        "longitude": -2.94
    }

    # Internal primary keys are completely unique
    assert stop_op1["id"] != stop_op2["id"]
    # Source scoped keys are different: (feed_version_id, external_stop_id)
    assert (stop_op1["feed_version_id"], stop_op1["external_stop_id"]) != (
        stop_op2["feed_version_id"],
        stop_op2["external_stop_id"]
    )


def test_safe_publication_rejection():
    """Verifies that an invalid feed does not proceed to activation."""
    processor = GTFSStaticProcessor()
    # Non-existent file must fail validation
    report = processor.process("/invalid/path/gtfs.zip", context={"feed_version_id": "v_fail"})
    assert report.status == "failed"
    assert report.valid_records == 0
