$JOB_NAME="azure-pipelines-agent-job"
$RESOURCE_GROUP="aca-jobs-sample"

az containerapp job execution list `
    --name "$JOB_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --output table `
    --query '[].{Status: properties.status, Name: name, StartTime: properties.startTime}'