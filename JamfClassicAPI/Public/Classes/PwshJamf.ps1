Class PwshJamf {

    [ValidatePattern('(https:\/\/)([\w\.-]+)(:\d+)')]
    [uri] $Server
    [string] $JamfAPIUsername
    [string] $JamfAPIPassword
    hidden [string] $Credentials
    hidden [hashtable] $Headers = @{}
    [string] $Header = "application/json"
    hidden static [string] $RestError

    ####################################################################################################
    # Constructor

    PwshJamf ([String]$JamfAPIUsername, [string]$JamfAPIPassword) {
        $this.Credentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($JamfAPIUsername):$($JamfAPIPassword)"))
        $this.Headers['Accept'] = $this.Headers['Accept'] -replace '.+', $this.Header
        $this.Headers.Add('Authorization', "Basic $($this.Credentials)")
    }

    ####################################################################################################
    # Methods

    # Generic helper method to invoke GET and DELETE REST Methods against a Jamf Pro Server.
    [psobject] InvokeAPI($Resource,$Method) {
        try {
            # Write-Host "$($this.Server)JSSResource/$Resource"
            # Write-Host $Method
            # Write-Host $this.Headers
            $Results = Invoke-RestMethod -Uri "$($this.Server)JSSResource/$Resource" -Method $Method -Headers $this.Headers -Verbose -ErrorVariable RestError -ErrorAction SilentlyContinue
            return $Results
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorDescription = $($this.RestError.Message -split [Environment]::NewLine)
            Write-Host -Message "FAILED:  ${statusCode} / $($errorDescription[5]) - $($errorDescription[6])"
            Write-Host -Message "FAILED:  ${statusCode} / $($this.RestError.Message)"
            Return $null
        }
    }

    # Generic helper method to invoke POST and PUT REST Methods against a Jamf Pro Server.
    [psobject] InvokeAPI($Resource,$Method,$Payload) {
        try {
            # Write-Host "$($this.Server)JSSResource/$Resource"
            # Write-Host $Method
            # Write-Host $this.Headers
            $Results = Invoke-RestMethod -Uri "$($this.Server)JSSResource/$Resource" -Method $Method -Headers $this.Headers -ContentType "application/xml" -Body $Payload -Verbose -ErrorVariable RestError -ErrorAction SilentlyContinue
            return $Results
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $errorDescription = $($this.RestError.Message -split [Environment]::NewLine)
            Write-Host -Message "FAILED:  ${statusCode} / $($errorDescription[5]) - $($errorDescription[6])"
            Write-Host -Message "FAILED:  ${statusCode} / $($this.RestError.Message)"
            Return $null
        }
    }

    ####################################################################################################
    # Available API Endpoints:

    ##### Resource Path:  /buildings #####

    # Returns all buildings
    [psobject] GetBuildings() {
        $Resource = "buildings"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns building by name
    [psobject] GetBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns building by id
    [psobject] GetBuildingById($ID) {
        $Resource = "buildings/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new building
    [psobject] createBuilding($Name) {
        $Resource = "buildings/id/0"
        $Method = "POST"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><building><name>${Name}</name></building>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates building by name
    [psobject] updateBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><building><name>${Name}</name></building>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates building by id
    [psobject] updateBuildingByID($ID,$Name) {
        $Resource = "buildings/id/${ID}"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><building><name>${Name}</name></building>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes building by name
    [psobject] deleteBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes building by id
    [psobject] deleteBuildingByID($ID) {
        $Resource = "buildings/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }
}

    ##### Resource Path:  / #####
