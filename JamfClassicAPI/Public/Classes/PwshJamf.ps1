Class PwshJamf {

    [ValidatePattern('(https:\/\/)([\w\.-]+)(:\d+)')]
    [uri] $Server
    [string] $Header = "application/json"
    hidden [string] $JamfAPIUsername
    hidden [string] $JamfAPIPassword
    hidden [string] $Credentials
    hidden [hashtable] $Headers = @{}
    hidden static [string] $RestError

    ####################################################################################################
    # Constructor

    PwshJamf () {
        Write-Host "Development Zone"
    }

    PwshJamf ([pscredential]$Credentials) {
        $this.Credentials = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes( ( “$( $Credentials.UserName.ToString() ):$( ( [Runtime.InteropServices.Marshal]::PtrToStringBSTR( [Runtime.InteropServices.Marshal]::SecureStringToBSTR( $Credentials.Password ) ) ) )” ) ) )
        $this.Headers.Add('Accept', $this.Header)
        $this.Headers.Add('Authorization', "Basic $($this.Credentials)")
    }

    PwshJamf ([String]$JamfAPIUsername, [string]$JamfAPIPassword) {
        $this.Credentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($JamfAPIUsername):$($JamfAPIPassword)"))
        $this.Headers.Add('Accept', $this.Header)
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
    # Helper Methods

    # Build a blank XML Payload
    [xml] _BuildXML() {
        [xml]$Payload = New-Object Xml
        # Creation of a node and its text
        $XmlDeclaration = $Payload.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $Payload.AppendChild($XmlDeclaration) | Out-Null
        return $Payload
    }

    # Build the first element in XML Payload
    [xml] _BuildXML($Element) {
        [xml]$Payload = New-Object Xml
        # Creation of a node and its text
        $XmlDeclaration = $Payload.CreateXmlDeclaration("1.0", "UTF-8", $null)
        $Payload.AppendChild($XmlDeclaration) | Out-Null
        $xmlElt = $Payload.CreateElement("${Element}")
        # Add the node to the document
        $Payload.AppendChild($xmlElt)
        return $Payload
    }

    # Add an elemnt to the XML Payload
    [xml] _AddXMLElement($Payload,$Parent,$Child) {
        # Creation of a node and its text
        $xmlElt = $Payload.CreateElement("${Child}")
        # Add the node to the document
        $Payload.SelectSingleNode("${Parent}").AppendChild($xmlElt)
        return $Payload
    }

    # Add an elemnt to the XML Payload
    [xml] _AddXMLText($Payload,$Parent,$Element,$ElementText) {
        # Creation of a node and its text
        $xmlElt = $Payload.CreateElement("${Element}")
        $xmlText = $Payload.CreateTextNode("${ElementText}")
        $xmlElt.AppendChild($xmlText) | Out-Null
        # Add the node to the document
        $Payload.SelectSingleNode("${Parent}").AppendChild($xmlElt)
        return $Payload
    }

    # Helper to build an xml Node
    [psobject] BuildXMLNode($Node,$Configuration) {
        $Payload = $this.'_BuildXML'($Node)

        # Loop through each configuration item and create a node from it.
        ForEach ($Key in $Configuration.Keys) {

            # Check if the configuration has a sub-element.
            if ( $Key -match "[.]" ) {
                # Split the configuration between parent and child elements.
                $ParentKey,$ChildKey = $Key -split "[.]"
                # Create a parent element and add the node to the document
                $Payload = $this.'_AddXMLElement'($Payload,"/*","${ParentKey}")
                # Create a node from an element and text
                $Payload = $this.'_AddXMLText'($Payload,"//${ParentKey}","${ChildKey}","$($Configuration.$Key)")
            }
            else {
                $Payload = $this.'_AddXMLText'($Payload,"/*","${Key}","$($Configuration.$Key)")
            }
        }

        # My hacky idea to create subnodes from keys with a "." will end up creating multiple subnodes of the same name, if multiple properities for a subnode is specified.
        # So here, we'll clean those up.
        $EmptyNodes = $Payload.SelectNodes("//*[count(@*) = 0 and count(child::*) = 0 and not(string-length(text())) > 0]")
        $EmptyNodes | ForEach-Object { $_.ParentNode.RemoveChild($_) } | Out-Null

        return $Payload
    }

    # Helper to build an xml Node
    [psobject] BuildXMLNode($Node,$Key,$Values) {
        $Payload = $this.'_BuildXML'("${Node}s")

        # Loop through each configuration item and create a node from it.
        ForEach ($Value in $Values) {
            $Element = $this.'_BuildXML'($Node)
            $Element = $this.'_AddXMLText'($Element,$Node,$Key,$Value)
            $Payload.DocumentElement.SelectSingleNode("/*").AppendChild($Payload.ImportNode($Element.($Element.FirstChild.NextSibling.LocalName), $true)) | Out-Null
        }
        return $Payload
    }

    ####################################################################################################
    # Available API Endpoints:

    ##### Resource Path:  /accounts #####

    # Returns all accounts
    [psobject] GetAccounts() {
        $Resource = "accounts"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns account by username
    [psobject] GetAccountByUsername($Name) {
        $Resource = "accounts/username/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns account by userid
    [psobject] GetAccountByUserid($ID) {
        $Resource = "accounts/userid/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new account
    [psobject] CreateAccountUser($Payload) {
        $Resource = "accounts/userid/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates account by username
    [psobject] UpdateAccountByUsername($Name,$Payload) {
        $Resource = "accounts/username/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates account by userid
    [psobject] UpdateAccountByUserid($ID,$Payload) {
        $Resource = "accounts/userid/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes account by username
    [psobject] DeleteAccountByUsername($Name) {
        $Resource = "accounts/username/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes account by userid
    [psobject] DeleteAccountByUserid($ID) {
        $Resource = "accounts/userid/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns account by groupname
    [psobject] GetAccountByGroupname($Name) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns account by groupid
    [psobject] GetAccountByGroupid($ID) {
        $Resource = "accounts/groupid/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new account
    [psobject] CreateAccountGroup($Payload) {
        $Resource = "accounts/groupid/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates account by groupname
    [psobject] UpdateAccountByGroupname($Name,$Payload) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates account by groupid
    [psobject] UpdateAccountByID($ID,$Payload) {
        $Resource = "accounts/groupid/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes account by groupname
    [psobject] DeleteAccountByGroupname($Name) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes account by groupid
    [psobject] DeleteAccountByID($ID) {
        $Resource = "accounts/groupid/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }


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
        $Payload = $this.'_BuildXML'("activation_code")
        $Payload = $this.'_AddXMLText'($Payload,"activation_code","code",$Code)
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
        $Payload = $this.'_BuildXML'("building")
        $Payload = $this.'_AddXMLText'($Payload,"building","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates building by name
    [psobject] UpdateBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("building")
        $Payload = $this.'_AddXMLText'($Payload,"building","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates building by id
    [psobject] UpdateBuildingByID($ID,$Name) {
        $Resource = "buildings/id/${ID}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("building")
        $Payload = $this.'_AddXMLText'($Payload,"building","name",$Name)
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


    ##### Resource Path:  /categories #####

    # Returns all categories
    [psobject] GetCategories() {
        $Resource = "categories"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns category by name
    [psobject] GetCategoryByName($Name) {
        $Resource = "categories/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns category by id
    [psobject] GetCategoryById($ID) {
        $Resource = "categories/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new category
    [psobject] CreateCategory($Name) {
        $Resource = "categories/id/0"
        $Method = "POST"
        $Payload = $this.'_BuildXML'("category")
        $Payload = $this.'_AddXMLText'($Payload,"category","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates category by name
    [psobject] UpdateCategoryByName($Name) {
        $Resource = "categories/name/${Name}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("category")
        $Payload = $this.'_AddXMLText'($Payload,"category","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates category by id
    [psobject] UpdateCategoryByID($ID,$Name) {
        $Resource = "categories/id/${ID}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("category")
        $Payload = $this.'_AddXMLText'($Payload,"category","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes category by name
    [psobject] DeleteCategoryByName($Name) {
        $Resource = "categories/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes category by id
    [psobject] DeleteCategoryByID($ID) {
        $Resource = "categories/id/${ID}"
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
        $Payload = $this.'_BuildXML'("department")
        $Payload = $this.'_AddXMLText'($Payload,"department","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates department by name
    [psobject] UpdateDepartmentByName($Name) {
        $Resource = "departments/name/${Name}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("department")
        $Payload = $this.'_AddXMLText'($Payload,"department","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates department by id
    [psobject] UpdateDepartmentByID($ID,$Name) {
        $Resource = "departments/id/${ID}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("department")
        $Payload = $this.'_AddXMLText'($Payload,"department","name",$Name)
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

    # Creates new package
    [psobject] CreatePackage($Payload) {
        $Resource = "packages/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates package by name
    [psobject] UpdatePackageByName($Name,$Payload) {
        $Resource = "packages/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates package by id
    [psobject] UpdatePackageByID($ID,$Payload) {
        $Resource = "packages/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
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

    # Creates new policy
    [psobject] CreatePolicy($Payload) {
        $Resource = "policies/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates policy by name
    [psobject] UpdatePolicyByName($Name,$Payload) {
        $Resource = "policies/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates policy by id
    [psobject] UpdatePolicyByID($ID,$Payload) {
        $Resource = "policies/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
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
        $Payload = $this.'_BuildXML'("package_configuration")
        $Payload = $this.'_AddXMLElement'($Payload,"package_configuration","packages")
        $Payload = $this.'_AddXMLText'($Payload,"packages","name",$PackageName)
        $Payload = $this.'_AddXMLText'($Payload,"packages","action",$Action)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Helper to build a policy from Subsets
    [psobject] BuildPolicy($Subsets) {
        $Payload = $this._BuildXML("policy")
        $Payload = $this.'_AddXMLElement'($Payload,"//policy","package_configuration")
        $Payload = $this.'_AddXMLElement'($Payload,"//package_configuration","packages")
        $Payload = $this.'_AddXMLElement'($Payload,"//policy","scripts")
        $Payload = $this.'_AddXMLElement'($Payload,"//policy","printers")
        $Payload = $this.'_AddXMLElement'($Payload,"//policy","dock_items")
        $Payload = $this.'_AddXMLElement'($Payload,"//policy","account_maintenance")
        $Payload = $this.'_AddXMLElement'($Payload,"//account_maintenance","accounts")
        $Payload = $this.'_AddXMLElement'($Payload,"//policy","directory_bindings")

        # Loop through each Subset value and append it to the payload
        foreach ( $Subset in $Subsets) {
            $Subset.FirstChild.NextSibling.LocalName

            switch ($Subset.FirstChild.NextSibling.LocalName) {
                "package" {
                    $Payload.DocumentElement.SelectSingleNode("//packages").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                "script" {
                    $Payload.DocumentElement.SelectSingleNode("//scripts").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                "printer" {
                    $Payload.DocumentElement.SelectSingleNode("//printers").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                "dock_item" {
                    $Payload.DocumentElement.SelectSingleNode("//dock_items").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                "account" {
                    $Payload.DocumentElement.SelectSingleNode("//accounts").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                "directory_binding" {
                    $Payload.DocumentElement.SelectSingleNode("//directory_bindings").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                Default {
                    $Payload.DocumentElement.AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
            }
        }

        return $Payload
    }


    ##### Resource Path:  /sites #####

    # Returns all sites
    [psobject] GetSites() {
        $Resource = "sites"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns site by name
    [psobject] GetSiteByName($Name) {
        $Resource = "sites/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns site by id
    [psobject] GetSiteById($ID) {
        $Resource = "sites/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new site
    [psobject] CreateSite($Name) {
        $Resource = "sites/id/0"
        $Method = "POST"
        $Payload = $this.'_BuildXML'("site")
        $Payload = $this.'_AddXMLText'($Payload,"site","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates site by name
    [psobject] UpdateSiteByName($Name) {
        $Resource = "sites/name/${Name}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("site")
        $Payload = $this.'_AddXMLText'($Payload,"site","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates site by id
    [psobject] UpdateSiteByID($ID,$Name) {
        $Resource = "sites/id/${ID}"
        $Method = "PUT"
        $Payload = $this.'_BuildXML'("site")
        $Payload = $this.'_AddXMLText'($Payload,"site","name",$Name)
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes site by name
    [psobject] DeleteSiteByName($Name) {
        $Resource = "sites/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes site by id
    [psobject] DeleteSiteByID($ID) {
        $Resource = "sites/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }


    ##### Resource Path:  / #####


}