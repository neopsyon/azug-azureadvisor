function Split-AzResourceId {
    [CmdletBinding()]
    param (
        # Azure resource id
        [Parameter(Mandatory, Position = 0)]
        [string]$ResourceId
    )
    process {
        $splittedResourceId = $ResourceId -split '/'
        $resourceObject = @{
            SubscriptionId = $splittedResourceId[2]
            ResourceGroupName = $splittedResourceId[4]
            ResourceProvider = '{0}/{1}' -f $splittedResourceId[6], $splittedResourceId[7]
            ResourceName = $splittedResourceId[8]
        }
        return($resourceObject)
    }
}