# Bot in VNet with Azure Front Door

## Deployment

### Deploying the Base Infrastructure

- Navigate to the `./infra/base` directory
- Initialize the project - `terraform init`
- Update the variable values in `terraform.tfvars`
- Deploy the infrastructure - `terraform apply --var-file="terraform.tfvars"`

### Deploying the Bot Code

- Navigate to the root directory
- Add the User Assigned Managed Identity properties from the terraform outputs to the `./bot/EchoBot/appsettings.json` file
- Zip up the contents excluding the .sln file inside `./bot/EchoBot`, naming the file `bot-deployment.zip`
- Deploy the code to the Azure App Service - `az webapp deploy --resource-group ${RG_NAME} --name ${APP_SERVICE_NAME} --src-path './bot/EchoBot/bot-deployment.zip'`

### Deploying the VNet Integration Infrastructure
 
- List the App Service's private endpoint requests - `az network private-endpoint-connection list -g ${RG_NAME} -n ${APP_SERVICE_NAME} --type Microsoft.Web/sites`
- Approve the private endpoint request from front door on the app service - `az network private-endpoint-connection approve -g ${RG_NAME} -n ${GUID_NAME_FROM_LIST_COMMAND_OUTPUT} --resource-name ${APP_SERVICE_NAME} --type Microsoft.Web/sites --description "Request made via Terraform"`
- Only allow traffic from selected networks on the app service - `az webapp config access-restriction set -g ${RG_NAME} -n ${APP_SERVICE_NAME} --default-action Deny --use-same-restrictions-for-scm-site true`

## Testing the Solution

### Ensure Bot is Publicly Inaccessible

- Navigate to the Azure Portal and find the newly created resource group
- Select the Azure App Service resource and click "Browse"
- Observe the 403 response

Alternatively, you can attempt to connect to the App Service's messaging endpoint via the Bot Framework Emulator and observe the same behavior.

### Ensure Bot is Privately Accessible

- Navigate to the Azure Portal and find the newly created resource group
- Select the Virtual Network resource and find the "Bastion" blade
- Enter your username and password used in Terraform parameters to connect to Bastion
- Open Powershell within the jumpbox
- Observe that the App Services domain name resolves to the correct IP address for the Private Endpoint - `nslookup ${APP_SERVICE_DOMAIN_NAME}`

### Ensure Bot is Accessible Via Microsoft Teams

- Navigate to the Azure Portal and find the newly created resource group
- Select the Bot resource and find the "Channels" blade
- Find Microsoft Teams and click "Open in Teams"
- Chat with the bot