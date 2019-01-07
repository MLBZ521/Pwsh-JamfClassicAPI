<#
    .SYNOPSIS
        Generic helper cmdlet to invoke Rest methods against Jamf Pro Server.
    .DESCRIPTION
        This cmdlet extends the original Invoke-RestMethod cmdlet with Jamf Pro Classic
        API specific parameters and user authorization to provide easier resource access.
    .PARAMETER Resource
        Mandatory - Jamf Pro Classic API Resource that needs to be accessed.
    .PARAMETER Method
        Optional - REST method to be used for the call. (Default is GET)
    .PARAMETER Header
        Optional - HTTP Header used in the REST call. (Default is xml)
    .PARAMETER Body
        Optional - HTTP Body payload. (Used for POST and PUT requests)
    .EXAMPLE
        Invoke-JamfAPI-Classic -Resource "accounts"
    .EXAMPLE
        Invoke-JamfAPI-Classic -Resource "accounts" -Method Delete
#>
function Invoke-JamfAPI-Classic() {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='Authentication')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Authentication = $script:APICredentials,

        [Parameter(Mandatory)]
        [string]$Resource,

        [ValidateSet('Get','Put','Post','Delete')]
        [string]$Method = 'Get',

        [ValidateSet('xml','json')]
        [string]$Header = 'xml',

        [psobject]$Body,

        [string]$Server = $script:JamfProServer,
        [string]$Uri = "${Server}/JSSResource/${Resource}"
        # [string]$ResourceParams

    )

    switch ($Header) {
        "xml" {
            [psobject]$Header = @{"accept"="application/xml"}
         }
        "json" {
            [psobject]$Header = @{"accept"="application/json"}
        }
    }

    Write-Verbose "${Method}:  ${Resource}"

    Try {
        $response = Invoke-RestMethod -Uri "${Uri}" -Method $Method -Headers $Header -Credential $Authentication -ErrorVariable RestError -ErrorAction SilentlyContinue
    }
    Catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        If ($statusCode -notcontains "200") {
            $errorDescription = $($RestError.Message -split [Environment]::NewLine)
            Write-Host -Message "FAILED:  ${statusCode} / $($errorDescription[5]) - $($errorDescription[6])"
        }
    }
    return $response
}