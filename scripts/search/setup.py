#!/usr/bin/env python3
import os
import sys
import time
import json
import logging
import requests

from azure.identity import (
    AzureCliCredential,
    ManagedIdentityCredential,
    ChainedTokenCredential
)
from azure.appconfiguration import AzureAppConfigurationClient
from azure.mgmt.appcontainers import ContainerAppsAPIClient

# ── Silence verbose logging ─────────────────────────────────────────────────
for logger_name in (
    "azure.core.pipeline.policies.http_logging_policy",
    "azure.identity",
    "azure.ai.projects",
):
    logging.getLogger(logger_name).setLevel(logging.WARNING)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

def get_container_app_fqdn(credential: object, sub_id: str,
                           resource_group: str, app_name: str) -> str:
    try:
        logging.info(f"Fetching FQDN for container app '{app_name}' in resource group '{resource_group}'...")
        client = ContainerAppsAPIClient(credential, sub_id)
        app = client.container_apps.get(resource_group, app_name)
        fqdn = app.configuration.ingress.fqdn or ""
        logging.info(f"Successfully retrieved FQDN: {fqdn}")
        return fqdn
    except Exception as e:
        logging.error(f"Failed to fetch FQDN for container app '{app_name}': {e}")
        return ""

def call_search_api(search_endpoint, search_api_version, resource_type, resource_name, method, credential, body=None):
    """
    Calls the Azure Search API with the specified parameters.
    """
    token = credential.get_token("https://search.azure.com/.default").token
    headers = {
        "Authorization": f"Bearer {token}",
        'Content-Type': 'application/json'
    }
    search_endpoint = f"{search_endpoint}/{resource_type}/{resource_name}?api-version={search_api_version}"
    response = None
    try:
        if method not in ["get", "put", "delete"]:
            logging.warning(f"[call_search_api] Invalid method {method} ")

        if method == "get":
            response = requests.get(search_endpoint, headers=headers)
        elif method == "put":
            response = requests.put(search_endpoint, headers=headers, json=body)
        if method == "delete":
            response = requests.delete(search_endpoint, headers=headers)
            status_code = response.status_code
            logging.info(f"[call_search_api] Successfully called search API {method} {resource_type} {resource_name}. Code: {status_code}.")

        if response is not None:
            status_code = response.status_code
            if status_code >= 400:
                logging.warning(f"[call_search_api] {status_code} code when calling search API {method} {resource_type} {resource_name}. Reason: {response.reason}.")
                try:
                    response_text_dict = json.loads(response.text)
                    logging.warning(f"[call_search_api] {status_code} code when calling search API {method} {resource_type} {resource_name}. Message: {response_text_dict['error']['message']}")        
                except json.JSONDecodeError:
                    logging.warning(f"[call_search_api] {status_code} Response is not valid JSON. Raw response:\n{response.text}")
            else:
                logging.info(f"[call_search_api] Successfully called search API {method} {resource_type} {resource_name}. Code: {status_code}.")
    except Exception as e:
        error_message = str(e)
        logging.error(f"Error when calling search API {method} {resource_type} {resource_name}. Error: {error_message}")


