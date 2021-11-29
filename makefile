VERSION := 0.0.1
RG_NAME := oauth-demo-rg
LOCATION := australiaeast
APP_REG_NAME := backend-app-reg

build:
	cd ./src/cmd/frontend
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/frontend:${VERSION} -f ./src/cmd/frontend/Dockerfile .

	cd ./src/cmd/backend
	az acr build -r $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv) -t $(shell az acr list -g ${RG_NAME} --query "[].loginServer" -o tsv)/backend:${VERSION} -f ./src/cmd/backend/Dockerfile .
	
deployment:
	cd ./deploy && ./deploy.sh -g ${RG_NAME} -l ${LOCATION} -a ${APP_REG_NAME}
