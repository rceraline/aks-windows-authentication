$resourceGroup = "rg-winauth-01"
$location = "Canada Central"

az group create --name $resourceGroup --location $location

# wait for connection to be ready
Start-Sleep -Seconds 5

az deployment group create --resource-group $resourceGroup `
    --mode Complete `
    --name winauth `
    --template-file .\main.bicep `
    --parameters .\main.bicepparam

