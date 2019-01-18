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
        Set-JamfServer -Url "https://jamf.company.com:8443" -Save ([Yes|Y]|[No|N]) -DisableSSL ([Yes|Y]|[No|N])
#>

function Set-JamfServer() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if ( $_ -match '^(https:\/\/)([\w\.-]+)(:\d+)$' ) {
                $true
            }
            else {
                Throw " `"$_`" did not match the expected format.  Please use the following format:  https://jamf.company.com:8443"
            }
        })]
        [string]$Url,
   
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes','No', 'Y', 'N', IgnoreCase = $true)]
        [string]$Save,

        [Parameter]
        [ValidateSet('Yes','No', 'Y', 'N', IgnoreCase = $true)]
        [string]$DisableSSL
        )
    
    Write-Verbose -Message "Setting the Jamf Pro Server to:  ${Url}"
    if ( $Save -eq 'Yes','y' ) {
        Write-Verbose -Message "Saving the Jamf Pro Server URL to the User environment."
        [Environment]::SetEnvironmentVariable("JamfProServer", "${URL}", "User")
    }
    else {
        Write-Verbose -Message "Saving the Jamf Pro Server URL to the session."
        $env:JamfProServer = "${URL}"
    }

    if ( $disableSSL -eq 'Yes','y' ) {
        # Disable validation of SSL certificates.
        Write-Verbose -Message "Disabling validation self-signed certs."
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }
}