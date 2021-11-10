param (
    [Parameter(Mandatory)]
    [string]$GraphToken
)
begin {
    $ErrorActionPreference = 'Stop'
    . ('{0}/helpers/Invoke-MsGraphRestMethod.ps1' -f (get-item $PSScriptRoot).parent)
    . ('{0}/helpers/Split-AzResourceId.ps1' -f (get-item $PSScriptRoot).parent)
    if (-not (Get-Module 'Az.ResourceGraph' -ListAvailable)) {
        Install-Module 'Az.ResourceGraph' -Confirm:$false -Force
    }
    $UriParams = @{'$select' = 'id,accountEnabled,userPrincipalName' }
    # Azure Graph Query for advisory - Deprecated accounts with owner permissions should be removed from your subscriptions
    $graphquery = 'securityresources
    | where type == "microsoft.security/assessments"
    | extend source = tostring(properties.resourceDetails.Source)
    | extend resourceId =
        trim(" ", tolower(tostring(case(source =~ "azure", properties.resourceDetails.Id,
                                        source =~ "aws", properties.resourceDetails.AzureResourceId,
                                        source =~ "gcp", properties.resourceDetails.AzureResourceId,
                                        extract("^(.+)/providers/Microsoft.Security/assessments/.+$",1,id)))))
    | extend status = trim(" ", tostring(properties.status.code))
    | extend cause = trim(" ", tostring(properties.status.cause))
    | extend assessmentKey = tostring(name)
    | where assessmentKey == "00c6d40b-e990-6acf-d4f3-471e747a27c4"
    | where status == "Unhealthy"'
}
process {
    $graphQueryResult = Search-azgraph -query $graphquery
    if ($graphQueryResult.data.count -gt 0) {
        $adUsers = Invoke-MsGraphRestMethod -Resource 'users' -UriParams $UriParams -AuthenticationToken $GraphToken
        if ($adUsers.value.count -gt 0) {
            $disabledUsers = $adUsers.value | Where-Object { $_.accountEnabled -eq $false }
            if ($disabledUsers) {
                $unhealthySubscriptions = $graphQueryResult.data.properties.resourceDetails.Id
                foreach ($subscription in $unhealthySubscriptions) {
                    $disabledUserAzRoleAssignments = Get-AzRoleAssignment -Scope $subscription | where-object { $_.SignInName -in $disabledUsers.userPrincipalName }
                    foreach ($azRoleAssignment in $disabledUserAzRoleAssignments) {
                        if (($azRoleAssignment.Scope -Split '/').Count -ge 9) {
                            $resourceObject = Split-AzResourceId -ResourceId $azRoleAssignment.Scope
                            [void](Set-AzContext -SubscriptionId $resourceObject.SubscriptionId)
                            $testResourceLock = Get-AzResourceLock -ResourceName $resourceObject.ResourceName -ResourceGroupName $resourceObject.ResourceGroupName -ResourceType $resourceObject.ResourceProvider
                        }
                        if ($testResourceLock) {
                            $testResourceLock | Remove-AzResourceLock -Confirm:$false -Force | Out-Null
                        }
                        # IMPORTANT: Principal that is executing removal of the access has to have explicit assignment as the owner over the subscription scope, otherwise you will receive precondition failed error
                        Remove-AzRoleAssignment -ObjectId $azRoleAssignment.ObjectId -Scope $azRoleAssignment.Scope -RoleDefinitionName $azRoleAssignment.RoleDefinitionName -Confirm:$false
                        Write-host ('Removed access rights - {0} {1} {2}' -f $azRoleAssignment.ObjectId, $azRoleAssignment.Scope, $azRoleAssignment.RoleDefinitionName)
                        if ($testResourceLock) {
                            New-AzResourceLock -LockName $testResourceLock.Name -LockLevel 'CanNotDelete' -ResourceName $resourceObject.ResourceName -ResourceGroupName $resourceObject.ResourceGroupName -ResourceType $resourceObject.ResourceProvider -Force
                        }
                    }
                }
            }
        }
    }
}