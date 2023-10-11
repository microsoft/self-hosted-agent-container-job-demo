# az login


# set variables
$RESOURCE_GROUP="aca-jobs-sample"
$LOCATION="westeurope"
$VNET_NAME="aca-jobs-sample-vnet"


# Deploy App Service Web App

$APP_SERVICE_PLAN_NAME="aca-jobs-sample-plan"
$APP_SERVICE_NAME="aca-jobs-sample"
$APP_SERVICE_SUBNET_NAME="acajobsappservice"

Write-Host "Creating resource group $RESOURCE_GROUP in $LOCATION"

az appservice plan create `
    --name "$APP_SERVICE_PLAN_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --location "$LOCATION" `
    --sku B1 `
    --number-of-workers 1

az webapp create `
    --name "$APP_SERVICE_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --plan "$APP_SERVICE_PLAN_NAME"

Write-Host "Creating subnet $APP_SERVICE_SUBNET_NAME in $VNET_NAME"

az network vnet subnet create `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $VNET_NAME `
    --name $APP_SERVICE_SUBNET_NAME `
    --address-prefixes 20.0.2.0/23

Write-Host "Updating subnet $APP_SERVICE_SUBNET_NAME in $VNET_NAME"

az network vnet subnet update `
    --name "$APP_SERVICE_SUBNET_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --vnet-name "$VNET_NAME" `
    --disable-private-endpoint-network-policies true

$SUBSCRIPTION_ID=az account show --query id --output tsv
$APP_SERVICE_ENDPOINT_NAME="appServiceEndpoint"

Write-Host "Creating private endpoint $APP_SERVICE_ENDPOINT_NAME in $VNET_NAME"

az network private-endpoint create `
    -n $APP_SERVICE_ENDPOINT_NAME `
    -g $RESOURCE_GROUP `
    --vnet-name $VNET_NAME `
    --subnet $APP_SERVICE_SUBNET_NAME `
    --connection-name appServiceConnection `
    --private-connection-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_SERVICE_NAME" `
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

Write-Host "Creating VM in $VNET_NAME"
$VMNAME="acajobssamplevm"
$USERNAME="zojovano"
$VM_SUBNET_NAME="acajobsvm"

$ADMIN_PASSWORD=az keyvault secret show --name zojovano --vault-name platform-management --query "value" --out tsv
$SECURE_PASSWORD = ConvertTo-SecureString -String $ADMIN_PASSWORD -AsPlainText -Force

az network vnet subnet create `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $VNET_NAME `
    --name $VM_SUBNET_NAME `
    --address-prefixes 20.0.4.0/27
 

az vm create `
    -g $RESOURCE_GROUP `
    -n $VMNAME `
    --image MicrosoftWindowsDesktop:windows-ent-cpc:win11-22h2-ent-cpc-os:22621.2283.230912 `
    --vnet-name $VNET_NAME `
    --subnet $VM_SUBNET_NAME `
    --authentication-type password `
    --admin-username $USERNAME `
    --admin-password $SECURE_PASSWORD `
    --public-ip-address """"
