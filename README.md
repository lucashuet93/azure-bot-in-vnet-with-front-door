# Bot in VNet with Azure Front Door

## Deployment

### Deploying the Base Infrastructure

- Rename `sample.env` to `.env` and add values accordingly
- Open the root directory in bash
- Login to Azure - `az login`
- Run the deployment script - `./scripts/deploy.sh`

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