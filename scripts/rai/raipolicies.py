# scripts/rai/raipolicies.py
#!/usr/bin/env python
import os
import sys
import logging

from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource.policy import PolicyClient
from azure.mgmt.resource.policy.models import PolicyAssignment

# Load from .env if present
load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

REQUIRED_ENV_VARS = [
    "AZURE_SUBSCRIPTION_ID",
    "AZURE_RESOURCE_GROUP",
    "AZURE_AI_SERVICES_NAME",
    "AZURE_CHAT_DEPLOYMENT_NAME"
]

def check_env_vars():
    logging.info("The following environment variables are required:")
    for name in REQUIRED_ENV_VARS:
        logging.info("  • %s", name)

    missing = [v for v in REQUIRED_ENV_VARS if not os.environ.get(v)]
    if missing:
        logging.info("")  # blank line
        logging.error("Missing environment variables:")
        for name in missing:
            logging.error("  • %s", name)
        sys.exit(1)

def main():
    check_env_vars()

    sub_id     = os.environ["AZURE_SUBSCRIPTION_ID"]
    rg         = os.environ["AZURE_RESOURCE_GROUP"]
    ai_service = os.environ["AZURE_AI_SERVICES_NAME"]
    chat_dep   = os.environ["AZURE_CHAT_DEPLOYMENT_NAME"]

    # Scope to your AI Chat deployment resource
    scope = (
        f"/subscriptions/{sub_id}"
        f"/resourceGroups/{rg}"
        f"/providers/Microsoft.CognitiveServices"
        f"/accounts/{ai_service}"
        f"/deployments/{chat_dep}"
    )

    cred   = DefaultAzureCredential()
    client = PolicyClient(cred, sub_id)

    for policy in ("MainRAIpolicy", "MainBlockListPolicy"):
        assignment_name = f"{policy}-assignment"
        definition_id   = (
            f"/subscriptions/{sub_id}"
            f"/providers/Microsoft.Authorization"
            f"/policyDefinitions/{policy}"
        )

        logging.info("Assigning policy '%s' to scope '%s'…", policy, scope)
        client.policy_assignments.create(
            scope=scope,
            policy_assignment_name=assignment_name,
            parameters=PolicyAssignment(policy_definition_id=definition_id)
        )

    logging.info("✅ RAI policies applied successfully.")

if __name__ == "__main__":
    main()
