export class FirewallModeSwitchErrorStrings {
  static readonly SNAPSHOT_FAILED: string = 'mode switch snapshot failed'
  static readonly READ_PREVIOUS_POLICY_FAILED: string = 'read previous policy failed'
  static readonly CLEAR_LOCAL_DEPLOYMENTS_FAILED: string = 'clear local deployments failed'
  static readonly ADD_RULE_FAILED: string = 'add rule failed'
  static readonly SAVE_DEPLOYMENTS_FAILED: string = 'save deployments failed'
  static readonly SAVE_TARGET_MODE_FAILED: string = 'save target mode failed'
  static readonly COMPLETED_WITH_FAILED_ITEMS: string = 'mode switch completed with failed items'
  static readonly ROLLBACK_CLEAR_CURRENT_RULES_FAILED: string = 'rollback clear current rules failed'
  static readonly ROLLBACK_POLICY_FAILED: string = 'rollback policy failed'
  static readonly ROLLBACK_RESTORE_RULE_FAILED: string = 'rollback restore rule failed'
  static readonly ROLLBACK_LOCAL_DEPLOYMENTS_FAILED: string = 'rollback local deployments failed'
  static readonly ROLLBACK_CURRENT_MODE_FAILED: string = 'rollback current mode failed'
}

export class FirewallPolicyErrorStrings {
  static readonly READ_POLICY_FAILED: string = 'read policy failed'
  static readonly SET_POLICY_FAILED: string = 'set policy failed'
  static readonly READ_MODE_POLICY_FAILED: string = 'read mode policy failed'
  static readonly SET_MODE_POLICY_FAILED: string = 'set mode policy failed'
  static readonly POLICY_APPLY_FAILED: string = 'policy apply failed'
  static readonly SAVE_USER_POLICY_MODE_FAILED: string = 'save user policy mode failed'
}

export class FirewallRuleMutationErrorStrings {
  static readonly RULE_INTENT_NOT_FOUND: string = 'rule intent not found'
  static readonly UPDATE_FAILED_WHILE_REMOVING_OLD_DEPLOYMENTS: string = 'update rule failed while removing old deployments'
  static readonly LOCAL_SAVE_FAILED: string = 'local save failed'
  static readonly RULE_UPDATED_WITH_FAILED_ITEMS: string = 'rule updated with failed items'
  static readonly DELETE_RULE_COMPLETED_WITH_FAILED_ITEMS: string = 'delete rule completed with failed items'
  static readonly REMOVE_RULE_INTENT_FAILED: string = 'remove rule intent failed'
  static readonly CONFLICT_RULE_INTENT_NOT_FOUND: string = 'conflict rule intent not found'
  static readonly TARGET_RULE_INTENT_NOT_FOUND: string = 'target rule intent not found'
  static readonly REPLACE_FAILED_AND_RESTORE_OLD_FAILED: string = 'replace conflict rule failed and restore old rule failed'
  static readonly REPLACE_FAILED_AND_RESTORED_OLD: string = 'replace conflict rule failed and restored old rule'
  static readonly RULE_CREATED_WITH_FAILED_ITEMS: string = 'rule created with failed items'
  static readonly RESTORE_OLD_INTENT_FAILED: string = 'restore old intent failed'
  static readonly RESTORE_TARGET_INTENT_FAILED: string = 'restore target intent failed'
  static readonly ROLLBACK_NEW_SYSTEM_RULE_FAILED: string = 'rollback new system rule failed'
  static readonly ROLLBACK_UPDATED_SYSTEM_RULE_FAILED: string = 'rollback updated system rule failed'
  static readonly ROLLBACK_SYSTEM_RULE_FAILED: string = 'rollback system rule failed'
  static readonly ROLLBACK_LOCAL_DEPLOYMENTS_FAILED: string = 'rollback local deployments failed'
  static readonly ROLLBACK_LOCAL_INTENT_FAILED: string = 'rollback local intent failed'
}

export class FirewallRuleDeploymentErrorStrings {
  static readonly ADD_RULE_FAILED: string = 'add rule failed'
  static readonly REMOVE_SYSTEM_RULE_FAILED: string = 'remove system rule failed'
  static readonly RESTORE_OLD_SYSTEM_RULE_FAILED: string = 'restore old system rule failed'
  static readonly RESTORE_OLD_DEPLOYMENTS_FAILED: string = 'restore old deployments failed'
  static readonly PRESERVE_FAILED_DEPLOYMENTS_FAILED: string = 'preserve failed deployments failed'
  static readonly REMOVE_DEPLOYMENTS_FAILED: string = 'remove deployments failed'
}

export class FirewallRuleValidationErrorStrings {
  static readonly RULE_NAME_REQUIRED: string = 'rule name is required'
  static readonly TARGET_USERS_REQUIRED: string = 'target users are required'
  static readonly DOMAIN_REQUIRED: string = 'domain rule requires domain'
  static readonly DNS_REQUIRED: string = 'dns rule requires primary dns'
}

export class FirewallSystemErrorStrings {
  static readonly MISSING_SYSTEM_RULE_ID: string = 'missing system rule id'
}
