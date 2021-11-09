function Invoke-MsGraphRestMethod {
    <#
            .SYNOPSIS
            Generic helper cmdlet to invoke Rest methods agains a MsGraph.
            .DESCRIPTION
            This cmdlet extends the original Invoke-RestMethod cmdlet with MsGraph REST
            API specific parameters, so it does user authorization and provides easier
            resource access.
            .PARAMETER Resource
            MsGraph REST API Resource that needs to be accessed
            .PARAMETER Method
            REST method to be used for the call. (Default is GET)
            .PARAMETER AuthenticationMode
            Authentication Mode to access MsGraph
            .PARAMETER AuthenticationToken
            Authentication Token to access MsGraph
            .PARAMETER UriParams
            Parameters that needs to be appended to the GET url.
            .PARAMETER Headers
            HTTP Headers that needs to be added for the REST call.
            .PARAMETER Body
            HTTP Body payload
            .EXAMPLE
            Invoke-MsGraphRestMethod -Resource groups -Beta -AuthenticationToken $MSGraphToken -UriParams $UriParams
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Resource,
        [ValidateSet('Get', 'Patch', 'Put', 'Post', 'Delete')]
        [string]$Method = 'Get',
        [switch]$Beta,
        [uri]$Server = 'https://graph.microsoft.com',
        [uri]$Uri,
        [Parameter(Mandatory)]
        [string]$AuthenticationToken,
        [string]$ContentType = 'application/json',
        [hashtable]$UriParams = @{ },
        [hashtable]$Headers,
        [hashtable]$Body
    )

    if ($Beta) {
        $Server = '{0}beta' -f $Server
    }
    else {
        $Server = '{0}v1.0' -f $Server
    }
    If (!$uri) {
        $Uri = ('{0}/{1}' -f $Server, $Resource)
    }
    Add-Type -AssemblyName System.Net.Http
    $Headers = @{
        Authorization = ('Bearer {0}' -f $AuthenticationToken)
    }
    If ($UriParams -and $UriParams.Keys) {
        $Params = ''
        foreach ($key in $UriParams.Keys) {
            $Params += ('{0}={1}&' -f $key, $UriParams.$key)
        }
        If ($Params) {
            $Uri = ('{0}?{1}' -f ($Uri), $Params)
        }
    }
    $Response = $null
    $InvokeParams = @{
        Uri              = $Uri
        Method           = $Method
        DisableKeepAlive = $true
        Headers          = $Headers
        ContentType      = $ContentType
    }
    If ($Body) {
        $InvokeParams.Add('Body',(ConvertTo-Json $Body -Depth 100))
    }
    try {
        $Response = Invoke-RestMethod @InvokeParams
        if ($Response.psobject.properties.name -contains '@odata.nextLink') {
            do {
                $returnResponse += $Response.value
                $Response = Invoke-RestMethod -Uri $Response.'@odata.nextLink' -Headers $Headers -ContentType $ContentType -Method $Method
            }
            while ($Response.psobject.properties.name -contains '@odata.nextLink')
        }
        else {
            $returnResponse = $Response
        }
    }
    catch {
        $statusMessage = $_.Exception.Response.StatusCode
        $statusCode = [int][system.net.httpstatuscode]::$statusMessage
        $errorMessage = $_.ErrorDetails.Message
        $throwMessage = 'Status code {0} {1}. Server reported the following message: {2}.' -f $statusCode, $statusMessage, $errorMessage
        throw [Net.Http.HttpRequestException] $throwMessage
    }
    Write-Verbose -Message ('Response: {0}' -f $Response)
    return($returnResponse)
}