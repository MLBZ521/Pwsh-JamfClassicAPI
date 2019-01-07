<#
    .SYNOPSIS
        Sets the API credentials for the target Jamf Pro Server.
    .DESCRIPTION
        All further cmdlets will be executed with the authentication details passed 
        by this command against the JPS API.    
    .PARAMETER Credential
        API Credential to authenticate to the Jamf Pro API.
    .EXAMPLE
        Set-JamfProAuthentication -Credential (Get-Credential)
#>

function Set-JamfProAuthentication() {
    [CmdletBinding(DefaultParameterSetName="Credential")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUsePSCredentialType", "Credential")]
    param(
        [Parameter(Mandatory=$true,ParameterSetName='Credential')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Credential
    )

    Write-Verbose "Credentials Supplied"
    $script:APICredentials = $Credential

}