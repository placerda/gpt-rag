#!/usr/bin/env python3

import os
import sys
import json
import re
import logging

from azure.identity import (
    AzureCliCredential,
    ManagedIdentityCredential,
    ChainedTokenCredential
)
from azure.appconfiguration import AzureAppConfigurationClient
from azure.ai.ml import MLClient
from azure.ai.ml.entities import (
    AzureOpenAIConnection,
    AzureAISearchConnection,
    AzureAIServicesConnection,
    ServerlessConnection,
    ApiKeyConfiguration
)
from azure.mgmt.apimanagement import ApiManagementClient

# ── Configure logging ─────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.mgmt"
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)


def check_env():
    if not os.getenv("AZURE_APP_CONFIG_ENDPOINT"):
        logging.error("❗️ Missing environment variable: AZURE_APP_CONFIG_ENDPOINT")
        sys.exit(1)


def cfg(app_conf: AzureAppConfigurationClient, key: str, label= 'infra', required: bool = True) -> str:
    """
    Fetch `key` from App Configuration; exit if missing or empty.
    """
    try:
        setting = app_conf.get_configuration_setting(key=key, label=label)
    except Exception as e:
        logging.error("❗️ Could not fetch key '%s' from App Configuration: %s", key, e)
        if required:
            sys.exit(1)
        return ""
    if required and not setting.value:
        logging.error("❗️ Key '%s' is empty in App Configuration", key)
        sys.exit(1)
    return setting.value


def interpolate(template: str, app_conf: AzureAppConfigurationClient) -> str:
    """
    Replace every {KEY} in template by cfg(app_conf, KEY).
    """
    def _repl(match):
        return cfg(app_conf, match.group(1))
    return re.sub(r"\{(\w+)\}", _repl, template)


def resolve_resource_id(raw: str, app_conf: AzureAppConfigurationClient) -> str:
    """
    If raw is '{OUTER.KEY}', fetch the JSON object in App Config and return attribute KEY.
    Otherwise treat as a template.
    """
    m = re.fullmatch(r"\{(\w+)\.(\w+)\}", raw)
    if m:
        outer, inner = m.groups()
        val = cfg(app_conf, outer)
        try:
            obj = json.loads(val)
        except json.JSONDecodeError:
            logging.error("❗️ App Config key '%s' is not valid JSON", outer)
            sys.exit(1)
        if inner not in obj:
            logging.error("❗️ JSON key '%s' has no attribute '%s'", outer, inner)
            sys.exit(1)
        return obj[inner]
    return interpolate(raw, app_conf)


def main():
    check_env()

    # connect to App Configuration
    app_conf = AzureAppConfigurationClient(
        os.environ["AZURE_APP_CONFIG_ENDPOINT"],
        ChainedTokenCredential(AzureCliCredential(), ManagedIdentityCredential())
    )

    # core settings
    subscription_id  = cfg(app_conf, "AZURE_SUBSCRIPTION_ID")
    resource_group   = cfg(app_conf, "AZURE_RESOURCE_GROUP")
    hub_name         = cfg(app_conf, "AZURE_AI_FOUNDRY_HUB_NAME")
    aoai_api_ver     = cfg(app_conf, "AZURE_AOAI_API_VERSION")
    aoai_dep_list    = cfg(app_conf, "AZURE_AOAI_DEPLOYMENT_LIST")
    proj_conn_str    = cfg(app_conf, "AZURE_AI_FOUNDRY_PROJECT_CONNECTION_STRING")

    # instantiate MLClient to register connections
    ml_client = MLClient(
        credential=ChainedTokenCredential(AzureCliCredential(), ManagedIdentityCredential()),
        subscription_id=subscription_id,
        resource_group_name=resource_group,
        workspace_name=hub_name,
    )

    # register resource connections
    with open("config/aifoundry/connections.json", "r") as f:
        conn_cfgs = json.load(f).get("connections", {})
    for key, cfg_item in conn_cfgs.items():
        name     = cfg_item["name"]
        category = cfg_item["category"]
        use_apim = cfg_item.get("use_apim", False)
        logging.info("Registering connection '%s' (category=%s)", name, category)

        # prepare common fields
        target = interpolate(cfg_item.get("target", ""), app_conf)
        api_path = interpolate(cfg_item.get("api_path", ""), app_conf) if cfg_item.get("api_path") else None
        raw_res = cfg_item.get("resource_id", "")
        res_id = resolve_resource_id(raw_res, app_conf) if raw_res else None
        is_shared = cfg_item.get("is_shared", False)

        # credentials if API key
        creds = None
        if cfg_item.get("api_key"):
            creds = ApiKeyConfiguration(key=interpolate(cfg_item["api_key"], app_conf))

        # APIM handling
        if use_apim:
            apim_name = interpolate(cfg_item["apim_service_name"], app_conf)
            apim_sub  = interpolate(cfg_item["apim_subscription_display_name"], app_conf)
            apim = ApiManagementClient(
                credential=ChainedTokenCredential(AzureCliCredential(), ManagedIdentityCredential()),
                subscription_id=subscription_id,
                api_version="2024-06-01-preview"
            )
            subs = list(apim.subscription.list(resource_group, apim_name))
            sub  = next((s for s in subs if s.display_name == apim_sub), subs[0] if len(subs)==1 else None)
            if not sub:
                logging.error("❗️ APIM subscription '%s' not found; available: %s", apim_sub, [s.display_name for s in subs])
                sys.exit(1)
            sec = apim.subscription.list_secrets(resource_group, apim_name, sub.name)
            key = sec.primary_key
            gateway = f"https://{apim_name}.azure-api.net/{api_path}"
            creds = ApiKeyConfiguration(key=key)
            target = gateway

        # build and create connection entities
        if category == "AzureOpenAI":
            ent = AzureOpenAIConnection(
                name=name,
                azure_endpoint=target,
                credentials=creds,
                api_version=cfg_item.get("api_version", aoai_api_ver),
                resource_id=res_id,
                is_shared=is_shared
            )
        elif category == "AIInference":
            if not creds:
                logging.error("❗️ AIInference '%s' requires api_key or apim", name)
                sys.exit(1)
            ent = ServerlessConnection(name=name, endpoint=target, api_key=creds.key)
        elif category == "CognitiveServices":
            if not res_id:
                logging.error("❗️ CognitiveServices '%s' requires resource_id", name)
                sys.exit(1)
            ent = AzureAIServicesConnection(
                name=name,
                endpoint=target,
                credentials=creds,
                ai_services_resource_id=res_id,
                is_shared=is_shared
            )
        elif category == "CognitiveSearch":
            if creds:
                ent = AzureAISearchConnection(name=name, endpoint=target, credentials=creds, is_shared=is_shared)
            else:
                if not res_id:
                    logging.error("❗️ CognitiveSearch '%s' requires resource_id for AAD", name)
                    sys.exit(1)
                ent = AzureAISearchConnection(name=name, endpoint=res_id, is_shared=is_shared)
        else:
            logging.warning("Unknown category '%s'; skipping", category)
            continue

        ml_client.connections.create_or_update(ent)
        logging.info("✅ Registered '%s'", name)


if __name__ == "__main__":
    main()
