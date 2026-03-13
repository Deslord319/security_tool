from __future__ import annotations

from typing import Type

from .adapter import AdapterConfig


def load_adapter(name: str) -> AdapterConfig:
    if name == "security_tool":
        from scripts.e2e.adapters.security_tool import ADAPTER_CONFIG

        return ADAPTER_CONFIG
    raise RuntimeError(f"Unsupported adapter: {name}")


def load_adapter_suite(name: str, suite_name: str) -> list[str]:
    if name == "security_tool":
        from scripts.e2e.adapters.security_tool import SUITES

        if suite_name not in SUITES:
            raise RuntimeError(f"Unsupported suite '{suite_name}' for adapter '{name}'")
        return SUITES[suite_name]
    raise RuntimeError(f"Unsupported adapter: {name}")


def load_adapter_flow_registry(name: str) -> dict[str, dict[str, object]]:
    if name == "security_tool":
        from scripts.e2e.adapters.security_tool import FLOW_REGISTRY

        return FLOW_REGISTRY
    raise RuntimeError(f"Unsupported adapter: {name}")


def load_adapter_flow_executor(name: str) -> Type[object]:
    if name == "security_tool":
        from scripts.e2e.adapters.security_tool import SecurityToolFlowExecutor

        return SecurityToolFlowExecutor
    raise RuntimeError(f"Unsupported adapter: {name}")


def list_adapter_suites(name: str) -> list[str]:
    if name == "security_tool":
        from scripts.e2e.adapters.security_tool import SUITES

        return sorted(SUITES.keys())
    raise RuntimeError(f"Unsupported adapter: {name}")
