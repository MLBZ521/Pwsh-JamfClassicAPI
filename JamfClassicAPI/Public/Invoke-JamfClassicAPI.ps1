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
        Invoke-JamfClassicAPI -Resource "accounts"
    .EXAMPLE
        Invoke-JamfClassicAPI -Resource "accounts" -Method Delete
#>
function Invoke-JamfClassicAPI() {
    [CmdletBinding()]
    Param(
        [Parameter(ParameterSetName='Authentication')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.CredentialAttribute()]
        $Authentication = $script:APICredentials,

        [ValidateSet('GET','PUT','POST','DELETE', IgnoreCase = $true)]
        [string]$Method = 'GET',

        [ValidateSet('xml','json', IgnoreCase = $true)]
        [string]$Header = 'xml',

        [psobject]$Body,

        [hashtable]$ResourceParameters,

        [string]$Server = $env:JamfProServer
    )

    DynamicParam {
        $RuntimeParamDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        # Build Dynamic Paramter for $Resource
        $ParameterAttributes = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttributes.HelpMessage = "Provide the Resource to access:"
        $ParameterAttributes.Mandatory = $Mandatory.IsPresent
        $ParameterAttributes.ParameterSetName = '__AllParameterSets'
        $ParameterAttributes.ValueFromPipeline = $ValueFromPipeline.IsPresent
        $ParameterAttributes.ValueFromPipelineByPropertyName = $ValueFromPipelineByPropertyName.IsPresent
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
                [psobject]$Header = @{"accept"="application/xml"}
            }
            "json" {
                [psobject]$Header = @{"accept"="application/json"}
            }
        }
        
        # Check if the provided $Method is supported by the selected $Resource.
        if ( $Method -notin $( $global:APIResources | Where-Object { $_.Path -eq $Resource } ).Methods ) {
            Write-Error -Message "The selected resource does not support the provided method." -ErrorAction Stop
        }

        # Check if a $ResourceParamter is required for the requested $Resource and fail out if a $ResourceParamter was not provided.
        if ( $( $Resource -split "/" | Where-Object { $_ -match "[{].+[}]" } ).Count -ne 0 -and $null -eq $ResourceParamter ) {
            Write-Error -Message "The selected resource requires a `$ResourceParamter to be provided." -ErrorAction Stop
        }
        # If a $ResourceParamter is required for the requested $Resource, replace the provide $ResourceParamter in the $Resource string.
        elseif ( $( $Resource -split "/" | Where-Object { $_ -match "[{].+[}]" } ).Count -gt 0 ) {
            Write-Verbose -Message "Updating the Resourse with the provided Parameters"

            ForEach ( $Parameter in $ResourceParameters.Keys ) {
                $Resource = $( $Resource | Where-Object { $_ -match "[{].+[}]" } ) -replace "[{]$Parameter[}]", $ResourceParameters[$Parameter]
            }
        }
        
        Write-Verbose "Invoke method `"${Method}`" on resource `"${Resource}`" with header `"accept: $(${Header}.Values)`""
        $Uri = "${Server}/JSSResource${Resource}"
    }

    Process {
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
}
