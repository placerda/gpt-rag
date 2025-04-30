#!/bin/sh

# Delete the gpt-rag-ingestion folder from .azure if it exists
if [ -d ./.azure/gpt-rag-ingestion ]; then
    rm -rf ./.azure/gpt-rag-ingestion
fi
git clone --branch 2.0.0 https://github.com/placerda/gpt-rag-ingestion ./.azure/gpt-rag-ingestion

# Delete the gpt-rag-orchestrator folder from .azure if it exists
if [ -d ./.azure/gpt-rag-orchestrator ]; then
    rm -rf ./.azure/gpt-rag-orchestrator
fi
git clone --branch 2.0.0 https://github.com/placerda/gpt-rag-agentic ./.azure/gpt-rag-orchestrator

# Delete the gpt-rag-frontend folder from .azure if it exists
if [ -d ./.azure/gpt-rag-frontend ]; then
    rm -rf ./.azure/gpt-rag-frontend
fi
git clone --branch 2.0.0 https://github.com/placerda/gpt-rag-ui ./.azure/gpt-rag-frontend
