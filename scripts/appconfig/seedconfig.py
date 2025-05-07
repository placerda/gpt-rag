#!/usr/bin/env python
import os
import sys
import json
import logging

from azure.identity import AzureCliCredential, ManagedIdentityCredential, ChainedTokenCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.appconfiguration import AzureAppConfigurationClient, ConfigurationSetting

# Configure root logger
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.mgmt.resource",
    "azure.appconfiguration"
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

# Required environment variables
REQUIRED_ENV_VARS = [
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_RESOURCE_GROUP",
    "AZURE_DEPLOYMENT_NAME",
    "AZURE_APP_CONFIG_ENDPOINT"
]

def check_env_vars():
    missing = [v for v in REQUIRED_ENV_VARS if not os.environ.get(v)]
    if missing:
        logging.error("Missing environment variables: %s", ", ".join(missing))
        sys.exit(1)

def main():
    # 1) Validate env-vars
    check_env_vars()
    sub_id            = os.environ["AZURE_SUBSCRIPTION_ID"]
    rg                = os.environ["AZURE_RESOURCE_GROUP"]
    deployment        = os.environ["AZURE_DEPLOYMENT_NAME"]
    app_conf_endpoint = os.environ["AZURE_APP_CONFIG_ENDPOINT"]

    logging.info("Seeding App Configuration at %s for deployment %s/%s",
                 app_conf_endpoint, rg, deployment)

    # 2) Authenticate
    cred = ChainedTokenCredential(
        AzureCliCredential(),
        ManagedIdentityCredential()
    )

    # 3) Fetch ARM outputs
    resource_client = ResourceManagementClient(cred, sub_id)
    raw_outputs = resource_client.deployments \
        .get(rg, deployment).properties.outputs
    # normalize to upper case
    outputs = { k.upper(): v for k, v in raw_outputs.items() }
    
    # 4) Connect to App Configuration
    client = AzureAppConfigurationClient(app_conf_endpoint, cred)

    # 5) Seed PROVISION_CONFIG (JSON dump)

    if "PROVISION_CONFIG" not in outputs or "value" not in outputs["PROVISION_CONFIG"]:
        logging.error("Missing PROVISION_CONFIG.value in deployment outputs")
        sys.exit(1)
    logging.info("🌱 Seeding PROVISION_CONFIG (infra/provisioning settings)")        
    provision_config = outputs["PROVISION_CONFIG"]["value"]
    client.set_configuration_setting(
        ConfigurationSetting(
            key="PROVISION_CONFIG",
            value=json.dumps(provision_config)
        )
    )
    for key, val in provision_config.items():
        logging.info("Set %s = %s", key, val)
    logging.info("✅ Seeded PROVISION_CONFIG (%d entries)", len(provision_config))

    # 6) Seed APP_SETTINGS (individual settings)
    if "APP_SETTINGS" not in outputs or "value" not in outputs["APP_SETTINGS"]:
        logging.error("Missing APP_SETTINGS.value in deployment outputs")
        sys.exit(1)
    logging.info("🌱 Seeding APP_SETTINGS (runtime settings)")
    app_settings = outputs["APP_SETTINGS"]["value"]
    count = 0
    for key, val in app_settings.items():
        logging.info("Setting %s = %s", key, val)
        setting = ConfigurationSetting(key=key, value=str(val))
        client.set_configuration_setting(setting)
        count += 1

    logging.info("✅ Seeded %d APP_SETTINGS entries", count)


if __name__ == "__main__":
    main()
