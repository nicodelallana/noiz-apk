"""Base processor interface and validation reporting structures."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


@dataclass
class ValidationError:
    """Individual validation failure in an ingestion resource."""
    record_type: str
    record_identifier: str
    error_message: str
    raw_data: Optional[Dict[str, Any]] = None


@dataclass
class ValidationReport:
    """Consolidated validation report for an ingestion job."""
    resource_format: str
    total_records: int = 0
    valid_records: int = 0
    rejected_records: int = 0
    status: str = "pending"  # 'passed', 'warnings', 'failed'
    errors: List[ValidationError] = field(default_factory=list)
    metrics: Dict[str, Any] = field(default_factory=dict)
    started_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    completed_at: Optional[datetime] = None

    def mark_completed(self, status: Optional[str] = None):
        self.completed_at = datetime.now(timezone.utc)
        if status:
            self.status = status
        elif self.rejected_records == 0:
            self.status = "passed"
        elif self.valid_records > 0:
            self.status = "warnings"
        else:
            self.status = "failed"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "resource_format": self.resource_format,
            "total_records": self.total_records,
            "valid_records": self.valid_records,
            "rejected_records": self.rejected_records,
            "status": self.status,
            "error_count": len(self.errors),
            "errors": [
                {
                    "type": e.record_type,
                    "id": e.record_identifier,
                    "msg": e.error_message
                }
                for e in self.errors[:50]  # Cap error list in report
            ],
            "metrics": self.metrics,
            "duration_ms": int((self.completed_at - self.started_at).total_seconds() * 1000) if self.completed_at else 0
        }


class BaseProcessor(ABC):
    """Abstract base class for all transport format processors."""

    @abstractmethod
    def process(self, file_path: str, context: Dict[str, Any]) -> ValidationReport:
        """Processes the resource and returns a validation report."""
        pass
