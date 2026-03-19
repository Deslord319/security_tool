from scripts.e2e.core.adapter import AdapterConfig
from scripts.e2e.adapters.security_tool.resolvers import list_registered_pages


ADAPTER_CONFIG = AdapterConfig(
    project_id="security_tool",
    adapter_name="security_tool",
    adapter_version="1.0.0",
    bundle_name="com.huawei.securitytool",
    mode="completeness",
    main_ability="EntryAbility",
    admin_ability="EnterpriseAdminAbility",
    cases_dir="scripts/e2e/cases",
    page_registry_version="2026-03-12",
    notes=[
        "This adapter is the reference implementation inside the business repository.",
        "The structure is designed so core modules can be extracted into a standalone repository later.",
        f"Registered pages: {', '.join(list_registered_pages())}",
    ],
)
