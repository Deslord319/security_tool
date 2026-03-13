from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from .adapter import AdapterConfig
from .models import EnvironmentSnapshot


@dataclass(frozen=True)
class ExecutionContext:
    project_root: Path
    output_dir: Path
    adapter: AdapterConfig
    device_id: str | None
    dry_run: bool

    def placeholder_map(self) -> dict[str, str]:
        return {
            "device_id": self.device_id or "",
            "bundle_name": self.adapter.bundle_name,
            "project_root": str(self.project_root),
            "main_ability": self.adapter.main_ability,
            "admin_ability": self.adapter.admin_ability,
            "adapter_name": self.adapter.adapter_name,
            "project_id": self.adapter.project_id,
        }

    def environment_snapshot(self, *, connected: bool, extras: dict[str, Any] | None = None) -> dict[str, Any]:
        snapshot = asdict(
            EnvironmentSnapshot(
                project_id=self.adapter.project_id,
                adapter_name=self.adapter.adapter_name,
                adapter_version=self.adapter.adapter_version,
                bundle_name=self.adapter.bundle_name,
                device_id=self.device_id,
                mode=self.adapter.mode,
                connected=connected,
            )
        )
        snapshot["page_registry_version"] = self.adapter.page_registry_version
        if extras:
            snapshot.update(extras)
        return snapshot
