#!/usr/bin/env python3
# scripts/search/setup.py

import os
import time
import logging
import argparse
import requests
import subprocess
from azure.identity import ManagedIdentityCredential, AzureCliCredential, ChainedTokenCredential

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


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
    # delete then put
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
        "authResourceId": f"api://{apim_service}",
        "timeout": "PT230S",
        "inputs": [{"name": "documentUrl", "source": "/document/metadata_storage_path"}],
        "outputs": [{"name": "chunks", "targetName": "chunks"}]
    }
    body = {"name": ss, "skills": [skill]}
    call_search_api(search_service, api_version, "skillsets", ss, "delete", cred)
    time.sleep(1)
    call_search_api(search_service, api_version, "skillsets", ss, "put", cred, body)


def create_embedding_skillset(search_service, api_version, index_name,
                              apim_service, openai_path, openai_version, cred):
    ss = f"{index_name}-skillset-embed"
    skill = {
        "@odata.type": "#Microsoft.Skills.Text.AzureOpenAIEmbeddingSkill",
        "name": "embedding-skill",
        "description": f"Generate embeddings for {index_name}",
        "uri": f"https://{apim_service}.azure-api.net/{openai_path}/embeddings?api-version={openai_version}",
        "httpHeaders": {
            "Ocp-Apim-Subscription-Key": os.environ["AZURE_APIM_SUBSCRIPTION_KEY"]
        },
        "inputs": [{"name": "text", "source": "/document/content"}],
        "outputs": [{"name": "embedding", "targetName": "contentVector"}]
    }
    body = {"name": ss, "skills": [skill]}
    call_search_api(search_service, api_version, "skillsets", ss, "delete", cred)
    time.sleep(1)
    call_search_api(search_service, api_version, "skillsets", ss, "put", cred, body)


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
    p = argparse.ArgumentParser(
        description="Setup four AI Search indices + skillsets + indexers"
    )
    p.add_argument("--subscription-id",    required=True)
    p.add_argument("--resource-group",     required=True)
    p.add_argument("--container-app-name", required=True)
    p.add_argument("--search-service",     required=True)
    p.add_argument("--search-api-version", required=True)
    p.add_argument("--search-index",       required=True,
                   help="Base RAG index name (e.g. 'ragindex')")
    p.add_argument("--apim-service",       required=True)
    p.add_argument("--openai-path",        required=True)
    p.add_argument("--openai-version",     required=True)
    args = p.parse_args()

    cred = ChainedTokenCredential(ManagedIdentityCredential(), AzureCliCredential())

    fqdn = get_containerapp_fqdn(args.resource_group, args.container_app_name)
    logging.info(f"Data‑ingest Container App FQDN: {fqdn}")

    # environment settings
    storage_rg      = os.environ["AZURE_STORAGE_ACCOUNT_RG"]
    storage_account = os.environ["AZURE_STORAGE_ACCOUNT_NAME"]
    storage_cont    = os.environ["AZURE_STORAGE_CONTAINER"]
    analyzer        = os.environ.get("SEARCH_ANALYZER_NAME", "standard.lucene")
    interval        = os.environ.get("SEARCH_INDEX_INTERVAL", "PT2H")
    embed_dim       = int(os.environ["AZURE_EMBEDDINGS_VECTOR_SIZE"])

    base = args.search_index
    # 1) RAG index
    rag_fields = [
        {"name":"id","type":"Edm.String","key":True,"searchable":False},
        {"name":"content","type":"Edm.String","searchable":True,"analyzer":analyzer},
        {"name":"contentVector","type":"Collection(Edm.Single)",
         "searchable":True,"retrievable":True,"dimensions":embed_dim}
    ]
    create_datasource(args.search_service, args.search_api_version,
                      base, args.subscription_id,
                      storage_rg, storage_account, storage_cont, cred)
    create_index(args.search_service, args.search_api_version, base, rag_fields, cred)
    create_rag_skillset(args.search_service, args.search_api_version,
                        base, fqdn, args.apim_service, cred)
    create_indexer(args.search_service, args.search_api_version,
                   base, f"{base}-datasource", f"{base}-skillset-chunking",
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
        idx = f"{base}-{name}"
        create_datasource(args.search_service, args.search_api_version,
                          idx, args.subscription_id,
                          storage_rg, storage_account, storage_cont, cred)
        create_index(args.search_service, args.search_api_version, idx, fields, cred)
        create_embedding_skillset(args.search_service, args.search_api_version,
                                 idx, args.apim_service,
                                 args.openai_path, args.openai_version, cred)
        create_indexer(args.search_service, args.search_api_version,
                       idx, f"{idx}-datasource", f"{idx}-skillset-embed",
                       interval, cred)

    logging.info("✅ All four indices + skillsets + indexers created.")
