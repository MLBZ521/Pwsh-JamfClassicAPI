<#
    .SYNOPSIS
        Sets the target Jamf Pro Server.
    .DESCRIPTION
        All further cmdlets will be executed against the JPS API specified by this cmdlet.
    .PARAMETER Url
        Mandatory - Fully qualified HTTPS URL for the target JPS.
    .PARAMETER Save
        Mandatory - Whether to save the URL to the user environemnt or sesssion.
    .EXAMPLE
        Set-JamfServer -Url "https://jamf.company.com:8443" -Save (Yes/No)
#>

function Set-JamfServer() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^(https:\/\/)([\w\.-]+)(:\d+)')]
        [string]$Url,
   
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes','No', 'Y', 'N', IgnoreCase = $true)]
        [string]$Save
        )
    
    Write-Verbose "Setting the Jamf Pro Server to:  ${Url}"
    if ( $Save -eq 'Yes','y' ) {
        Write-Verbose "Saving the Jamf Pro Server URL to the User environment."
        [Environment]::SetEnvironmentVariable("JamfProServer", "${URL}", "User")
    }
    else {
        Write-Verbose "Saving the Jamf Pro Server URL to the session."
        $env:JamfProServer = "${URL}"
    }
}