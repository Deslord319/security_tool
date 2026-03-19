from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class PageDescriptor:
    page_id: str
    page_text: str
    marker_text: str


@dataclass(frozen=True)
class DialogDescriptor:
    dialog_key: str
    labels: tuple[str, ...]
    region: dict[str, int] = field(default_factory=dict)


@dataclass(frozen=True)
class OptionDescriptor:
    option_group: str
    option_key: str
    labels: tuple[str, ...]


@dataclass(frozen=True)
class FieldDescriptor:
    field_group: str
    field_keys: tuple[str, ...]


LOCAL_ONLY_FLOW_REFS = frozenset({"app.launch"})
