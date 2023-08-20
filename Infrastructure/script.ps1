$resourceGroup = "rg-winauth-01"
$location = "Canada Central"

az group create --name $resourceGroup --location $location

az deployment group create --resource-group $resourceGroup `
    --mode Complete `
    --name winauth `
    --template-file .\main.bicep `
    --parameters .\main.bicepparam