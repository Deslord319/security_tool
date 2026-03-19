from __future__ import annotations

import copy
from typing import Any

from scripts.e2e.adapters.security_tool.action_templates import ACTION_TEMPLATES


class TemplateRuntimeMixin:
    async def _execute_template_action(self, payload: dict[str, Any]) -> dict[str, Any]:
        params = payload.get("params", {})
        template_key = str(params.get("template_key", "")).strip()
        template = ACTION_TEMPLATES.get(template_key)
        if not template:
            return self._unknown(payload, "MCP_ACTION_PENDING", f"Template not defined: {template_key}")

        context = {
            "template_key": template_key,
            "operation_ref": params.get("operation_ref", ""),
            "domain": params.get("domain", ""),
            "entity": params.get("entity", ""),
            "action": params.get("action", ""),
            "variant": params.get("variant", ""),
            "data": dict(params.get("data", {})),
        }
        step_evidence: list[dict[str, Any]] = []
        for index, step in enumerate(template.get("sequence", []), start=1):
            step_result = await self._run_template_step(step, context)
            step_result_evidence = copy.deepcopy(step_result.get("evidence", {}))
            step_evidence.append(
                {
                    "index": index,
                    "type": step.get("type", ""),
                    "handler": step.get("handler", ""),
                    "status": step_result.get("status", "UNKNOWN"),
                    "message": step_result.get("message", ""),
                    "evidence": step_result_evidence,
                }
            )
            if step_result.get("status") != "PASS":
                failure_evidence = copy.deepcopy(step_result.get("evidence", {}))
                failure_evidence["template_key"] = template_key
                failure_evidence["template_steps"] = step_evidence
                return {
                    **step_result,
                    "evidence": failure_evidence,
                }

        return self._pass(
            template.get("description", "Template action executed"),
            {
                "template_key": template_key,
                "operation_ref": context["operation_ref"],
                "template_steps": step_evidence,
            },
        )

    async def _run_template_step(self, step: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
        step_type = str(step.get("type", "")).strip()
        params = self._resolve_template_value(step.get("params", {}), context)

        if step_type == "toggle_first_on_page":
            return await self._toggle_first_toggle({"params": params}, page_text=str(params.get("page_text", "")))

        if step_type == "save_tool_settings":
            return await self._save_tool_settings({"params": params})

        if step_type == "open_firewall_rules_page":
            return await self._open_firewall_rules_page(str(params.get("rule_type", "")))

        if step_type == "open_named_dialog":
            labels = [str(label) for label in params.get("labels", []) if str(label).strip()]
            return await self._open_named_dialog(
                {"params": params},
                labels=labels,
                dialog_key=str(params.get("dialog_key", "")).strip(),
            )

        if step_type == "fill_inputs":
            values = [str(value) for value in params.get("values", [])]
            return await self._fill_text_inputs(values, field_group=str(params.get("field_group", "")).strip())

        if step_type == "fill_inputs_with_fallback_touch":
            values = [str(value) for value in params.get("values", [])]
            fill_result = await self._fill_text_inputs(values, field_group=str(params.get("field_group", "")).strip())
            if fill_result.get("status") == "PASS":
                return self._pass("Template inputs populated", {"fill": fill_result.get("evidence", {}), "values": values})
            action_result = await self._touch_identity_controls()
            if action_result.get("status") != "PASS":
                return fill_result
            return self._pass("Template fallback controls interacted", {"values": values, "interaction": action_result.get("evidence", {})})

        if step_type == "confirm_dialog":
            return await self._confirm_dialog(allow_cancel=bool(params.get("allow_cancel", True)))

        if step_type == "submit_firewall_rule_form":
            return await self._submit_firewall_rule_form(params)

        if step_type == "toggle_indexed_control":
            return await self._toggle_indexed_control(
                control_type=str(params.get("control_type", "Toggle")),
                index=int(params.get("index", 0)),
                feature=str(params.get("feature", "")),
            )

        if step_type == "select_indexed_option":
            return await self._select_indexed_option(
                index=int(params.get("index", 0)),
                value=str(params.get("value", "")),
                option_group=str(params.get("option_group", "")).strip(),
                options=params.get("options", {}) if isinstance(params.get("options", {}), dict) else {},
            )

        if step_type == "wait_for_text":
            text = str(params.get("text", "")).strip()
            wait_result = await self._wait_for(
                [{"text": text, "bundle_name": str(params.get("bundle_name", "com.huawei.securitytool"))}],
                timeout_sec=float(params.get("timeout_sec", 5.0)),
            )
            if not wait_result.get("ok", False):
                return self._unknown({"action": "execute_template_action", "params": context}, "MCP_ACTION_PENDING", f"Template wait_for_text did not resolve: {text}")
            return self._pass("Template text condition satisfied", {"text": text, "match": wait_result.get("match", {})})

        if step_type == "assert_text_visible":
            candidates = [str(item) for item in params.get("candidates", []) if str(item).strip()]
            return await self._assert_any_text_visible(candidates, timeout_sec=float(params.get("timeout_sec", 2.5)))

        if step_type == "delete_visible_rule":
            return await self._delete_visible_rule(
                target=str(params.get("target", "")),
                fallback_target=str(params.get("fallback_target", "")),
            )

        if step_type == "capture_screenshot":
            return await self._capture_screenshot(params)

        return self._unknown({"action": "execute_template_action", "params": context}, "MCP_ACTION_PENDING", f"Unsupported template step type: {step_type}")

    def _resolve_template_value(self, value: Any, context: dict[str, Any]) -> Any:
        if isinstance(value, str):
            if value.startswith("${") and value.endswith("}"):
                return self._lookup_template_path(value[2:-1], context)
            return value
        if isinstance(value, list):
            return [self._resolve_template_value(item, context) for item in value]
        if isinstance(value, dict):
            return {key: self._resolve_template_value(item, context) for key, item in value.items()}
        return value

    def _lookup_template_path(self, path: str, context: dict[str, Any]) -> Any:
        current: Any = context
        for part in path.split("."):
            if isinstance(current, dict):
                current = current.get(part)
            else:
                return ""
        return current
