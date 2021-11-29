# app-svc-easy-auth

## pre-requisites
- Azure subscription
- Azure CLI
- Bash shell
- VS Code (optional) 

## deployment
- clone this repo
- modify /makefile to change the following variables to your desired values
  -  RG_NAME (Resource Group Name)
  -  LOCATION (Azure datacenter location)
  -  APP_REG_NAME (application registration name)
- execute the deployment
  - `$ make deployment`
- once the deployment is complete, execute the container build & push
  - `$ make build`
- verify that the frontend can call the backend
  - `$ curl 6jixdodaa2cco-fe.azurewebsites.net/helloFrontend`
- verify that the backed app cannot be called directly & returns a 401 (unauthorized) reposnse
  - `curl 6jixdodaa2cco-be.azurewebsites.net/helloBackend`
