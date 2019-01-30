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

    PwshJamf () {
        Write-Host "Development Zone"
    }

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

    ##### Resource Path:  /activationcode #####

    # Returns all activationcode
    [psobject] GetActivationcode() {
        $Resource = "activationcode"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Updates department by name
    [psobject] UpdateActivationcode($Code) {
        $Resource = "activationcode"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><activation_code><code>${Code}</code></activation_code>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    
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
    [psobject] CreateBuilding($Name) {
        $Resource = "buildings/id/0"
        $Method = "POST"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><building><name>${Name}</name></building>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates building by name
    [psobject] UpdateBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><building><name>${Name}</name></building>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates building by id
    [psobject] UpdateBuildingByID($ID,$Name) {
        $Resource = "buildings/id/${ID}"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><building><name>${Name}</name></building>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes building by name
    [psobject] DeleteBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes building by id
    [psobject] DeleteBuildingByID($ID) {
        $Resource = "buildings/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    
    ##### Resource Path:  /departments #####

    # Returns all departments
    [psobject] GetDepartments() {
        $Resource = "departments"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns department by name
    [psobject] GetDepartmentByName($Name) {
        $Resource = "departments/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns department by id
    [psobject] GetDepartmentById($ID) {
        $Resource = "departments/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new department
    [psobject] CreateDepartment($Name) {
        $Resource = "departments/id/0"
        $Method = "POST"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><department><name>${Name}</name></department>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates department by name
    [psobject] UpdateDepartmentByName($Name) {
        $Resource = "departments/name/${Name}"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><department><name>${Name}</name></department>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates department by id
    [psobject] UpdateDepartmentByID($ID,$Name) {
        $Resource = "departments/id/${ID}"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><department><name>${Name}</name></department>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes department by name
    [psobject] DeleteDepartmentByName($Name) {
        $Resource = "departments/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes department by id
    [psobject] DeleteDepartmentByID($ID) {
        $Resource = "departments/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    
    ##### Resource Path:  /packages #####

    # Returns all packages
    [psobject] GetPackages() {
        $Resource = "packages"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns package by name
    [psobject] GetPackageByName($Name) {
        $Resource = "packages/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns package by id
    [psobject] GetPackageById($ID) {
        $Resource = "packages/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes package by name
    [psobject] DeletePackageByName($Name) {
        $Resource = "packages/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes package by id
    [psobject] DeletePackageByID($ID) {
        $Resource = "packages/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }


    ##### Resource Path:  /policies #####

    # Returns all policies
    [psobject] GetPoliciess() {
        $Resource = "policies"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns policy by name
    [psobject] GetPolicyByName($Name) {
        $Resource = "policies/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns policy by id
    [psobject] GetPolicyById($ID) {
        $Resource = "policies/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }
    
    # Returns policy Subsets by name
    [psobject] GetPolicySubsetByName($Name,$Subset) {
        $Resource = "policies/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns policy Subsets by id
    [psobject] GetPolicySubsetById($ID,$Subset) {
        $Resource = "policies/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }
    
    # Returns policies by category
    [psobject] GetPoliciesByCategory($Category) {
        $Resource = "policies/category/${Category}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }
    
    # Returns policies by type
    [psobject] GetPoliciesByCreatedBy($CreatedBy) {
        $Resource = "policies/createdBy/${CreatedBy}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes policy by name
    [psobject] DeletePolicyByName($Name) {
        $Resource = "policies/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes policy by id
    [psobject] DeletePolicyByID($ID) {
        $Resource = "policies/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Adds package by name to policy by name, specifying the action (cache, install, uninstall)
    [psobject] AddPackageToPolicyByName($PolicyName,$PackageName,$Action) {
        $Resource = "policies/name/${PolicyName}"
        $Method = "PUT"
        [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?>
            <package_configuration>
                <packages>
                    <package>
                    <name>${PackageName}</name>
                    <action>${Action}</action>
                </package>
                </packages>
            </package_configuration>"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }
    ##### Resource Path:  / #####

    
}