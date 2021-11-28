VERSION := 0.0.1
ACR_NAME := cbelleeacr398239f

build:
	cd ./src/cmd/frontend
	az acr build -r ${ACR_NAME} -t ${ACR_NAME}/frontend:${VERSION} -f ./src/cmd/frontend/Dockerfile .

	cd ./src/cmd/backend
	az acr build -r ${ACR_NAME} -t ${ACR_NAME}/backend:${VERSION} -f ./src/cmd/backend/Dockerfile .
	
deployment: 
	./deploy/deploy.sh
