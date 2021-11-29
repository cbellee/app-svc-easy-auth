while getopts g:l:a: flag
do
    case "${flag}" in
        g) RG_NAME=${OPTARG};;
        l) LOCATION=${OPTARG};;
        a) APP_REG_NAME=${OPTARG};;
    esac
done

# define variables
DEPLOYMENT_NAME="infra-deployment"

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
    --template-file ./azuredeploy.bicep \
    --parameters location=${LOCATION} \
    --parameters backendAppId=${APP_ID}

# get the frontend app's Managed Identity objectId from the deployment output
FRONT_END_MI_OBJECT_ID=$(az deployment group show \
    --resource-group ${RG_NAME} \
    --name ${DEPLOYMENT_NAME} \
    --query properties.outputs.frontendMIObjectId.value -o tsv)

FRONT_END_APP_URI=$(az deployment group show \
    --resource-group ${RG_NAME} \
    --name ${DEPLOYMENT_NAME} \
    --query properties.outputs.frontEndAppUri.value -o tsv)

BACK_END_APP_URI=$(az deployment group show \
    --resource-group ${RG_NAME} \
    --name ${DEPLOYMENT_NAME} \
    --query properties.outputs.backEndAppUri.value -o tsv)

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
curl https://${FRONT_END_APP_URI}/helloFrontend

# output: 
hello from backend website: f92fcna9e7c7wfh-be.azurewebsites.net%  

# verify the backend returns 401 (Unauthorised) when accessed directly
curl https://${BACK_END_APP_URI}/helloBackend -v

# output:
# GET /helloBackend HTTP/1.1
#> Host: sdf9sefef9ef98f89e-be.azurewebsites.net
#> User-Agent: curl/7.68.0
#> Accept: */*
#>
#* Mark bundle as not supporting multiuse
#< HTTP/1.1 401 Unauthorized
#< WWW-Authenticate: Bearer realm="sdf9sefef9ef98f89e-be.azurewebsites.net"