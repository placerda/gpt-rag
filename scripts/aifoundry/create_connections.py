#!/usr/bin/env python
import os
import sys
import json
import logging
import time

from azure.identity import AzureCliCredential, ManagedIdentityCredential, ChainedTokenCredential
from azure.appconfiguration import AzureAppConfigurationClient

# Azure ML SDK
from azure.ai.ml import MLClient
from azure.ai.ml.entities import (
    AzureOpenAIConnection,
    AzureAIServicesConnection,
    AzureAISearchConnection,
    ApiKeyConfiguration
)

# API Management SDK
from azure.mgmt.apimanagement import ApiManagementClient

def create_connections():
    # 1) Authenticate via Managed Identity or Azure CLI
    credential = ChainedTokenCredential(
        ManagedIdentityCredential(),
        AzureCliCredential()
    )

    # 2) Load provisioning JSON from App Configuration
    endpoint = os.environ.get("AZURE_APP_CONFIG_ENDPOINT")
    if not endpoint:
        logging.error("Environment variable 'AZURE_APP_CONFIG_ENDPOINT' is not set. Exiting.")
        sys.exit(1)
    appconfig = AzureAppConfigurationClient(endpoint, credential)
    setting = appconfig.get_configuration_setting(key="PROVISION_CONFIG")
    cfg = json.loads(setting.value)

    # 3) Instantiate MLClient for your AI Foundry Project
    subscription_id = cfg["AZURE_SUBSCRIPTION_ID"]
    resource_group  = cfg["AZURE_RESOURCE_GROUP"]
    workspace_name  = cfg["AZURE_AI_FOUNDRY_PROJECT_NAME"]
    ml_client = MLClient(credential, subscription_id, resource_group, workspace_name)

    # 4) Retrieve the APIM subscription key for Azure OpenAI  
    apim_client       = ApiManagementClient(credential, subscription_id, api_version="2024-06-01-preview")
    apim_svc_name     = cfg["AZURE_APIM_SERVICE_NAME"]
    apim_sub_name     = cfg["AZURE_APIM_OPENAI_SUBSCRIPTION_NAME"]
    secrets_contract  = apim_client.subscription.list_secrets(
        resource_group, apim_svc_name, apim_sub_name
    )
    primary_key = secrets_contract.primary_key

    # 5) Compute the APIM gateway URL (default: https://<apim-name>.azure-api.net)  
    apim_gateway_url = f"https://{apim_svc_name}.azure-api.net"

    # 6) Create an Azure OpenAI connection (via APIM + ApiKey)
    aoai_conn = AzureOpenAIConnection(
        name         = cfg["AZURE_AI_FOUNDRY_PROJECT_AOAI_CONN_NAME"],
        azure_endpoint = apim_gateway_url,
        credentials  = ApiKeyConfiguration(key=primary_key),
        resource_id  = (
            f"/subscriptions/{subscription_id}"
            f"/resourceGroups/{cfg['AZURE_AOAI_RESOURCE_GROUP']}"
            f"/providers/Microsoft.CognitiveServices/accounts/{cfg['AZURE_OPENAI_SERVICE_NAME']}"
        ),
        is_shared    = False
    )
    ml_client.connections.create_or_update(aoai_conn)  
    
    # 7) Create an Azure AI Services connection (AAD auth)
    aisvc_conn = AzureAIServicesConnection(
        name                  = cfg["AZURE_AI_FOUNDRY_PROJECT_AISERVICES_CONN_NAME"],
        endpoint              = f"https://{cfg['AZURE_AI_SERVICES_ENDPOINT']}",
        credentials           = None,
        ai_services_resource_id = (
            f"/subscriptions/{subscription_id}"
            f"/resourceGroups/{resource_group}"
            f"/providers/Microsoft.CognitiveServices/accounts/{cfg['AZURE_AI_SERVICES_NAME']}"
        ),
        is_shared    = False
    )
    ml_client.connections.create_or_update(aisvc_conn)  

    # 8) Create an Azure AI Search connection (AAD auth, keyword-only) 
    aisearch_conn = AzureAISearchConnection(
        name      = cfg["AZURE_AI_FOUNDRY_PROJECT_AISEARCH_CONN_NAME"],
        endpoint  = cfg["AZURE_SEARCH_ENDPOINT"],      # e.g. https://<your-search>.search.windows.net
        api_key   = None,                              # use AAD
        is_shared  = False
    )
    ml_client.connections.create_or_update(aisearch_conn)


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
    logging.info("Starting creation of AI project connections…")
    start = time.time()
    create_connections()
    logging.info(f"🎉 All connections created in {round(time.time() - start, 2)}s")

if __name__ == "__main__":
    main()