def execute_setup():
    """
    This function performs the necessary steps to set up the ingestion sub components.
    """    
    credential = ChainedTokenCredential(
        ManagedIdentityCredential(),
        AzureCliCredential()
    )

    endpoint = os.environ.get("AZURE_APP_CONFIG_ENDPOINT")
    if not endpoint:
        logging.error("Environment variable 'AZURE_APP_CONFIG_ENDPOINT' is not set. Exiting.")
        exit(1)
    provision_config = AzureAppConfigurationClient(endpoint, credential)
    setting = provision_config.get_configuration_setting(key="PROVISION_CONFIG")
    cfg = json.loads(setting.value)
    subscription_id = cfg["AZURE_SUBSCRIPTION_ID"] 
    search_endpoint = cfg["AZURE_SEARCH_ENDPOINT"]
    app_name = cfg["AZURE_DATA_INGEST_CONTAINER_APP_NAME"]
    azure_openai_service_name = cfg["AZURE_OPENAI_SERVICE_NAME"]
    search_analyzer_name = cfg["AZURE_SEARCH_ANALYZER_NAME"]
    search_api_version  = cfg["AZURE_SEARCH_API_VERSION"]
    search_index_interval = cfg["AZURE_SEARCH_INDEX_INTERVAL"]
    search_index_name = cfg["AZURE_SEARCH_INDEX_NAME"]
    storage_container = cfg["AZURE_STORAGE_ACCOUNT_CONTAINER_DOCS"]
    storage_account_name = cfg["AZURE_SOLUTION_STORAGE_ACCOUNT_NAME"]
    network_isolation = True if cfg["AZURE_NETWORK_ISOLATION"].lower() == "true" else False
    azure_embeddings_vector_size =  cfg["AZURE_EMBEDDINGS_VECTOR_DIMENSIONS"]
    resource_group = cfg["AZURE_RESOURCE_GROUP"]
    azure_storage_resource_group = cfg["AZURE_RESOURCE_GROUP"]
    azure_aoai_resource_group =  cfg["AZURE_AOAI_RESOURCE_GROUP"]
    web_api_endpoint = get_container_app_fqdn(credential, subscription_id, resource_group, app_name)

    logging.info(f"[execute_setup] Subscription id: {subscription_id}")
    logging.info(f"[execute_setup] Search service endpoint: {search_endpoint}")
    logging.info(f"[execute_setup] Container app name: {app_name}")
    logging.info(f"[execute_setup] Azure OpenAI Service Name: {azure_openai_service_name}")      
    logging.info(f"[execute_setup] Search analyzer name: {search_analyzer_name}")
    logging.info(f"[execute_setup] Search API version: {search_api_version}")
    logging.info(f"[execute_setup] Search index interval: {search_index_interval}")
    logging.info(f"[execute_setup] Search index name: {search_index_name}")
    logging.info(f"[execute_setup] Storage container: {storage_container}")
    logging.info(f"[execute_setup] Storage account name: {storage_account_name}")
    logging.info(f"[execute_setup] Network isolation: {network_isolation}")    
    logging.info(f"[execute_setup] Embedding vector size: {azure_embeddings_vector_size}")
    logging.info(f"[execute_setup] Resource group: {resource_group}")  
    logging.info(f"[execute_setup] Storage resource group: {azure_storage_resource_group}") 
    logging.info(f"[execute_setup] Azure OpenAI resource group: {azure_aoai_resource_group}")        
    logging.info(f"[execute_setup] Web API endpoint: {web_api_endpoint}")

    ###########################################################################
    # NL2SQL Elements
    ###########################################################################
    storage_container_nl2sql          = "nl2sql"
    search_index_name_nl2sql_queries  = f"{search_index_name}-nl2sql-queries"
    search_index_name_nl2sql_tables   = f"{search_index_name}-nl2sql-tables"
    search_index_name_nl2sql_measures = f"{search_index_name}-nl2sql-measures"

    logging.info(f"[execute_setup] NL2SQL Storage container: {storage_container_nl2sql}")
    logging.info(f"[execute_setup] NL2SQL Search index name (queries): {search_index_name_nl2sql_queries}")
    logging.info(f"[execute_setup] NL2SQL Search index name (tables): {search_index_name_nl2sql_tables}")
    logging.info(f"[execute_setup] NL2SQL Search index name (measures): {search_index_name_nl2sql_measures}")

    ###########################################################################
    # Approve Search Shared Private Links (if needed)
    ########################################################################### 
    # logging.info("Approving search shared private links.")  
    # approve_search_shared_private_access(subscription_id, resource_group, azure_storage_resource_group, azure_aoai_resource_group, function_app_name, storage_account_name, azure_openai_service_name, credential)

    ###############################################################################
    # Creating AI Search datasource
    ###############################################################################
    def create_datasource(search_endpoint, search_api_version, datasource_name, storage_connection_string, container_name, credential, subfolder=None):
        body = {
            "description": f"Datastore for {datasource_name}",
            "type": "azureblob",
            "dataDeletionDetectionPolicy": {
                "@odata.type": "#Microsoft.Azure.Search.NativeBlobSoftDeleteDeletionDetectionPolicy"
            },
            "credentials": {
                "connectionString": storage_connection_string
            },
            "container": {
                "name": container_name,
                "query": f"{subfolder}/" if subfolder else ""
            }
        }
        call_search_api(search_endpoint, search_api_version, "datasources", f"{datasource_name}-datasource", "put", credential, body)

    logging.info("Creating datasources step.")
    start_time = time.time()
    storage_connection_string = f"ResourceId=/subscriptions/{subscription_id}/resourceGroups/{azure_storage_resource_group}/providers/Microsoft.Storage/storageAccounts/{storage_account_name}/;"
    create_datasource(search_endpoint, search_api_version, f"{search_index_name}", storage_connection_string, storage_container, credential)
    nl2sql_subfolders = {
        "queries": search_index_name_nl2sql_queries,
        "tables": search_index_name_nl2sql_tables,
        "measures": search_index_name_nl2sql_measures   # New datasource for measures
    }
    for subfolder, index_name in nl2sql_subfolders.items():
        create_datasource(search_endpoint, search_api_version, index_name, storage_connection_string, "nl2sql", credential, subfolder=subfolder)
    response_time = time.time() - start_time
    logging.info(f"Create datastores step. {round(response_time, 2)} seconds")

    ###############################################################################
    # Creating indexes
    ###############################################################################
    def create_index_body(index_name, fields, content_fields_name, keyword_field_name, vector_profile_name="myHnswProfile", vector_algorithm_name="myHnswConfig"):
        body = {
            "name": index_name,
            "fields": fields,
            "corsOptions": {
                "allowedOrigins": ["*"],
                "maxAgeInSeconds": 60
            },
            "vectorSearch": {
                "profiles": [
                    {
                        "name": vector_profile_name,
                        "algorithm": vector_algorithm_name
                    }
                ],
                "algorithms": [
                    {
                        "name": vector_algorithm_name,
                        "kind": "hnsw",
                        "hnswParameters": {
                            "m": 4,
                            "efConstruction": 400,
                            "efSearch": 500,
                            "metric": "cosine"
                        }
                    }
                ]
            },
            "semantic": {
                "configurations": [
                    {
                        "name": "my-semantic-config",
                        "prioritizedFields": {
                            "prioritizedContentFields": [
                                {
                                    "fieldName": field_name
                                }
                                for field_name in content_fields_name
                            ]
                        }
                    }
                ]
            }
        }
        if keyword_field_name is not None:
            body["semantic"]["configurations"][0]["prioritizedFields"]["prioritizedKeywordsFields"] = [
                {
                    "fieldName": keyword_field_name
                }
            ]
        return body

    logging.info("Creating indexes.")
    start_time = time.time()
    vector_profile_name = "myHnswProfile"
    vector_algorithm_name = "myHnswConfig"
    indices = [
        {
            "index_name": search_index_name,  # RAG index
            "fields": [
                {
                    "name": "id",
                    "type": "Edm.String",
                    "key": True,
                    "analyzer": "keyword",
                    "searchable": True,
                    "retrievable": True
                },
                {
                    "name": "parent_id",
                    "type": "Edm.String",
                    "searchable": False,
                    "retrievable": True
                },                
                {
                    "name": "metadata_storage_path",
                    "type": "Edm.String",
                    "searchable": False,
                    "sortable": False,
                    "filterable": False,
                    "facetable": False
                },
                {
                    "name": "metadata_storage_name",
                    "type": "Edm.String",
                    "searchable": False,
                    "sortable": False,
                    "filterable": False,
                    "facetable": False
                },
                {
                    "name": "metadata_storage_last_modified",
                    "type": "Edm.DateTimeOffset",
                    "searchable": False,
                    "sortable": True,
                    "retrievable": True,
                    "filterable": True
                },
                {
                    "name": "metadata_security_id",
                    "type": "Collection(Edm.String)",
                    "searchable": False,
                    "retrievable": True,
                    "filterable": True
                },                
                {
                    "name": "chunk_id",
                    "type": "Edm.Int32",
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "content",
                    "type": "Edm.String",
                    "searchable": True,
                    "retrievable": True,
                    "analyzer": search_analyzer_name 
                },
                {
                    "name": "imageCaptions",
                    "type": "Edm.String",
                    "searchable": True,
                    "retrievable": True,
                    "analyzer": search_analyzer_name 
                },                
                {
                    "name": "page",
                    "type": "Edm.Int32",
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "offset",
                    "type": "Edm.Int64",
                    "filterable": False,
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "length",
                    "type": "Edm.Int32",
                    "filterable": False,
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "title",
                    "type": "Edm.String",
                    "filterable": True,
                    "searchable": True,
                    "retrievable": True,
                    "analyzer": search_analyzer_name
                },
                {
                    "name": "category",
                    "type": "Edm.String",
                    "filterable": True,
                    "searchable": True,
                    "retrievable": True,
                    "analyzer": search_analyzer_name
                },
                {
                    "name": "filepath",
                    "type": "Edm.String",
                    "filterable": False,
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "url",
                    "type": "Edm.String",
                    "filterable": False,
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "summary",
                    "type": "Edm.String",
                    "filterable": False,
                    "searchable": True,
                    "retrievable": True
                },
                {
                    "name": "relatedImages",
                    "type": "Collection(Edm.String)",
                    "filterable": False,
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "relatedFiles",
                    "type": "Collection(Edm.String)",
                    "filterable": False,
                    "searchable": False,
                    "retrievable": True
                },
                {
                    "name": "source",
                    "type": "Edm.String",
                    "searchable": False,
                    "retrievable": True,
                    "filterable": True
                },
                {
                    "name": "contentVector",
                    "type": "Collection(Edm.Single)",
                    "searchable": True,
                    "retrievable": True,
                    "dimensions": azure_embeddings_vector_size,
                    "vectorSearchProfile": vector_profile_name
                },
                {
                    "name": "captionVector",
                    "type": "Collection(Edm.Single)",
                    "searchable": True,
                    "retrievable": True,
                    "dimensions": azure_embeddings_vector_size,
                    "vectorSearchProfile": vector_profile_name
                }
            ],
            "content_fields_name": ["content", "imageCaptions"],
            "keyword_field_name": "category"
        },
        {
            "index_name": search_index_name_nl2sql_queries,
            "fields": [
                {
                    "name": "id",
                    "type": "Edm.String",
                    "key": True,
                    "searchable": False,
                    "filterable": False,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "datasource",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": True,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },              
                {
                    "name": "question",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": False,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False,
                    "analyzer": search_analyzer_name
                },
                {
                    "name": "query",
                    "type": "Edm.String",
                    "searchable": False,
                    "filterable": False,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "reasoning",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": False,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "contentVector",
                    "type": "Collection(Edm.Single)",
                    "searchable": True,
                    "retrievable": True,
                    "dimensions": azure_embeddings_vector_size,
                    "vectorSearchProfile": vector_profile_name
                }
            ],
            "content_fields_name": ["question"],
            "keyword_field_name": None
        },
        {
            "index_name": search_index_name_nl2sql_tables,
            "fields": [
                {
                    "name": "id",
                    "type": "Edm.String",
                    "key": True,
                    "searchable": False,
                    "filterable": False,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "table",
                    "type": "Edm.String",
                    "searchable": True,
                    "retrievable": True
                },
                {
                    "name": "description",
                    "type": "Edm.String",
                    "searchable": True,
                    "retrievable": True,
                    "analyzer": search_analyzer_name
                },
                {
                    "name": "datasource",
                    "type": "Edm.String",
                    "searchable": True,
                    "retrievable": True
                },
                {
                    "name": "columns",
                    "type": "Collection(Edm.ComplexType)",
                    "fields": [
                        {
                            "name": "name",
                            "type": "Edm.String",
                            "searchable": True,
                            "retrievable": True
                        },
                        {
                            "name": "description",
                            "type": "Edm.String",
                            "searchable": True,
                            "retrievable": True,
                            "analyzer": search_analyzer_name
                        },
                        {
                            "name": "type",
                            "type": "Edm.String",
                            "searchable": False,
                            "retrievable": True
                        },
                        {
                            "name": "examples",
                            "type": "Collection(Edm.String)",
                            "searchable": False,
                            "retrievable": True
                        }
                    ]
                },
                {
                    "name": "contentVector",
                    "type": "Collection(Edm.Single)",
                    "searchable": True,
                    "retrievable": True,
                    "dimensions": azure_embeddings_vector_size,
                    "vectorSearchProfile": vector_profile_name
                }
            ],
            "content_fields_name": ["description"],
            "keyword_field_name": "table"
        },
        {
            "index_name": search_index_name_nl2sql_measures,
            "fields": [
                {
                    "name": "id",
                    "type": "Edm.String",
                    "key": True,
                    "searchable": False,
                    "filterable": False,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "datasource",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": True,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },              
                {
                    "name": "name",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": True,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },                
                {
                    "name": "description",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": False,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False,
                    "analyzer": search_analyzer_name
                },
                {
                    "name": "type",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": True,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "source_table",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": True,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "data_type",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": False,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "source_model",
                    "type": "Edm.String",
                    "searchable": True,
                    "filterable": False,
                    "retrievable": True,
                    "sortable": False,
                    "facetable": False
                },
                {
                    "name": "contentVector",
                    "type": "Collection(Edm.Single)",
                    "searchable": True,
                    "retrievable": True,
                    "dimensions": azure_embeddings_vector_size,
                    "vectorSearchProfile": vector_profile_name
                }
            ],
            "content_fields_name": ["description"],
            "keyword_field_name": "description"
        }
    ]
    for index in indices:
        body = create_index_body(
            index_name=index["index_name"],
            fields=index["fields"],
            content_fields_name=index["content_fields_name"],
            keyword_field_name=index["keyword_field_name"],
            vector_profile_name=vector_profile_name,
            vector_algorithm_name=vector_algorithm_name
        )
        call_search_api(search_endpoint, search_api_version, "indexes", index["index_name"], "delete", credential)
        call_search_api(search_endpoint, search_api_version, "indexes", index["index_name"], "put", credential, body)
    response_time = time.time() - start_time
    logging.info(f"Indexes created in {round(response_time, 2)} seconds")

    ###########################################################################
    # 04 Creating AI Search skillsets
    ###########################################################################
    logging.info("04 Creating skillsets step.")
    start_time = time.time()
    body = { 
        "name": f"{search_index_name}-skillset",
        "description":"SKillset to do document chunking",
        "skills":[ 
            { 
                "@odata.type":"#Microsoft.Skills.Custom.WebApiSkill",
                "name":"document-chunking",
                "description":"Extract chunks from documents.",
                "httpMethod":"POST",
                "timeout":"PT230S",
                "context":"/document",
                "batchSize":1,
                "inputs":[ 
                    {
                        "name":"documentUrl",
                        "source":"/document/metadata_storage_path"
                    },                   
                    { 
                        "name":"documentSasToken",
                        "source":"/document/metadata_storage_sas_token"
                    },
                    { 
                        "name":"documentContentType",
                        "source":"/document/metadata_content_type"
                    }
                ],
                "outputs":[ 
                    {
                        "name":"chunks",
                        "targetName":"chunks"
                    }
                ]
            }
        ],
        "indexProjections": {
            "selectors": [
                {
                    "targetIndexName":f"{search_index_name}",
                    "parentKeyFieldName": "parent_id",
                    "sourceContext": "/document/chunks/*",
                    "mappings": [
                        {
                            "name": "chunk_id",
                            "source": "/document/chunks/*/chunk_id",
                            "inputs": []
                        },
                        {
                            "name": "offset",
                            "source": "/document/chunks/*/offset",
                            "inputs": []
                        },
                        {
                            "name": "length",
                            "source": "/document/chunks/*/length",
                            "inputs": []
                        },
                        {
                            "name": "page",
                            "source": "/document/chunks/*/page",
                            "inputs": []
                        },
                        {
                            "name": "title",
                            "source": "/document/chunks/*/title",
                            "inputs": []
                        },
                        {
                            "name": "category",
                            "source": "/document/chunks/*/category",
                            "inputs": []
                        },
                        {
                            "name": "url",
                            "source": "/document/chunks/*/url",
                            "inputs": []
                        },
                        {
                            "name": "relatedImages",
                            "source": "/document/chunks/*/relatedImages",
                            "inputs": []
                        },
                        {
                            "name": "relatedFiles",
                            "source": "/document/chunks/*/relatedFiles",
                            "inputs": []
                        },
                        {
                            "name": "filepath",
                            "source": "/document/chunks/*/filepath",
                            "inputs": []
                        },
                        {
                            "name": "content",
                            "source": "/document/chunks/*/content",
                            "inputs": []
                        },
                        {
                            "name": "imageCaptions",
                            "source": "/document/chunks/*/imageCaptions",
                            "inputs": []
                        },                        
                        {
                            "name": "summary",
                            "source": "/document/chunks/*/summary",
                            "inputs": []
                        },
                        {
                            "name": "source",
                            "source": "/document/chunks/*/source",
                            "inputs": []
                        },
                        {
                            "name": "captionVector",
                            "source": "/document/chunks/*/captionVector",
                            "inputs": []
                        },                                                                              
                        {
                            "name": "contentVector",
                            "source": "/document/chunks/*/contentVector",
                            "inputs": []
                        },
                        {
                            "name": "metadata_storage_last_modified",
                            "source": "/document/metadata_storage_last_modified",
                            "inputs": []
                        },
                        {
                            "name": "metadata_storage_name",
                            "source": "/document/metadata_storage_name",
                            "inputs": []
                        },
                        {
                            "name": "metadata_storage_path",
                            "source": "/document/metadata_storage_path",
                            "inputs": []
                        },                        
                        {
                            "name": "metadata_security_id", 
                            "source": "/document/metadata_security_id",
                            "inputs": []
                        }                         
                    ]
                }
            ],
            "parameters": {
                "projectionMode": "skipIndexingParentDocuments"
            }
        }
    }
    body['skills'][0]['uri'] = f"https://{web_api_endpoint}/document-chunking"
    call_search_api(search_endpoint, search_api_version, "skillsets", f"{search_index_name}-skillset", "delete", credential)        
    call_search_api(search_endpoint, search_api_version, "skillsets", f"{search_index_name}-skillset", "put", credential, body)

    # creating skillsets for the NL2SQL indexes
    def create_embedding_skillset(skillset_name, resource_uri, input_field, output_field):
        skill = {
            "@odata.type":"#Microsoft.Skills.Custom.WebApiSkill",
            "name": f"{skillset_name}-skill",
            "description": f"Generates embeddings for {input_field}.",
            "uri": resource_uri,
            "httpMethod":"POST",
            "batchSize": 1,
            "timeout":"PT60S",
            "context":"/document",
            "inputs": [
                {
                "name": "id",
                "source": "/document/id"
                },
                {
                "name": "text",
                "source": f"/document/{input_field}"
                }
            ],
            "outputs": [
                {
                "name": "embedding",
                "targetName": output_field
                }
            ]
        }

        skillset_body = {
            "name": skillset_name,
            "description": f"Skillset for generating embeddings for {skillset_name} index.",
            "skills": [skill]
        }
        return skillset_body

    resource_uri = f"https://{web_api_endpoint}/text-embedding"
    skillsets = [
        {
            "skillset_name": f"{search_index_name}-nl2sql-queries-skillset",
            "input_field": "question",
            "output_field": "contentVector"
        },
        {
            "skillset_name": f"{search_index_name}-nl2sql-tables-skillset",
            "input_field": "description",
            "output_field": "contentVector"
        },
        {
            "skillset_name": f"{search_index_name}-nl2sql-measures-skillset",
            "input_field": "description",
            "output_field": "contentVector"
        }
    ]
    for skillset in skillsets:
        body = create_embedding_skillset(
            skillset_name=skillset["skillset_name"],
            resource_uri=resource_uri,
            input_field=skillset["input_field"],
            output_field=skillset["output_field"]
        )
        call_search_api(search_endpoint, search_api_version, "skillsets", skillset["skillset_name"], "delete", credential)
        call_search_api(search_endpoint, search_api_version, "skillsets", skillset["skillset_name"], "put", credential, body)
        logging.info(f"Skillset '{skillset['skillset_name']}' created successfully.")
    response_time = time.time() - start_time
    logging.info(f"04 Create skillset step. {round(response_time,2)} seconds")

    ###########################################################################
    # 05 Creating indexers
    ###########################################################################
    logging.info("05 Creating indexer step.")
    start_time = time.time()
    body = {
        "dataSourceName" : f"{search_index_name}-datasource",
        "targetIndexName" : f"{search_index_name}",
        "skillsetName" : f"{search_index_name}-skillset",
        "schedule" : { "interval" : f"{search_index_interval}"},
        "fieldMappings" : [
            {
                "sourceFieldName" : "metadata_storage_path",
                "targetFieldName" : "id",
                "mappingFunction" : {
                    "name" : "fixedLengthEncode"
                }
            }            
        ],
        "outputFieldMappings" : [
        ],
        "parameters":
        {
            "batchSize": 1,
            "maxFailedItems":-1,
            "maxFailedItemsPerBatch":-1,
            "base64EncodeKeys": True,
            "configuration": 
            {
                "dataToExtract": "allMetadata"
            }
        }
    }
    if network_isolation: 
        body['parameters']['configuration']['executionEnvironment'] = "private"
    call_search_api(search_endpoint, search_api_version, "indexers", f"{search_index_name}", "put", credential, body)

    def create_indexer_body(indexer_name, index_name, data_source_name, skillset_name, field_mappings=None, indexing_parameters=None):
        body = {
            "name": indexer_name,
            "dataSourceName": data_source_name,
            "targetIndexName": index_name,
            "skillsetName": skillset_name,
            "schedule": {
                "interval": "PT2H"
            },
            "fieldMappings": field_mappings if field_mappings else [],
            "outputFieldMappings": [
                {
                    "sourceFieldName": "/document/contentVector",
                    "targetFieldName": "contentVector"
                }
            ],
            "parameters":
            {
                "configuration": {
                    "parsingMode": "json"
                }
            }            
        }
        if indexing_parameters:
            body["parameters"] = indexing_parameters
        return body

    field_mappings_queries = [
        {
            "sourceFieldName" : "metadata_storage_path",
            "targetFieldName" : "id",
            "mappingFunction" : {
                "name" : "fixedLengthEncode"
            }
        },
        {
            "sourceFieldName": "datasource",
            "targetFieldName": "datasource"
        },              
        {
            "sourceFieldName": "question",
            "targetFieldName": "question"
        },
        {
            "sourceFieldName": "query",
            "targetFieldName": "query"
        },
        {
            "sourceFieldName": "reasoning",
            "targetFieldName": "reasoning"
        }
    ]
    field_mappings_tables = [
        {
            "sourceFieldName": "metadata_storage_path",
            "targetFieldName": "id",
            "mappingFunction": {
                "name": "fixedLengthEncode"
            }
        },
        {
            "sourceFieldName": "table",
            "targetFieldName": "table"
        },
        {
            "sourceFieldName": "description",
            "targetFieldName": "description"
        },
        {
            "sourceFieldName": "datasource",
            "targetFieldName": "datasource"
        },
        {
            "sourceFieldName": "columns",
            "targetFieldName": "columns"
        }
    ]
    # New field mappings for the measures index
    field_mappings_measures = [
        {
            "sourceFieldName": "metadata_storage_path",
            "targetFieldName": "id",
            "mappingFunction": {
                "name": "fixedLengthEncode"
            }
        },
        {
            "sourceFieldName": "datasource",
            "targetFieldName": "datasource"
        },
        {
            "sourceFieldName": "name",
            "targetFieldName": "name"
        },
        {
            "sourceFieldName": "description",
            "targetFieldName": "description"
        },
        {
            "sourceFieldName": "type",
            "targetFieldName": "type"
        },
        {
            "sourceFieldName": "source_table",
            "targetFieldName": "source_table"
        },
        {
            "sourceFieldName": "data_type",
            "targetFieldName": "data_type"
        },
        {
            "sourceFieldName": "source_model",
            "targetFieldName": "source_model"
        }
    ]
    indexing_parameters = {
        "configuration": {
            "parsingMode": "json"
        }
    }


    skillsets = [
        {
            "skillset_name": f"{search_index_name}-nl2sql-queries-skillset",
            "input_field": "question",
            "output_field": "contentVector"
        },
        {
            "skillset_name": f"{search_index_name}-nl2sql-tables-skillset",
            "input_field": "description",
            "output_field": "contentVector"
        },
        {
            "skillset_name": f"{search_index_name}-nl2sql-measures-skillset",
            "input_field": "description",
            "output_field": "contentVector"
        }
    ]


    indexers = [
        {
            "indexer_name": f"{search_index_name}-nl2sql-queries-indexer",
            "index_name": f"{search_index_name_nl2sql_queries}",
            "data_source_name": f"{search_index_name_nl2sql_queries}-datasource",
            "skillset_name": f"{search_index_name}-nl2sql-queries-skillset",
            "field_mappings": field_mappings_queries,
            "indexing_parameters": indexing_parameters
        },
        {
            "indexer_name": f"{search_index_name}-nl2sql-tables-indexer",
            "index_name": f"{search_index_name_nl2sql_tables}",
            "data_source_name": f"{search_index_name_nl2sql_tables}-datasource",
            "skillset_name": f"{search_index_name}-nl2sql-tables-skillset",
            "field_mappings": field_mappings_tables,
            "indexing_parameters": indexing_parameters
        },
        {
            "indexer_name": f"{search_index_name}-nl2sql-measures-indexer", 
            "index_name": f"{search_index_name_nl2sql_measures}",
            "data_source_name": f"{search_index_name_nl2sql_measures}-datasource",
            "skillset_name": f"{search_index_name}-nl2sql-measures-skillset",
            "field_mappings": field_mappings_measures,
            "indexing_parameters": indexing_parameters
        }
    ]
    for indexer in indexers:
        body = create_indexer_body(
            indexer_name=indexer["indexer_name"],
            index_name=indexer["index_name"],
            data_source_name=indexer["data_source_name"],
            skillset_name=indexer["skillset_name"],
            field_mappings=indexer["field_mappings"]
        )
        call_search_api(search_endpoint, search_api_version, "indexers", indexer["indexer_name"], "delete", credential)
        call_search_api(search_endpoint, search_api_version, "indexers", indexer["indexer_name"], "put", credential, body)
        logging.info(f"Indexer '{indexer['indexer_name']}' created successfully.")
    response_time = time.time() - start_time
    logging.info(f"05 Create indexers step. {round(response_time,2)} seconds")

def main():
    """
    Sets up a chunking function app in Azure.
    """   
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    logging.info(f"Starting setup.")    
    start_time = time.time()
    execute_setup()
    response_time = time.time() - start_time
    logging.info(f"🎉 Finished setup. {round(response_time,2)} seconds")

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')    
    main()