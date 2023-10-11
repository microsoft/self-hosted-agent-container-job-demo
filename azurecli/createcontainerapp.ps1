# az login
az upgrade
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights

# set variables
$RESOURCE_GROUP="aca-jobs-sample"
$LOCATION="westeurope"
$ENVIRONMENT="aca-env-jobs-sample"
$JOB_NAME="azure-pipelines-agent-job"
$PLACEHOLDER_JOB_NAME="placeholder-agent-job"
$VNET_NAME="aca-jobs-sample-vnet"

# create container app environment
az group create `
    --name "$RESOURCE_GROUP" `
    --location "$LOCATION"

az network vnet create `
    --resource-group $RESOURCE_GROUP `
    --name $VNET_NAME `
    --location $LOCATION `
    --address-prefix 20.0.0.0/16

az network vnet subnet create `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $VNET_NAME `
    --name infrastructure-subnet `
    --address-prefixes 20.0.0.0/23 

# Get subnet resource id
$INFRASTRUCTURE_SUBNET=az network vnet subnet show --resource-group ${RESOURCE_GROUP} --vnet-name $VNET_NAME --name infrastructure-subnet --query "id" -o tsv

Write-Host "Creating cointainer app environment. Subnet resource id: $INFRASTRUCTURE_SUBNET"

az containerapp env create `
   --name $ENVIRONMENT `
   --resource-group $RESOURCE_GROUP `
   --infrastructure-subnet-resource-id $INFRASTRUCTURE_SUBNET `
   --location $LOCATION

$AZP_TOKEN=az keyvault secret show --name container-apps-self-hosted-agent --vault-name platform-management --query "value" --out tsv
$ORGANIZATION_URL="https://dev.azure.com/SwissCSURockStars"
$AZP_POOL="container-apps"


# Build the Azure Pipelines agent container image

$CONTAINER_IMAGE_NAME="azure-pipelines-agent:1.0"
$CONTAINER_REGISTRY_NAME="demoacajobsselfhosted"

Write-Host "Creating Cointainer Registry: $CONTAINER_REGISTRY_NAME"

az acr create `
  --name "$CONTAINER_REGISTRY_NAME" `
  --resource-group "$RESOURCE_GROUP" `
  --location "$LOCATION" `
  --sku Basic `
  --admin-enabled true

az acr build `
  --registry "$CONTAINER_REGISTRY_NAME" `
  --image "$CONTAINER_IMAGE_NAME" `
  --file "Dockerfile.azure-pipelines" `
  "https://github.com/zojovano-demos/container-apps-ci-cd-runner-tutorial.git"
  

# Create a placeholder self-hosted agent
az containerapp job create -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP" --environment "$ENVIRONMENT" `
  --trigger-type Manual `
  --replica-timeout 300 `
  --replica-retry-limit 1 `
  --replica-completion-count 1 `
  --parallelism 1 `
  --image "$CONTAINER_REGISTRY_NAME.azurecr.io/$CONTAINER_IMAGE_NAME" `
  --cpu "2.0" `
  --memory "4Gi" `
  --secrets "personal-access-token=$AZP_TOKEN" "organization-url=$ORGANIZATION_URL" `
  --env-vars "AZP_TOKEN=secretref:personal-access-token" "AZP_URL=secretref:organization-url" "AZP_POOL=$AZP_POOL" "AZP_PLACEHOLDER=1" "AZP_AGENT_NAME=placeholder-agent" `
  --registry-server "$CONTAINER_REGISTRY_NAME.azurecr.io" 

az containerapp job start -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP"

az containerapp job execution list `
  --name "$PLACEHOLDER_JOB_NAME" `
  --resource-group "$RESOURCE_GROUP" `
  --output table `
  --query '[].{Status: properties.status, Name: name, StartTime: properties.startTime}' 

az containerapp job delete -n "$PLACEHOLDER_JOB_NAME" -g "$RESOURCE_GROUP"  

# Create a self-hosted agent as an event-driven job
az containerapp job create -n "$JOB_NAME" -g "$RESOURCE_GROUP" --environment "$ENVIRONMENT" `
  --trigger-type Event `
  --replica-timeout 1800 `
  --replica-retry-limit 1 `
  --replica-completion-count 1 `
  --parallelism 1 `
  --image "$CONTAINER_REGISTRY_NAME.azurecr.io/$CONTAINER_IMAGE_NAME" `
  --min-executions 0 `
  --max-executions 10 `
  --polling-interval 30 `
  --scale-rule-name "azure-pipelines" `
  --scale-rule-type "azure-pipelines" `
  --scale-rule-metadata "poolName=container-apps" "targetPipelinesQueueLength=1" `
  --scale-rule-auth "personalAccessToken=personal-access-token" "organizationURL=organization-url" `
  --cpu "2.0" `
  --memory "4Gi" `
  --secrets "personal-access-token=$AZP_TOKEN" "organization-url=$ORGANIZATION_URL" `
  --env-vars "AZP_TOKEN=secretref:personal-access-token" "AZP_URL=secretref:organization-url" "AZP_POOL=$AZP_POOL" `
  --registry-server "$CONTAINER_REGISTRY_NAME.azurecr.io"  


# Deploy App Service Web App

$APP_SERVICE_PLAN_NAME="aca-jobs-sample-plan"
$APP_SERVICE_NAME="aca-jobs-sample"
$APP_SERVICE_SUBNET_NAME="acajobsappservice"

az appservice plan create `
    --name "$APP_SERVICE_PLAN_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --location "$LOCATION" `
    --sku P1V2 `
    --number-of-workers 1

az webapp create `
    --name $APP_SERVICE_NAME `
    --resource-group "$RESOURCE_GROUP" `
    --plan "$APP_SERVICE_PLAN_NAME"


az network vnet subnet create `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $VNET_NAME `
    --name $APP_SERVICE_SUBNET_NAME `
    --address-prefixes 20.1.0.0/23 

az network vnet subnet update `
    --name "$APP_SERVICE_SUBNET_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --vnet-name "$VNET_NAME" `
    --disable-private-endpoint-network-policies true

$SUBSCRIPTION_ID = az account show --query id --output tsv
$APP_SERVICE_ENDPOINT_NAME ="appServiceEndpoint"

az network private-endpoint create `
    --name "$APP_SERVICE_ENDPOINT_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --vnet-name "$VNET_NAME" `
    --subnet "$APP_SERVICE_SUBNET_NAME" `
    --connection-name appServiceConnection `
    --private-connection-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/myWebApp" `
    --group-id sites

az network private-dns zone create `
    --name privatelink.azurewebsites.net `
    --resource-group "$RESOURCE_GROUP"
    
az network private-dns link vnet create `
    --name appServiceDNSLink `
    --resource-group "$RESOURCE_GROUP" `
    --registration-enabled false `
    --virtual-network "$VNET_NAME" `
    --zone-name privatelink.azurewebsites.net
    
az network private-endpoint dns-zone-group create `
    --name appServiceZoneGroup `
    --resource-group "$RESOURCE_GROUP" `
    --endpoint-name "$APP_SERVICE_ENDPOINT_NAME" `
    --private-dns-zone privatelink.azurewebsites.net `
    --zone-name privatelink.azurewebsites.net