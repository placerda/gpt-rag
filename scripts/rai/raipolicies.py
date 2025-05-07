#!/usr/bin/env python3
import os
import sys
import json
import logging

from azure.identity import (
    AzureCliCredential,
    ManagedIdentityCredential,
    ChainedTokenCredential
)
from azure.appconfiguration import AzureAppConfigurationClient
from azure.mgmt.cognitiveservices import CognitiveServicesManagementClient
from azure.mgmt.cognitiveservices.models import (
    RaiBlocklist,
    RaiBlocklistProperties,
    RaiBlocklistItem,
    RaiBlocklistItemProperties
)

# ── configure logging ─────────────────────────────────────────
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.mgmt"
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

# ── Only need App Config endpoint from environment ──────────────────────────
REQUIRED_ENV_VARS = [
    "AZURE_APP_CONFIG_ENDPOINT"
]

def check_env():
    missing = [v for v in REQUIRED_ENV_VARS if not os.getenv(v)]
    if missing:
        logging.error("Missing environment variables:")
        for name in missing:
            logging.error("  • %s", name)
        sys.exit(1)


def load_and_replace(path: str, replacements: dict) -> dict:
    try:
        raw = open(path, "r", encoding="utf-8").read()
    except OSError as e:
        logging.error("Unable to open %s: %s", path, e)
        sys.exit(1)

    for ph, val in replacements.items():
        raw = raw.replace(ph, val)

    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        logging.error("Failed to parse JSON in %s: %s", path, e)
        sys.exit(1)


def main():
    check_env()

    app_config_endpoint = os.environ["AZURE_APP_CONFIG_ENDPOINT"]

    # authenticate using CLI or Managed Identity
    cred = ChainedTokenCredential(
        AzureCliCredential(),
        ManagedIdentityCredential()
    )

    # ── 1) Fetch PROVISION_CONFIG from App Configuration ──────────────────────
    app_conf_client = AzureAppConfigurationClient(app_config_endpoint, cred)
    try:
        setting = app_conf_client.get_configuration_setting(key="PROVISION_CONFIG")
        provision_config = json.loads(setting.value)
    except Exception as e:
        logging.error("Could not load/parse PROVISION_CONFIG from App Configuration: %s", e)
        sys.exit(1)

    # ── 2) Extract core settings from PROVISION_CONFIG ───────────────────────
    try:
        subscription_id   = provision_config["AZURE_SUBSCRIPTION_ID"]
        resource_group    = provision_config["AZURE_RESOURCE_GROUP"]
        account_name      = provision_config["AZURE_OPENAI_SERVICE_NAME"]
        deployment_name   = provision_config["AZURE_CHAT_DEPLOYMENT_NAME"]
        logging.info(
            "Loaded: SUBSCRIPTION_ID=%s, RESOURCE_GROUP=%s", subscription_id, resource_group
        )
        logging.info(
            "Loaded: SERVICE_NAME=%s, CHAT_DEPLOYMENT=%s", account_name, deployment_name
        )
    except KeyError as e:
        logging.error("Missing key in PROVISION_CONFIG: %s", e)
        sys.exit(1)

    # ── 3) Create Cognitive Services client ──────────────────────────────────
    client = CognitiveServicesManagementClient(cred, subscription_id)

    # names for resources
    blocklist_name = "gptragBlocklist"
    policy_name    = "gptragRAIPolicy"

    # ── 4) Blocklist creation/update ─────────────────────────────────────────
    bl_def = load_and_replace(
        "scripts/rai/raiblocklist.json",
        {"{{BlocklistName}}": blocklist_name}
    )
    bl_name = bl_def.get("name") or bl_def.get("blocklistname")
    if not bl_name:
        logging.error("Blocklist JSON must have top-level 'name' or 'blocklistname'.")
        sys.exit(1)

    logging.info("Creating/updating blocklist %s …", bl_name)
    client.rai_blocklists.create_or_update(
        resource_group_name=resource_group,
        account_name=account_name,
        rai_blocklist_name=bl_name,
        rai_blocklist=RaiBlocklist(
            properties=RaiBlocklistProperties(
                description=bl_def.get("description", "")
            )
        )
    )

    # remove existing items
    for existing in client.rai_blocklist_items.list(resource_group, account_name, bl_name):
        client.rai_blocklist_items.delete(
            resource_group_name=resource_group,
            account_name=account_name,
            rai_blocklist_name=bl_name,
            rai_blocklist_item_name=existing.name
        )

    # re-add items
    for idx, item in enumerate(bl_def.get("blocklistItems", [])):
        pat = item.get("pattern", "") or ""
        if not pat.strip():
            logging.warning("Skipping blocklist item %d: empty pattern", idx)
            continue

        item_name = f"{bl_name}Item{idx}"
        logging.info("Adding blocklist item %s …", item_name)
        client.rai_blocklist_items.create_or_update(
            resource_group_name=resource_group,
            account_name=account_name,
            rai_blocklist_name=bl_name,
            rai_blocklist_item_name=item_name,
            rai_blocklist_item=RaiBlocklistItem(
                properties=RaiBlocklistItemProperties(
                    pattern=pat,
                    is_regex=item.get("isRegex", False)
                )
            )
        )

    # ── 5) RAI policy creation/update ─────────────────────────────────────────
    pol_def = load_and_replace(
        "scripts/rai/raipolicies.json",
        {
            "{{PolicyName}}": policy_name,
            "{{BlocklistName}}": bl_name
        }
    )
    p_name = pol_def.get("name")
    if not p_name:
        logging.error("Policy JSON must have top-level 'name'.")
        sys.exit(1)

    props      = pol_def["properties"]
    prompt_bl  = props.pop("promptBlocklists", [])
    comp_bl    = props.pop("completionBlocklists", [])
    for x in prompt_bl: x["source"] = "Prompt"
    for x in comp_bl:   x["source"] = "Completion"
    props["customBlocklists"] = prompt_bl + comp_bl

    # normalize casing
    for f in props.get("contentFilters", []):
        if "allowedContentLevel" in f:
            lvl = f.pop("allowedContentLevel")
            f["severityThreshold"] = lvl.capitalize()
        if "source" in f:
            f["source"] = f["source"].capitalize()
    if "mode" in props:
        props["mode"] = props["mode"].capitalize()

    logging.info("Creating/updating policy %s …", p_name)
    client.rai_policies.create_or_update(
        resource_group_name=resource_group,
        account_name=account_name,
        rai_policy_name=p_name,
        rai_policy={"properties": props}
    )

    # ── 6) Associate policy to deployment ────────────────────────────────────
    logging.info("Associating policy %s with deployment %s …", p_name, deployment_name)
    existing = client.deployments.get(resource_group, account_name, deployment_name)
    dep_dict = existing.as_dict()
    dep_dict["properties"]["raiPolicyName"] = p_name

    client.deployments.begin_create_or_update(
        resource_group_name=resource_group,
        account_name=account_name,
        deployment_name=deployment_name,
        deployment=dep_dict
    ).result()

    logging.info("✅ RAI blocklist, policy, and deployment association complete.")


if __name__ == "__main__":
    main()
