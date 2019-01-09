<#
    .SYNOPSIS
        Helper cmdlet to get all resources available from the Jamf Pro Classic API.
    .DESCRIPTION
        This cmdlet will get all resources, a description for each, and available methods, 
        for each resource endpoint which will all dymanic use of the API each time the 
        module is loaded.
    .PARAMETER Server
        Mandatory - Fully qualified HTTPS URL for the target JPS.
    .EXAMPLE
        Get-JamfAPIResources -Server "https://jamf.company.com:8443"
#>
function Get-JamfAPIResources() {
    [CmdletBinding()]
    Param(
        [string]$Server = $script:JamfProServer
    )

    Write-Verbose "Getting available API resources endpoints from ${Server}"

    Try {
        $response = Invoke-WebRequest -Uri "${Server}/api/resources.json" -Method GET -ErrorVariable RestError -ErrorAction Stop 
    }
    Catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        If ($statusCode -notcontains "200") {
            $errorDescription = $($RestError.Message -split [Environment]::NewLine)            
            Write-Host -Message "FAILED:  ${statusCode} / $($errorDescription[5]) - $($errorDescription[6])"
        }
    }  

    $allResources = $response | Select-Object $_.Content | ConvertFrom-Json

    Write-Verbose "For each resource endpoint, getting all available operations and methods"
    ForEach ( $Resource in $allResources.apis )  {

        Try {
            $response = Invoke-WebRequest -Uri "${Server}/api/model$($($Resource.path).replace("{format}", "json"))" -Method GET -ErrorVariable RestError -ErrorAction SilentlyContinue
        }
        Catch {
            $statusCode = $_.Exception.Response.StatusCode.value__

            If ($statusCode -notcontains "200") {
                $errorDescription = $($RestError.Message -split [Environment]::NewLine)
                Write-Host -Message "FAILED:  ${statusCode} / $($errorDescription[5]) - $($errorDescription[6])"
            }
        }
    
        $Operations = $response | Select-Object $_.Content | ConvertFrom-Json
    
        ForEach ( $Operation in $Operations.apis ) {
    
            $ResourcePathOperation = New-Object PSObject -Property ([ordered]@{
                Path  = $Operation.path
                Description = $Operation.description
                Methods = $(
                    if ( $Operation.operations.notes -eq "You can PUT, POST, and DELETE using this resource URL." ) {
                        [Array]("GET", "POST", "PUT", "DELETE")
                    }
                    else {
                        ForEach ( $ResourceOperation in $Operation.operations ) {                         
                            $ResourceOperation.httpMethod
                        }
                    }
                )
            })
            [Array]$resourceOperations += $ResourcePathOperation
        }
    }
    return $resourceOperations
}
