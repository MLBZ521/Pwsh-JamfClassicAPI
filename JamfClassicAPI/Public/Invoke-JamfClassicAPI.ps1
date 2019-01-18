<#
    .SYNOPSIS
        Generic helper cmdlet to invoke Rest methods against Jamf Pro Server.
    .DESCRIPTION
        This cmdlet extends the original Invoke-RestMethod cmdlet with Jamf Pro Classic
        API specific parameters and user authorization to provide easier resource access.
    .PARAMETER Authentication
        Mandatory - Jamf Pro Classic API credentials.
    .PARAMETER Body
        Optional - HTTP Body payload.  (Used for POST and PUT requests)
    .PARAMETER Endpoints
        Optional - Provided values will be transposed into the requested $Resoure.
    .PARAMETER Header
        Optional - HTTP Header used in the REST call.  (Default is xml)
    .PARAMETER Method
        Optional - REST method to be used for the call.  (Default is GET)
    .PARAMETER Resource
        Mandatory - Jamf Pro Classic API Resource that needs to be accessed.
    .PARAMETER Server
        Mandatory - The Jamf Pro Server that will be called.

    .EXAMPLE
        Get all user accounts configured in the JPS.

        Invoke-JamfClassicAPI -Authentication (Get-Credentials) -Resource '/accounts' -Method GET -Header xml -Server https://jss.domain.com:8443
    .EXAMPLE
        Delete the user account with an ID of 10.

        Invoke-JamfClassicAPI -Authentication (Get-Credentials) -Resource '/accounts/userid/{id}' -Endpoints @{ id = "10"; } -Method DELETE -Header xml -Server https://jss.domain.com:8443
#>
function Invoke-JamfClassicAPI() {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName = 'Authentication')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Authentication = $script:APICredentials,

        [ValidateSet('GET', 'PUT', 'POST', 'DELETE', IgnoreCase = $true)]
        [string]$Method = 'GET',

        [ValidateSet('xml', 'json', IgnoreCase = $true)]
        [string]$Header = 'xml',

        [ValidateSet('Class', IgnoreCase = $true)]
        [string]$Caller,

        [hashtable]$Endpoints,
        
        [psobject]$Body,

        [string]$Server = $env:JamfProServer
    )

    DynamicParam {
        # Build Dynamic Paramter for $Resource
        $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttributes = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttributes.HelpMessage = "Provide the Resource to access:"
        $ParameterAttributes.Mandatory = $true
        $ParameterAttributes.ParameterSetName = '__AllParameterSets'
        $ParameterAttributes.ValueFromPipeline = $true
        $ParameterAttributes.ValueFromPipelineByPropertyName = $true
        $AttributeCollection.Add($ParameterAttributes)
        $AttributeCollection.Add((New-Object System.Management.Automation.ValidateSetAttribute( $( $global:APIResources.Path ) )))
        $RuntimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('Resource', [string], $AttributeCollection)
        $RuntimeParamDict.Add('Resource', $RuntimeParam)
        return $RuntimeParamDict
    }

    Begin {
        $PsBoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ErrorAction SilentlyContinue}

        # Set the proper Header content based on the provided parameter value.
        switch ($Header) {
            "xml" {
                [psobject]$Header = @{"accept" = "application/xml"}
            }
            "json" {
                [psobject]$Header = @{"accept" = "application/json"}
            }
        }
        
        # Check if the provided $Method is supported by the provided $Resource.
        if ( $Method -notin $( $global:APIResources | Where-Object { $_.Path -eq $Resource } ).Methods.Method ) {
            Write-Error -Message "The provided resource does not support the provided method." -ErrorAction Stop
        }
        # Check if the provided $Method was provided a payload in $Body.
        elseif ( $Method -eq "PUT","POST" -and $null -eq $Body ) {
            Write-Error -Message "A payload (`$Body) was not provided and is required with the provided method." -ErrorAction Stop
        }
        # Check if the provided $Method was provided the proper $Header type.
        elseif ( $Method -eq "PUT","POST" -and $Header -ne "xml" ) {
            Write-Error -Message "The selecprovidedted `$Method does not support the provided `$Header." -ErrorAction Stop
        }

        if ( $Caller -ne "Class" ) {
            # Check if a $Endpoints is required for the requested $Resource and fail out if a $Endpoints was not provided.
            if ( $( $Resource -split "/" | Where-Object { $_ -match "[{].+[}]" } ).Count -ne 0 -and $null -eq $Endpoints ) {
                Write-Error -Message "The provided resource requires a `$Endpoints to be provided." -ErrorAction Stop
            }
            # If a $Endpoints is required for the requested $Resource, replace the provide $Endpoints in the $Resource string.
            elseif ( $( $Resource -split "/" | Where-Object { $_ -match "[{].+[}]" } ).Count -gt 0 ) {
                Write-Verbose -Message "Updating the Resourse with the provided Parameters"

                ForEach ( $Endpoint in $Endpoints.Keys ) {
                    $Resource = $( $Resource | Where-Object { $_ -match "[{].+[}]" } ) -replace "[{]$Endpoint[}]", $Endpoints[$Endpoint]
                }
            }
        }
                
        Write-Verbose -Message "Invoke method `"${Method}`" on resource `"${Resource}`" with header `"accept: $(${Header}.Values)`""
        $Uri = "${Server}/JSSResource${Resource}"
    }

    Process {
        try {
            $response = Invoke-RestMethod -Uri "${Uri}" -Method $Method -Headers $Header -Credential $Authentication -ErrorVariable RestError -ErrorAction SilentlyContinue
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__

            if ($statusCode -notcontains "200") {
                $errorDescription = $($RestError.Message -split [Environment]::NewLine)
                Write-Host -Message "FAILED:  ${statusCode} / $($errorDescription[5]) - $($errorDescription[6])"
                # Write-Host -Message "FAILED:  ${statusCode} / $($RestError.Message)"
            }
        }
        return $response
    }
}
