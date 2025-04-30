#!/usr/bin/env python
import os
import sys
import logging
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.appconfiguration import AzureAppConfigurationClient

# Load from .env if present
load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# List your required env vars here
REQUIRED_ENV_VARS = [
    "AZURE_CLOUD",
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_RESOURCE_GROUP",
    "AZURE_DEPLOYMENT_NAME",
    "AZURE_APP_CONFIG_NAME"
]

def check_env_vars():
    logging.info("The following environment variables are required:")
    for name in REQUIRED_ENV_VARS:
        logging.info("  • %s", name)

    missing = [v for v in REQUIRED_ENV_VARS if not os.environ.get(v)]
    if missing:
        logging.info("")  # blank line for readability
        logging.error("Missing environment variables:")
        for name in missing:
            logging.error("  • %s", name)
        sys.exit(1)

def main():
    # 1) Validate
    check_env_vars()

    # 2) Grab them
    environment  = os.environ["AZURE_CLOUD"]    
    sub_id       = os.environ["AZURE_SUBSCRIPTION_ID"]
    rg           = os.environ["AZURE_RESOURCE_GROUP"]
    deployment   = os.environ["AZURE_DEPLOYMENT_NAME"]
    appconf_name = os.environ["AZURE_APP_CONFIG_NAME"]

    # 3) Authenticate
    cred = DefaultAzureCredential()

    # 4) Fetch deployment outputs via ARM
    resource_client = ResourceManagementClient(cred, sub_id)
    props = resource_client.deployments.get(rg, deployment).properties.outputs
    if "appConfigKVs" not in props or "value" not in props["appConfigKVs"]:
        logging.error("Deployment outputs missing ‘appConfigKVs.value’")
        sys.exit(1)
    kvs = props["appConfigKVs"]["value"]  # expected dict of key→value

    # 5) Connect to App Configuration
    if environment == "AzureUSGovernment":
        # US Government Cloud
        suffix = "azconfig.azure.us"
    elif environment == "AzureChinaCloud":
        # China Cloud
        suffix = "azconfig.cn"
    else:
        # Default (Public Cloud)
        suffix = "azconfig.io"

    endpoint = f"https://{appconf_name}.{suffix}"
    client = AzureAppConfigurationClient(endpoint, cred)

    # 6) Seed each setting
    count = 0
    for key, val in kvs.items():
        logging.info("Setting %s = %s", key, val)
        client.set_configuration_setting(key=key, value=str(val))
        count += 1

    logging.info("✅ Seeded %d entries into %s", count, appconf_name)

if __name__ == "__main__":
    main()
