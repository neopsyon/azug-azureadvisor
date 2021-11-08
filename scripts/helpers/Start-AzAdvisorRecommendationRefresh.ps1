process {
    $ErrorActionPreference = 'Stop'
    $subscriptionList = Get-AzSubscription
    $accessToken = Get-AzAccessToken -ResourceUrl 'https://management.azure.com'
    $authorizationHeader = @{Authorization = ('Bearer {0}' -f $accessToken.Token) }
    foreach ($subscription in $subscriptionList) {
        # Invoke Azure Advisor Refresh API operation
        $refreshSplat = @{
            Uri     = 'https://management.azure.com/subscriptions/{0}/providers/Microsoft.Advisor/generateRecommendations?api-version=2017-04-19' -f $subscription.Id
            Headers = $authorizationHeader
            Method  = 'Post'
        }
        $refreshAdvisory = Invoke-WebRequest @refreshSplat

        # Wait until asynchronous operation is completed
        $refreshAdvisoryStatusSplat = @{
            Uri     = 'https://management.azure.com/subscriptions/{0}/providers/Microsoft.Advisor/generateRecommendations/{1}?api-version=2017-04-19' -f $subscription.Id, (($refreshAdvisory.Headers.Location -split '/')[-1] -split '\?')[0]
            Headers = $authorizationHeader
            Method  = 'Get'
        }
        $refreshAdvisoryStatus = Invoke-WebRequest @refreshAdvisoryStatusSplat
        if ($refreshAdvisoryStatus.StatusCode -ne 204) {
            Do {
                $refreshAdvisoryStatus = Invoke-WebRequest @refreshAdvisoryStatusSplat
            }
            Until ($refreshAdvisoryStatus -eq 204)
        }
        Write-Host ('Successfully refreshed Azure Advisor Recommendations for subscription {0} with the ID {1}' -f $subscription.Name, $subscription.Id)
    }
}