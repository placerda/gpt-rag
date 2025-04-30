#!/usr/bin/env python3
import os
import sys
import time
import logging
import requests
import subprocess

from azure.identity import (
    ManagedIdentityCredential,
    AzureCliCredential,
    ChainedTokenCredential
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# These must all be set in the environment
REQUIRED_ENV_VARS = [
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_RESOURCE_GROUP",
    "AZURE_DATA_INGEST_CONTAINER_APP_NAME",
    "AZURE_SEARCH_SERVICE_NAME",
    "AZURE_SEARCH_API_VERSION",
    "AZURE_SEARCH_INDEX_NAME",
    "AZURE_APIM_SERVICE_NAME",
    "AZURE_APIM_OPENAI_API_PATH",
    "AZURE_OPENAI_API_VERSION",
    "AZURE_STORAGE_ACCOUNT_RG",
    "AZURE_STORAGE_ACCOUNT_NAME",
    "AZURE_STORAGE_CONTAINER",
    "AZURE_KEY_VAULT_NAME",
    "AZURE_APIM_SUBSCRIPTION_SECRET_NAME",
    "AZURE_APIM_GATEWAY_URL",
    "AZURE_OPENAI_EMBEDDING_DEPLOYMENT",
    "AZURE_OPENAI_EMBEDDING_MODEL_NAME",
    "AZURE_EMBEDDINGS_VECTOR_SIZE"
]

def check_env_vars():
    # 1) Preamble: list every required env-var
    logging.info("The following environment variables are required:")
    for name in REQUIRED_ENV_VARS:
        logging.info("  • %s", name)

    # 2) Check which ones are actually missing
    missing = [v for v in REQUIRED_ENV_VARS if not os.environ.get(v)]
    if missing:
        logging.error("")  # blank line for separation
        logging.error("Missing environment variables:")
        for name in missing:
            logging.error("  • %s", name)
        sys.exit(1)

def call_search_api(service, api_version, resource_type, name, method, credential, body=None):
    token = credential.get_token("https://search.azure.com/.default").token
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    url = f"https://{service}.search.windows.net/{resource_type}/{name}?api-version={api_version}"
    resp = requests.request(method, url, headers=headers, json=body)
    if resp.status_code >= 400:
        logging.error(f"{method.upper()} {url} → {resp.status_code}: {resp.text}")
    else:
        logging.info(f"{method.upper()} {url} → {resp.status_code}")
    return resp

def get_containerapp_fqdn(resource_group, container_app):
    cmd = [
        "az", "containerapp", "show",
        "--name", container_app,
        "--resource-group", resource_group,
        "--query", "properties.configuration.ingress.fqdn",
        "-o", "tsv"
    ]
    return subprocess.check_output(cmd, text=True).strip()

def create_datasource(search_service, api_version, index_name,
                      subscription_id, storage_rg, storage_account, container, cred):
    conn = (
        f"ResourceId=/subscriptions/{subscription_id}"
        f"/resourceGroups/{storage_rg}"
        f"/providers/Microsoft.Storage/storageAccounts/{storage_account}/;"
    )
    ds = f"{index_name}-datasource"
    body = {
        "name": ds,
        "description": f"Blob datastore for {index_name}",
        "type": "azureblob",
        "credentials": {"connectionString": conn},
        "container": {"name": container}
    }
    call_search_api(search_service, api_version, "datasources", ds, "put", cred, body)

def create_index(search_service, api_version, index_name, fields, cred):
    call_search_api(search_service, api_version, "indexes", index_name, "delete", cred)
    time.sleep(1)
    body = {"name": index_name, "fields": fields}
    call_search_api(search_service, api_version, "indexes", index_name, "put", cred, body)

def create_rag_skillset(search_service, api_version, index_name,
                        container_fqdn, apim_service, cred):
    ss = f"{index_name}-skillset-chunking"
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
    call_search_api(search_service, api_version, "skillsets", ss, "delete", cred)
    time.sleep(1)
    call_search_api(search_service, api_version, "skillsets", ss, "put", cred, {"name": ss, "skills": [skill]})

def create_embedding_skillset(search_service, api_version, index_name,
                              apim_service, openai_path, openai_version, cred):
    apim_key = subprocess.check_output([
        "az", "keyvault", "secret", "show",
        "--vault-name", os.environ["AZURE_KEY_VAULT_NAME"],
        "--name", os.environ["AZURE_APIM_SUBSCRIPTION_SECRET_NAME"],
        "--query", "value", "-o", "tsv"
    ], text=True).strip()

    ss = f"{index_name}-skillset-embed"
    skill = {
        "@odata.type": "#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill",
        "name": "embedding-skill",
        "description": f"Generate embeddings for {index_name} via APIM",
        "resourceUri": f"{os.environ['AZURE_APIM_GATEWAY_URL']}/{openai_path}",
        "apiKey": apim_key,
        "deploymentId": os.environ["AZURE_OPENAI_EMBEDDING_DEPLOYMENT"],
        "modelName": os.environ["AZURE_OPENAI_EMBEDDING_MODEL_NAME"],
        "dimensions": int(os.environ["AZURE_EMBEDDINGS_VECTOR_SIZE"]),
        "inputs": [{"name": "text", "source": "/document/content"}],
        "outputs": [{"name": "embedding", "targetName": "contentVector"}]
    }
    call_search_api(search_service, api_version, "skillsets", ss, "delete", cred)
    call_search_api(search_service, api_version, "skillsets", ss, "put", cred, {"name": ss, "skills": [skill]})

def create_indexer(search_service, api_version, index_name, datasource_name,
                   skillset_name, schedule_interval, cred):
    idxr = f"{index_name}-indexer"
    body = {
        "name": idxr,
        "dataSourceName": datasource_name,
        "targetIndexName": index_name,
        "skillsetName": skillset_name,
        "schedule": {"interval": schedule_interval}
    }
    call_search_api(search_service, api_version, "indexers", idxr, "put", cred, body)

def main():
    check_env_vars()

    cred = ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())

    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    resource_group = os.environ["AZURE_RESOURCE_GROUP"]
    container_app = os.environ["AZURE_DATA_INGEST_CONTAINER_APP_NAME"]
    search_service = os.environ["AZURE_SEARCH_SERVICE_NAME"]
    search_api_version = os.environ["AZURE_SEARCH_API_VERSION"]
    base_index = os.environ["AZURE_SEARCH_INDEX_NAME"]
    apim_service = os.environ["AZURE_APIM_SERVICE_NAME"]
    openai_path = os.environ["AZURE_APIM_OPENAI_API_PATH"]
    openai_version = os.environ["AZURE_OPENAI_API_VERSION"]

    fqdn = get_containerapp_fqdn(resource_group, container_app)
    logging.info(f"Data-ingest Container App FQDN: {fqdn}")

    storage_rg = os.environ["AZURE_STORAGE_ACCOUNT_RG"]
    storage_account = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
    storage_cont = os.environ["AZURE_STORAGE_CONTAINER"]
    analyzer = os.environ.get("SEARCH_ANALYZER_NAME", "standard.lucene")
    interval = os.environ.get("SEARCH_INDEX_INTERVAL", "PT2H")
    embed_dim = int(os.environ["AZURE_EMBEDDINGS_VECTOR_SIZE"])

    # 1) RAG index
    rag_fields = [
        {"name":"id","type":"Edm.String","key":True,"searchable":False},
        {"name":"content","type":"Edm.String","searchable":True,"analyzer":analyzer},
        {"name":"contentVector","type":"Collection(Edm.Single)",
         "searchable":True,"retrievable":True,"dimensions":embed_dim}
    ]
    create_datasource(search_service, search_api_version,
                      base_index, subscription_id,
                      storage_rg, storage_account, storage_cont, cred)
    create_index(search_service, search_api_version, base_index, rag_fields, cred)
    create_rag_skillset(search_service, search_api_version,
                        base_index, fqdn, apim_service, cred)
    create_indexer(search_service, search_api_version,
                   base_index, f"{base_index}-datasource", f"{base_index}-skillset-chunking",
                   interval, cred)

    # 2) NL2SQL indices
    for name, fields in {
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
    }.items():
        idx = f"{base_index}-{name}"
        create_datasource(search_service, search_api_version,
                          idx, subscription_id,
                          storage_rg, storage_account, storage_cont, cred)
        create_index(search_service, search_api_version, idx, fields, cred)
        create_embedding_skillset(search_service, search_api_version,
                                 idx, apim_service,
                                 openai_path, openai_version, cred)
        create_indexer(search_service, search_api_version,
                       idx, f"{idx}-datasource", f"{idx}-skillset-embed",
                       interval, cred)

    logging.info("✅ All indices, skillsets, and indexers created.")

if __name__ == "__main__":
    main()
