#!/usr/bin/env python
import os
import sys
import json
import logging
import subprocess

from azure.identity import (
    AzureCliCredential,
    ManagedIdentityCredential,
    ChainedTokenCredential
)
from azure.appconfiguration import AzureAppConfigurationClient

# Logging setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.appconfiguration"
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

def main():
    # 1) Validate required env var
    app_conf_endpoint = os.environ.get("AZURE_APP_CONFIG_ENDPOINT")
    if not app_conf_endpoint:
        logging.error("Missing required environment variable: AZURE_APP_CONFIG_ENDPOINT")
        sys.exit(1)

    # 2) Authenticate
    cred = ChainedTokenCredential(
        AzureCliCredential(),
        ManagedIdentityCredential()
    )

    # 3) Connect to App Configuration
    client = AzureAppConfigurationClient(app_conf_endpoint, cred)

    # 4) Fetch PROVISION_CONFIG
    try:
        setting = client.get_configuration_setting(key="PROVISION_CONFIG")
        provision_config = json.loads(setting.value)
    except Exception as e:
        logging.error("Failed to load PROVISION_CONFIG from App Configuration: %s", str(e))
        sys.exit(1)

    # 5) Set AZD environment variables
    count = 0
    for key, value in provision_config.items():
        try:
            subprocess.run(
                ["azd", "env", "set", key, str(value)],
                check=True
            )
            logging.info("Set AZD environment %s = %s", key, value)
            count += 1
        except subprocess.CalledProcessError as e:
            logging.error("Failed to set AZD environment %s: %s", key, str(e))

    logging.info("✅ Set %d AZD environment variables from PROVISION_CONFIG", count)

if __name__ == "__main__":
    main()
