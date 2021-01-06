#!/bin/bash
# Allow to create one instance of ACI based on Registry

# Modify for your environment.
# RESOURCE_GROUP_NAME: The name of resource group that you have created early
# ACI_NAME: The name of your Azure Container Instances that you want to create
# SERVICE_PRINCIPAL_NAME: Must be unique within your AD tenant
# SERVER_ACR_NAME: Server name of ACR
# IMAGE_NAME: Name of Docker image which are built
# TAG_NAME: Tag of image
# DNS_NAM: One name that you want , it must be DNS Compliant, It will be used on URL to access application
# PORT: Add port that you want where your container will live.
# SERVICE_PRINCIPAL_ID: Service principal Id that you have created on cloudShell
# SERVICE_PRINCIPAL_PWD: Service principal Password that you have created on cloudShell

RESOURCE_GROUP_NAME=
ACI_NAME=
SERVER_ACR_NAME=testregistryacr.azurecr.io
IMAGE_NAME=
TAG_NAME=
DNS_NAME=
PORT=
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_PWD=

az container create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $ACI_NAME \
    --image $SERVER_ACR_NAME/$IMAGE_NAME:$TAG_NAME \
     --dns-name-label $DNS_NAME \
    --ports $PORT \
    --registry-login-server $SERVER_ACR_NAME \
    --registry-username $SERVICE_PRINCIPAL_ID \
    --registry-password $SERVICE_PRINCIPAL_PWD