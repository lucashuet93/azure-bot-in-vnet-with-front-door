#!/bin/bash
set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ -f "$script_dir/../.env" ]]; then
	echo "Loading .env"
	source "$script_dir/../.env"
fi

echo "Checking for required environment variables"

if [[ ${#PREFIX} -eq 0 ]]; then
  echo 'ERROR: Missing environment variable PREFIX' 1>&2
  exit 6
else
  PREFIX="${PREFIX%$'\r'}"
fi

if [[ ${#LOCATION} -eq 0 ]]; then
  echo 'ERROR: Missing environment variable LOCATION' 1>&2
  exit 6
else
  LOCATION="${LOCATION%$'\r'}"  
fi

if [[ ${#ADMIN_USERNAME} -eq 0 ]]; then
  echo 'ERROR: Missing environment variable ADMIN_USERNAME' 1>&2
  exit 6
else
  ADMIN_USERNAME="${ADMIN_USERNAME%$'\r'}"  
fi

if [[ ${#ADMIN_PASSWORD} -eq 0 ]]; then
  echo 'ERROR: Missing environment variable ADMIN_USERNAME' 1>&2
  exit 6
else
  ADMIN_PASSWORD="${ADMIN_PASSWORD%$'\r'}"  
fi

cd "$script_dir/../infra/"

echo "Deploying Terraform infrastructure"
terraform init
terraform apply -var="prefix=${PREFIX}" -var="location=${LOCATION}" -var="admin_username=${ADMIN_USERNAME}" -var="admin_password=${ADMIN_PASSWORD}" --auto-approve

echo "Retrieving Terraform outputs"
RESOURCE_GROUP_NAME=$(terraform output resource_group_name | sed 's/^"//;s/"$//')
APP_SERVICE_NAME=$(terraform output app_service_name | sed 's/^"//;s/"$//')
UAMSI_CLIENT_ID=$(terraform output user_assigned_managed_identity_client_id | sed 's/^"//;s/"$//')
UAMSI_TENANT_ID=$(terraform output user_assigned_managed_identity_tenant_id | sed 's/^"//;s/"$//')

cd "$script_dir/../bot/EchoBot/"

echo "Writing appsettings.json"
sed -i -e "s/UAMSI_CLIENT_ID/${UAMSI_CLIENT_ID}/g" ./appsettings.json
sed -i -e "s/UAMSI_TENANT_ID/${UAMSI_TENANT_ID}/g" ./appsettings.json

echo "Creating zip file for bot deployment"
powershell Compress-Archive -Path "./*" -DestinationPath "./bot-deployment.zip" -Force

echo "Deploying bot"
az webapp deploy --resource-group $RESOURCE_GROUP_NAME --name $APP_SERVICE_NAME --src-path './bot-deployment.zip'

echo "Approving private endpoint connection request from Front Door to the App Service"
ALL_PRIVATE_ENDPOINT_CONNECTIONS=$(az network private-endpoint-connection list -g $RESOURCE_GROUP_NAME -n $APP_SERVICE_NAME --type Microsoft.Web/sites)
PENDING_CONNECTIONS=$(echo $ALL_PRIVATE_ENDPOINT_CONNECTIONS | jq -r '.[] | select(.properties.privateLinkServiceConnectionState.description == "Request made via Terraform" and .properties.privateLinkServiceConnectionState.status == "Pending") | .name')
for PENDING_CONNECTION in $PENDING_CONNECTIONS; do
  az network private-endpoint-connection approve -g $RESOURCE_GROUP_NAME -n $PENDING_CONNECTION --resource-name $APP_SERVICE_NAME --type Microsoft.Web/sites --description "Request made via Terraform"
done

echo "Restricting network access to the App Service"
az webapp config access-restriction set -g $RESOURCE_GROUP_NAME -n $APP_SERVICE_NAME --default-action Deny --use-same-restrictions-for-scm-site true