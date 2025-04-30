#!/usr/bin/env python
import os
import sys
import time
import logging
import requests

from dotenv import load_dotenv
from azure.identity import AzureCliCredential, ManagedIdentityCredential, ChainedTokenCredential
from azure.mgmt.containerinstance import ContainerInstanceManagementClient
from azure.keyvault.secrets import SecretClient

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# These must all be set in the environment
REQUIRED_ENV_VARS = [
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_RESOURCE_GROUP",
    "AZURE_DATA_INGEST_CONTAINER_APP_NAME",
    "AZURE_SEARCH_SERVICE_NAME",
    "AZURE_SEARCH_API_VERSION",
    "AZURE_SEARCH_INDEX_NAME",
    "AZURE_STORAGE_ACCOUNT_RG",
    "AZURE_STORAGE_ACCOUNT_NAME",
    "AZURE_STORAGE_CONTAINER",
    "AZURE_KEY_VAULT_NAME",
    "AZURE_APIM_GATEWAY_URL",
    "AZURE_APIM_OPENAI_API_PATH",
    "AZURE_OPENAI_API_VERSION",
    "AZURE_OPENAI_EMBEDDING_DEPLOYMENT",
    "AZURE_OPENAI_EMBEDDING_MODEL_NAME",
    "AZURE_EMBEDDINGS_VECTOR_SIZE"
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

def call_search_api(service, api_version, resource_type, name, method, credential, body=None):
    try:
        token = credential.get_token("https://search.azure.com/.default").token
        headers = {"Authorization": f"Bearer {token}"}
        if body is not None:
            headers["Content-Type"] = "application/json"

        url = f"https://{service}.search.windows.net/{resource_type}/{name}?api-version={api_version}"
        resp = requests.request(method, url, headers=headers, json=body, timeout=30)
        if resp.status_code >= 400:
            logging.error(f"{method.upper()} {url} → {resp.status_code}: {resp.text}")
            resp.raise_for_status()
        else:
            logging.info(f"{method.upper()} {url} → {resp.status_code}")
        return resp

    except requests.RequestException as e:
        logging.error("HTTP request failed: %s", e)
        sys.exit(1)

def get_container_fqdn(container_client, resource_group, container_name):
    try:
        cg = container_client.container_groups.get(resource_group, container_name)
        fqdn = cg.ip_address.fqdn if cg.ip_address else None
        if not fqdn:
            logging.error("Container instance '%s' has no FQDN assigned", container_name)
            sys.exit(1)
        return fqdn
    except Exception as e:
        logging.error("Failed to get container instance FQDN: %s", e)
        sys.exit(1)

def create_datasource(service, api_version, index_name,
                      subscription_id, storage_rg, storage_account, container, credential):
    resource_id = (
        f"/subscriptions/{subscription_id}"
        f"/resourceGroups/{storage_rg}"
        f"/providers/Microsoft.Storage/storageAccounts/{storage_account}"
    )
    ds_name = f"{index_name}-datasource"
    body = {
        "name": ds_name,
        "description": f"Blob datastore for {index_name}",
        "type": "azureblob",
        "credentials": {"managedIdentityResourceId": resource_id},
        "container": {"name": container}
    }
    call_search_api(service, api_version, "datasources", ds_name, "put", credential, body)

def create_index(service, api_version, index_name, fields, credential):
    call_search_api(service, api_version, "indexes", index_name, "delete", credential)
    time.sleep(1)
    body = {"name": index_name, "fields": fields}
    call_search_api(service, api_version, "indexes", index_name, "put", credential, body)

def create_rag_skillset(service, api_version, index_name, container_fqdn, credential):
    ss_name = f"{index_name}-skillset-chunking"
    skill = {
        "@odata.type": "#Microsoft.Skills.Custom.WebApiSkill",
        "name": "document-chunking",
        "httpMethod": "POST",
        "uri": f"https://{container_fqdn}/document-chunking",
        "timeout": "PT230S",
        "batchSize": 1,
        "context": "/document",
        "inputs": [{"name": "documentUrl", "source": "/document/metadata_storage_path"}],
        "outputs": [{"name": "chunks", "targetName": "chunks"}]
    }
    call_search_api(service, api_version, "skillsets", ss_name, "delete", credential)
    time.sleep(1)
    call_search_api(
        service, api_version, "skillsets", ss_name, "put", credential,
        {"name": ss_name, "skills": [skill]}
    )

def create_embedding_skillset(service, api_version, index_name,
                              openai_path, openai_version, credential, secret_client):
    gateway = os.environ["AZURE_APIM_GATEWAY_URL"].rstrip("/")
    secret_name = os.environ["AZURE_APIM_SUBSCRIPTION_SECRET_NAME"]
    apim_key = secret_client.get_secret(secret_name).value

    ss_name = f"{index_name}-skillset-embed"
    skill = {
        "@odata.type": "#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill",
        "name": "embedding-skill",
        "description": f"Generate embeddings for {index_name} via APIM",
        "resourceUri": f"{gateway}/{openai_path}?api-version={openai_version}",
        "apiKey": apim_key,
        "deploymentId": os.environ["AZURE_OPENAI_EMBEDDING_DEPLOYMENT"],
        "modelName": os.environ["AZURE_OPENAI_EMBEDDING_MODEL_NAME"],
        "dimensions": int(os.environ["AZURE_EMBEDDINGS_VECTOR_SIZE"]),
        "inputs": [{"name": "text", "source": "/document/content"}],
        "outputs": [{"name": "embedding", "targetName": "contentVector"}]
    }
    call_search_api(service, api_version, "skillsets", ss_name, "delete", credential)
    time.sleep(1)
    call_search_api(
        service, api_version, "skillsets", ss_name, "put", credential,
        {"name": ss_name, "skills": [skill]}
    )

def create_indexer(service, api_version, index_name, datasource, skillset, interval, credential):
    idx_name = f"{index_name}-indexer"
    body = {
        "name": idx_name,
        "dataSourceName": datasource,
        "targetIndexName": index_name,
        "skillsetName": skillset,
        "schedule": {"interval": interval}
    }
    call_search_api(service, api_version, "indexers", idx_name, "put", credential, body)

def main():
    check_env_vars()

    credential = ChainedTokenCredential(
        AzureCliCredential(),
        ManagedIdentityCredential()
    )

    sub_id     = os.environ["AZURE_SUBSCRIPTION_ID"]
    rg         = os.environ["AZURE_RESOURCE_GROUP"]
    container  = os.environ["AZURE_DATA_INGEST_CONTAINER_APP_NAME"]
    svc        = os.environ["AZURE_SEARCH_SERVICE_NAME"]
    api_ver    = os.environ["AZURE_SEARCH_API_VERSION"]
    base_index = os.environ["AZURE_SEARCH_INDEX_NAME"]
    openai_path= os.environ["AZURE_APIM_OPENAI_API_PATH"]
    openai_ver = os.environ["AZURE_OPENAI_API_VERSION"]

    # Key Vault client
    vault_url     = f"https://{os.environ['AZURE_KEY_VAULT_NAME']}.vault.azure.net"
    secret_client = SecretClient(vault_url=vault_url, credential=credential)

    # Container Instance client
    container_client = ContainerInstanceManagementClient(credential, sub_id)
    fqdn = get_container_fqdn(container_client, rg, container)
    logging.info(f"Data-ingest container FQDN: {fqdn}")

    storage_rg   = os.environ["AZURE_STORAGE_ACCOUNT_RG"]
    storage_acc  = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
    storage_cont = os.environ["AZURE_STORAGE_CONTAINER"]
    analyzer     = os.environ.get("SEARCH_ANALYZER_NAME", "standard.lucene")
    interval     = os.environ.get("SEARCH_INDEX_INTERVAL", "PT2H")
    embed_dim    = int(os.environ["AZURE_EMBEDDINGS_VECTOR_SIZE"])

    # 1) RAG index
    rag_fields = [
        {"name":"id","type":"Edm.String","key":True,"searchable":False},
        {"name":"content","type":"Edm.String","searchable":True,"analyzer":analyzer},
        {"name":"contentVector","type":"Collection(Edm.Single)",
         "searchable":True,"retrievable":True,"dimensions":embed_dim}
    ]
    create_datasource(svc, api_ver, base_index, sub_id, storage_rg, storage_acc, storage_cont, credential)
    create_index(svc, api_ver, base_index, rag_fields, credential)
    create_rag_skillset(svc, api_ver, base_index, fqdn, credential)
    create_indexer(
        svc, api_ver, base_index,
        f"{base_index}-datasource",
        f"{base_index}-skillset-chunking",
        interval, credential
    )

    # 2) NL2SQL indices
    nl2sql_defs = {
        "queries": [
            {"name":"id","type":"Edm.String","key":True},
            {"name":"question","type":"Edm.String","searchable":True,"analyzer":analyzer},
            {"name":"contentVector","type":"Collection(Edm.Single)","searchable":True,"dimensions":embed_dim}
        ],
        "tables": [
            {"name":"id","type":"Edm.String","key":True},
            {"name":"description","type":"Edm.String","searchable":True,"analyzer":analyzer},
            {"name":"contentVector","type":"Collection(Edm.Single)","searchable":True,"dimensions":embed_dim}
        ],
        "measures": [
            {"name":"id","type":"Edm.String","key":True},
            {"name":"description","type":"Edm.String","searchable":True,"analyzer":analyzer},
            {"name":"contentVector","type":"Collection(Edm.Single)","searchable":True,"dimensions":embed_dim}
        ],
    }

    for name, fields in nl2sql_defs.items():
        idx = f"{base_index}-{name}"
        create_datasource(svc, api_ver, idx, sub_id, storage_rg, storage_acc, storage_cont, credential)
        create_index(svc, api_ver, idx, fields, credential)
        create_embedding_skillset(svc, api_ver, idx, openai_path, openai_ver, credential, secret_client)
        create_indexer(
            svc, api_ver, idx,
            f"{idx}-datasource",
            f"{idx}-skillset-embed",
            interval, credential
        )

    logging.info("✅ All indices, skillsets, and indexers created.")

if __name__ == "__main__":
    main()
