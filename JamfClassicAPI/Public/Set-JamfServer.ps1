<#
    .SYNOPSIS
        Sets the target Jamf Pro Server.
    .DESCRIPTION
        All further cmdlets will be executed against the JPS API specified by this cmdlet.
    .PARAMETER Url
        Mandatory - Fully qualified HTTPS URL  for the target JPS.
    .EXAMPLE
        Set-JamfServer -Url "https://jamf.company.com:8443" -Save (Yes/No)
#>

function Set-JamfServer() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidatePattern('^(https:\/\/)([\w\.-]+)(:\d+)')]
        [string]$Url
    )
    Write-Verbose "Setting the Jamf Pro Server to:  ${Url}"
    $script:JamfProServer = $Url

    Write-Verbose "Setting session Security Protocol to TLS 1.2"
    # Set the session to use TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

}