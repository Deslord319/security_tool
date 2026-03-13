from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class AdapterConfig:
    project_id: str
    adapter_name: str
    adapter_version: str
    bundle_name: str
    mode: str = "completeness"
    main_ability: str = "EntryAbility"
    admin_ability: str = "EnterpriseAdminAbility"
    cases_dir: str = "scripts/e2e/cases"
    page_registry_version: str = "2026-03-12"
    notes: list[str] = field(default_factory=list)

    def resolve_cases_dir(self, project_root: Path) -> Path:
        return project_root / self.cases_dir
