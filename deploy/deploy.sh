# define variables
RG_NAME="app-oauth-demo-rg"
LOCATION="australiaeast"
DEPLOYMENT_NAME="infra-deployment"
APP_REG_NAME="backend-app-reg"
ACR_NAME="cbelleeacr398239f"

# create resource group
az group create --name $RG_NAME --location $LOCATION

# get the role 'id' from ./manifest.json
ROLE_GUID=$(cat ./manifest.json | jq -r '.[] | {id} | join(" ")')

# create a new application registration to represent the backend app
APP_ID=$(az ad app create --display-name ${APP_REG_NAME} --app-roles @manifest.json --query appId -o tsv)

# create a new service principal using the backend app's application registration
if [ $(az ad sp list --filter "appId eq '${APP_ID}'" --query "[] | length(@)") -gt 0 ]; then
    # return the new service principal's objectId
    SP_OBJECT_ID=$(az ad sp list --filter "appId eq '${APP_ID}'" --query "[].objectId" -o tsv)
else
    # if the service principal exists then retuen its objectId
    SP_OBJECT_ID=$(az ad sp create --id ${APP_ID} --query objectId -o tsv)
fi

echo "BACKEND SP_OBJECT_ID: ${SP_OBJECT_ID}"
echo "BACKEND APP_ID: ${APP_ID}"

# deploy Azure resouces
az deployment group create \
    --resource-group ${RG_NAME} \
    --name ${DEPLOYMENT_NAME} \
    --template-file ./deploy/azuredeploy.bicep \
    --parameters backendAppId=${APP_ID} \
    --parameters acrName=${ACR_NAME}

# get the frontend app's Managed Identity objectId from the deployment output
FRONT_END_MI_OBJECT_ID=$(az deployment group show \
    --resource-group ${RG_NAME} \
    --name ${DEPLOYMENT_NAME} \
    --query properties.outputs.frontendMIObjectId.value -o tsv)

# build URI to MSGraph to add frontend Managed Identity to backend 'apiaccess' role
URI="https://graph.microsoft.com/beta/servicePrincipals/${FRONT_END_MI_OBJECT_ID}/appRoleAssignments"
echo "appRoleAssignments URI: ${URI}"

# add the frontend Managed Identity to backend 'apiaccess' role
# will produce an error if the assignmet already exists, which can be ignored
az rest \
    --headers Content-Type=application/json \
    --method POST \
    --uri $URI \
    --body "{\"principalId\": \"${FRONT_END_MI_OBJECT_ID}\", \"resourceId\": \"${SP_OBJECT_ID}\", \"appRoleId\": \"${ROLE_GUID}\"}"

# verify that the frontend app can authN to the backend app
curl https://cbellee-app-oauth-demo-fe.azurewebsites.net/helloFrontend

# output: 
hello from backend website: app-svc-oauth-demo-be.azurewebsites.net%  

# verify the backend returns 401 (Unauthorised) when accessed directly
curl https://cbellee-app-oauth-demo-be.azurewebsites.net/helloBackend -v

# output:
# GET /helloBackend HTTP/1.1
#> Host: cbellee-app-oauth-demo-be.azurewebsites.net
#> User-Agent: curl/7.68.0
#> Accept: */*
#>
#* Mark bundle as not supporting multiuse
#< HTTP/1.1 401 Unauthorized
#< WWW-Authenticate: Bearer realm="cbellee-app-oauth-demo-be.azurewebsites.net"