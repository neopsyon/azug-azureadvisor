##
process {
    Import-Module 'Az.Accounts' -force
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $azDefaultContext = $azProfile.DefaultContext
    $tenantId = $azDefaultContext.Tenant.Id
    $graphToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($azDefaultContext.Account, $azDefaultContext.Environment, $tenantId, $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.microsoft.com").AccessToken
    Write-Host "##vso[task.setvariable variable=graphToken;]$graphToken"
}