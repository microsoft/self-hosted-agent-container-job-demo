# Sample - ADO Self-hosted agent as a Container App job

Demo of ADO pipeline self-hosted agent running as Azure Container Apps - Job

## Overview

ADO self-hosted agent running as a Container Apps Job. Container Apps is integrated with a VNET with App Service Private Endpoint(s). Public Access for the App Service is disabled and deployments to App Service can be done only through the Private Endpoint(s).

![Alt text](Resources/../assets/Picture01.jpg)

ADO self-hosted agent agent pool jobs:
![Alt text](Resources/../assets/adoselfhostedjob.png)

Container Apps Job execution history.
![Alt text](Resources/../assets/containerappjob.png)

## How to deploy the sample

### Pre-requisites

- Owner of Azure Subscription

### Deployment

- Run createcontainerapp.ps1 to:
   - Create Container App Job
   - Build self-hosted agent container image
   - Create VNET
   - Create App Service with Private Endpoints to previously created VNET

## References

- https://learn.microsoft.com/en-us/azure/container-apps/tutorial-ci-cd-runners-jobs?pivots=container-apps-jobs-self-hosted-ci-cd-azure-pipelines&tabs=powershell
- https://learn.microsoft.com/en-us/azure/container-apps/vnet-custom-internal?tabs=bash%2Cazure-cli&pivots=azure-cli
