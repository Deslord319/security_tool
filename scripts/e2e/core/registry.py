from __future__ import annotations

from typing import Type

from .adapter import AdapterConfig

SUPPORTED_ADAPTERS = {
    "security_tool": "scripts.e2e.adapters.security_tool",
}


def load_adapter(name: str) -> AdapterConfig:
    return _load_adapter_attr(name, "ADAPTER_CONFIG")


def load_adapter_suite(name: str, suite_name: str) -> list[str]:
    suites = _load_adapter_attr(name, "SUITES")
    if suite_name not in suites:
        raise RuntimeError(f"Unsupported suite '{suite_name}' for adapter '{name}'")
    return suites[suite_name]


def load_adapter_flow_executor(name: str) -> Type[object]:
    return _load_adapter_attr(name, "SecurityToolFlowExecutor")


def list_adapter_suites(name: str) -> list[str]:
    suites = _load_adapter_attr(name, "SUITES")
    return sorted(suites.keys())


def _load_adapter_attr(name: str, attr_name: str):
    module_name = SUPPORTED_ADAPTERS.get(name)
    if not module_name:
        raise RuntimeError(f"Unsupported adapter: {name}")
    module = __import__(module_name, fromlist=[attr_name])
    return getattr(module, attr_name)
