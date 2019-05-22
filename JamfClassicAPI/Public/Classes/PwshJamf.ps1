Class PwshJamf {

    [ValidatePattern('(https:\/\/)([\w\.-]+)(:\d+)')]
    [uri] $Server
    [string] $Header = "application/json"
    hidden [string] $JamfAPIUsername
    hidden [string] $JamfAPIPassword
    hidden [string] $Credentials
    hidden [hashtable] $Headers = @{}

    ####################################################################################################
    # Constructors

    PwshJamf () {
        Write-Host "Development Zone"
    }

    PwshJamf ([pscredential]$Credentials) {
        $this.Credentials = [System.Convert]::ToBase64String( [System.Text.Encoding]::UTF8.GetBytes( ( "$( $Credentials.UserName.ToString() ):$( ( [Runtime.InteropServices.Marshal]::PtrToStringBSTR( [Runtime.InteropServices.Marshal]::SecureStringToBSTR( $Credentials.Password ) ) ) )" ) ) )
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
    [psobject] InvokeAPI($Resource, $Method) {
        try {
            $Results = Invoke-RestMethod -Uri "$($this.Server)JSSResource/$Resource" -Method $Method -Headers $this.Headers -Verbose -ErrorAction SilentlyContinue
            $Return = $this._Verbosity($Method, $Results)
            return $Return
        }
        catch {
            $this._StatusCodeCheck($_.Exception.Response.StatusCode.value__)
            $this._FormatExceptionMessage($_)
            return $null
        }
    }

    # Generic helper method to invoke POST and PUT REST Methods against a Jamf Pro Server.
    [psobject] InvokeAPI($Resource, $Method, $Payload) {
        try {
            $Results = Invoke-RestMethod -Uri "$($this.Server)JSSResource/$Resource" -Method $Method -Headers $this.Headers -ContentType "application/xml" -Body $Payload -Verbose -ErrorAction SilentlyContinue
            $Return = $this._Verbosity($Method, $Results)
            return $Return
        }
        catch {
            $this._StatusCodeCheck($_.Exception.Response.StatusCode.value__)
            $this._FormatExceptionMessage($_)
            return $null
        }
    }

    # Helper method to provide the object type and ID of the record that was just modified or created.
    [psobject] _Verbosity($Method, $Results) {
        if ( $Method -eq "GET" ) {
            Write-Host -Message "Request successful" -ForegroundColor "Green"
        }
        else {
            $Type = $Results.FirstChild.NextSibling.LocalName
            $ID = $Results.SelectSingleNode("//${Type}") | Select-Object -ExpandProperty InnerText
            $Action = "performed"

            switch ( $Method ) {
                DELETE { $Action = "deleted" }
                POST { $Action = "created" }
                PUT { $Action = "updated" }
            }

            Write-Host -Message "Successfully ${Action} ${Type} id:  ${ID}" -ForegroundColor "Green"
            $Results = $null
        }
        return $Results
    }

    # Helper method that provides a response based on the returned status code from an API call.
    [psobject] _StatusCodeCheck($StatusCode) {
        switch ($StatusCode) {
            200 { Write-Host -Message "Request successful" -ForegroundColor "Green"  }
            201 { Write-Host -Message "Request successful" -ForegroundColor "Green"  }
            400 { Write-Host -Message "Error:  400 / Bad request.  Verify the syntax of the request specifically the XML body." -ForegroundColor "Red" }
            401 { Write-Host -Message "Error:  401 / Authentication failed.  Verify the credentials being used for the request." -ForegroundColor "Red" }
            403 { Write-Host -Message "Error:  403 / Invalid permissions.  Verify the account being used has the proper permissions for the object/resource you are trying to access." -ForegroundColor "Red" }
            404 { Write-Host -Message "Error:  404 / Resource not found.  Verify the URL path is correct." -ForegroundColor "Red" }
            409 { Write-Host -Message "Error:  409 / Conflict - A resource by this name already exists." -ForegroundColor "Red" }
            500 { Write-Host -Message "Error:  500 / Internal server error.  Retry the request or contact Jamf support if the error is persistent." -ForegroundColor "Red" }
            Default { Write-Host -Message "Error:  Appears something went wrong, please try again." -ForegroundColor "Red" }
        }
        return $null
    }

    # Helper method to format the response body when a API call fails.
    [psobject] _FormatExceptionMessage($Exception) {
        # The method to get the response body is different for PS Code v6.
        if ($Global:PSVersionTable.PSVersion.Major -lt 6) {
            $ResponseStream = $_.Exception.Response.GetResponseStream()
            $StreamReader = New-Object System.IO.StreamReader($ResponseStream)
            $StreamReader.BaseStream.Position = 0
            $ResponseBody = $StreamReader.ReadToEnd()            
        }
        else {
            $ResponseBody = $_.ErrorDetails.Message
        }
        
        # Split the reponse body, so we can grab the content we're interested in.
        $errorDescription = $($ResponseBody -split [Environment]::NewLine)
        Write-Host -Message "Response:  $($errorDescription[5]) - $($errorDescription[6])" -ForegroundColor "Red"
        return $null
    }

    # Helper method that will verify credentials by doing an API call and checking the result to verify permissions.
    [psobject] VerifyAPICredentials() {
        Write-Host -Message "Verifying API credentials..." -ForegroundColor "Yellow"
        Try {
            Invoke-RestMethod -Uri "$($this.Server)JSSResource/jssuser" -Method GET -Headers $this.Headers -Verbose -ErrorAction SilentlyContinue
            Write-Host -Message "API Credentials Valid!" -ForegroundColor "Blue"
        }
        Catch {
            $this._StatusCodeCheck($_.Exception.Response.StatusCode.value__)
            $this._FormatExceptionMessage($_)
            Write-Host -Message "ERROR:  Invalid Credentials or permissions." -ForegroundColor "Red"
            return $null
        }
        return $null
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
    [xml] _AddXMLElement($Payload, $Parent, $Child) {
        # Creation of a node and its text
        $xmlElt = $Payload.CreateElement("${Child}")
        # Add the node to the document
        $Payload.SelectSingleNode("${Parent}").AppendChild($xmlElt)
        return $Payload
    }

    # Add an elemnt to the XML Payload
    [xml] _AddXMLText($Payload, $Parent, $Element, $ElementText) {
        # Creation of a node and its text
        $xmlElt = $Payload.CreateElement("${Element}")
        $xmlText = $Payload.CreateTextNode("${ElementText}")
        $xmlElt.AppendChild($xmlText) | Out-Null
        # Add the node to the document
        $Payload.SelectSingleNode("${Parent}").AppendChild($xmlElt)
        return $Payload
    }

    # Helper to build an xml Node
    [psobject] BuildXMLNode($Node, $Configuration) {
        $Payload = $this._BuildXML($Node)

        # Loop through each configuration item and create a node from it.
        ForEach ($Key in $Configuration.Keys) {

            # Check if the configuration has a sub-element.
            if ( $Key -match "[.]" ) {
                # Split the configuration between parent and child elements.
                $ParentKey, $ChildKey = $Key -split "[.]"
                # Create a parent element and add the node to the document
                $Payload = $this._AddXMLElement($Payload, "/*", "${ParentKey}")
                # Create a node from an element and text
                $Payload = $this._AddXMLText($Payload, "//${ParentKey}", "${ChildKey}", "$($Configuration.$Key)")
            }
            else {
                $Payload = $this._AddXMLText($Payload, "/*", "${Key}", "$($Configuration.$Key)")
            }
        }

        # My hacky idea to create subnodes from keys with a "." will end up creating multiple subnodes of the same name, if multiple properities for a subnode is specified.
        # So here, we'll clean those up.
        $EmptyNodes = $Payload.SelectNodes("//*[count(@*) = 0 and count(child::*) = 0 and not(string-length(text())) > 0]")
        $EmptyNodes | ForEach-Object { $_.ParentNode.RemoveChild($_) } | Out-Null

        return $Payload
    }

    # Helper to build an xml Node
    [psobject] BuildXMLNode($Node, $Key, $Values) {
        $Payload = $this._BuildXML("${Node}s")

        # Loop through each configuration item and create a node from it.
        ForEach ($Value in $Values) {
            $Element = $this._BuildXML($Node)
            $Element = $this._AddXMLText($Element, $Node, $Key, $Value)
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
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns account by username
    [psobject] GetAccountByUsername($Name) {
        $Resource = "accounts/username/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns account by userid
    [psobject] GetAccountByUserid($ID) {
        $Resource = "accounts/userid/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new account
    [psobject] CreateAccountUser($Payload) {
        $Resource = "accounts/userid/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by username
    [psobject] UpdateAccountByUsername($Name, $Payload) {
        $Resource = "accounts/username/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by userid
    [psobject] UpdateAccountByUserid($ID, $Payload) {
        $Resource = "accounts/userid/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes account by username
    [psobject] DeleteAccountByUsername($Name) {
        $Resource = "accounts/username/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes account by userid
    [psobject] DeleteAccountByUserid($ID) {
        $Resource = "accounts/userid/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns account by groupname
    [psobject] GetAccountByGroupname($Name) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns account by groupid
    [psobject] GetAccountByGroupid($ID) {
        $Resource = "accounts/groupid/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new account
    [psobject] CreateAccountGroup($Payload) {
        $Resource = "accounts/groupid/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by groupname
    [psobject] UpdateAccountByGroupname($Name, $Payload) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by groupid
    [psobject] UpdateAccountByGroupID($ID, $Payload) {
        $Resource = "accounts/groupid/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes account by groupname
    [psobject] DeleteAccountByGroupname($Name) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes account by groupid
    [psobject] DeleteAccountByID($ID) {
        $Resource = "accounts/groupid/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /activationcode #####

    # Returns all activationcode
    [psobject] GetActivationcode() {
        $Resource = "activationcode"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates activationcode
    [psobject] UpdateActivationcode($Code) {
        $Resource = "activationcode"
        $Method = "PUT"
        $Payload = $this._BuildXML("activation_code")
        $Payload = $this._AddXMLText($Payload, "activation_code", "code", $Code)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /advancedcomputersearches #####

    # Returns all advancedcomputersearches
    [psobject] GetAdvancedComputerSearches() {
        $Resource = "advancedcomputersearches"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns advanced computer search by name
    [psobject] GetAdvancedComputerSearchByName($Name) {
        $Resource = "advancedcomputersearches/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns advanced computer search by id
    [psobject] GetAdvancedComputerSearchById($ID) {
        $Resource = "advancedcomputersearches/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new advanced computer search
    [psobject] CreateAdvancedComputerSearch($Payload) {
        $Resource = "advancedcomputersearches/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates advanced computer search by name
    [psobject] UpdateAdvancedComputerSearchByName($Name, $Payload) {
        $Resource = "advancedcomputersearches/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates advanced computer search by id
    [psobject] UpdateAdvancedComputerSearchByID($ID, $Payload) {
        $Resource = "advancedcomputersearches/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes advanced computer search by name
    [psobject] DeleteAdvancedComputerSearchByName($Name) {
        $Resource = "advancedcomputersearches/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes advanced computer search by id
    [psobject] DeleteAdvancedComputerSearchByID($ID) {
        $Resource = "advancedcomputersearches/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }


    ##### Resource Path:  /advancedmobiledevicesearches #####

    # Returns all advancedmobiledevicesearches
    [psobject] GetAdvancedMobileDeviceSearches() {
        $Resource = "advancedmobiledevicesearches"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns advanced mobile device search by name
    [psobject] GetAdvancedMobileDeviceSearchByName($Name) {
        $Resource = "advancedmobiledevicesearches/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns advanced mobile device search by id
    [psobject] GetAdvancedMobileDeviceSearchById($ID) {
        $Resource = "advancedmobiledevicesearches/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new advanced mobile device search
    [psobject] CreateAdvancedMobileDeviceSearch($Payload) {
        $Resource = "advancedmobiledevicesearches/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates advanced mobile device search by name
    [psobject] UpdateAdvancedMobileDeviceSearchByName($Name, $Payload) {
        $Resource = "advancedmobiledevicesearches/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates advanced mobile device search by id
    [psobject] UpdateAdvancedMobileDeviceSearchByID($ID, $Payload) {
        $Resource = "advancedmobiledevicesearches/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes advanced mobile device search by name
    [psobject] DeleteAdvancedMobileDeviceSearchByName($Name) {
        $Resource = "advancedmobiledevicesearches/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes advanced mobile device search by id
    [psobject] DeleteAdvancedMobileDeviceSearchByID($ID) {
        $Resource = "advancedmobiledevicesearches/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }


    ##### Resource Path:  /advancedusersearches #####

    # Returns all advancedusersearches
    [psobject] GetAdvancedUserSearches() {
        $Resource = "advancedusersearches"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns advanced user search by name
    [psobject] GetAdvancedUserSearchByName($Name) {
        $Resource = "advancedusersearches/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Returns advanced user search by id
    [psobject] GetAdvancedUserSearchById($ID) {
        $Resource = "advancedusersearches/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Creates new advanced user search
    [psobject] CreateAdvancedUserSearch($Payload) {
        $Resource = "advancedusersearches/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates advanced user search by name
    [psobject] UpdateAdvancedUserSearchByName($Name, $Payload) {
        $Resource = "advancedusersearches/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Updates advanced user search by id
    [psobject] UpdateAdvancedUserSearchByID($ID, $Payload) {
        $Resource = "advancedusersearches/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource,$Method,$Payload)
        return $Results
    }

    # Deletes advanced user search by name
    [psobject] DeleteAdvancedUserSearchByName($Name) {
        $Resource = "advancedusersearches/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Deletes advanced user search by id
    [psobject] DeleteAdvancedUserSearchByID($ID) {
        $Resource = "advancedusersearches/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource,$Method)
        return $Results
    }

    # Helper to build an advanced searches from Subsets
    [psobject] BuildAdvancedSearch($Type, $Subsets) {
        $Payload = $this._BuildXML("advanced_${Type}_search")
        $Payload = $this._AddXMLElement($Payload, "//criteria", "criterion")
        $Payload = $this._AddXMLElement($Payload, "//display_fields", "display_field")
 
        # Loop through each Subset value and append it to the payload
        foreach ( $Subset in $Subsets) {
            $Subset.FirstChild.NextSibling.LocalName

            switch ($Subset.FirstChild.NextSibling.LocalName) {
                "criterion" {
                    $Payload.DocumentElement.SelectSingleNode("//criteria").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                "display_field" {
                    $Payload.DocumentElement.SelectSingleNode("//display_fields").AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
                Default {
                    $Payload.DocumentElement.AppendChild($Payload.ImportNode($Subset.($Subset.FirstChild.NextSibling.LocalName), $true)) | Out-Null
                }
            }
        }
        return $Payload
    }


    ##### Resource Path:  /buildings #####

    # Returns all buildings
    [psobject] GetBuildings() {
        $Resource = "buildings"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns building by name
    [psobject] GetBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns building by id
    [psobject] GetBuildingById($ID) {
        $Resource = "buildings/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new building
    [psobject] CreateBuilding($Name) {
        $Resource = "buildings/id/0"
        $Method = "POST"
        $Payload = $this._BuildXML("building")
        $Payload = $this._AddXMLText($Payload, "building", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates building by name
    [psobject] UpdateBuildingByName($OldName, $NewName) {
        $Resource = "buildings/name/${OldName}"
        $Method = "PUT"
        $Payload = $this._BuildXML("building")
        $Payload = $this._AddXMLText($Payload, "building", "name", $NewName)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates building by id
    [psobject] UpdateBuildingByID($ID, $Name) {
        $Resource = "buildings/id/${ID}"
        $Method = "PUT"
        $Payload = $this._BuildXML("building")
        $Payload = $this._AddXMLText($Payload, "building", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes building by name
    [psobject] DeleteBuildingByName($Name) {
        $Resource = "buildings/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes building by id
    [psobject] DeleteBuildingByID($ID) {
        $Resource = "buildings/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /computerapplications #####

    # Returns computerapplication by name
    [psobject] GetComputerApplicationByName($Application) {
        $Resource = "computerapplications/application/${Application}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerapplication by name, including inventory information
    [psobject] GetComputerApplicationByNameAndInventory($Application, $Inventory) {
        $Resource = "computerapplications/application/${Application}/inventory/${Inventory}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerapplication by name and version
    [psobject] GetComputerApplicationByNameAndVersion($Application, $Version) {
        $Resource = "computerapplications/application/${Application}/version/${Version}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerapplication by name and version, including inventory information
    [psobject] GetComputerApplicationByNameAndVersionAndInventory($Application, $Version, $Inventory) {
        $Resource = "computerapplications/application/${Application}/version/${Version}/inventory/${Inventory}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /categories #####

    # Returns all categories
    [psobject] GetCategories() {
        $Resource = "categories"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns category by name
    [psobject] GetCategoryByName($Name) {
        $Resource = "categories/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns category by id
    [psobject] GetCategoryById($ID) {
        $Resource = "categories/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new category
    [psobject] CreateCategory($Name) {
        $Resource = "categories/id/0"
        $Method = "POST"
        $Payload = $this._BuildXML("category")
        $Payload = $this._AddXMLText($Payload, "category", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates category by name
    [psobject] UpdateCategoryByName($OldName, $NewName) {
        $Resource = "categories/name/${OldName}"
        $Method = "PUT"
        $Payload = $this._BuildXML("category")
        $Payload = $this._AddXMLText($Payload, "category", "name", $NewName)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates category by id
    [psobject] UpdateCategoryByID($ID, $Name) {
        $Resource = "categories/id/${ID}"
        $Method = "PUT"
        $Payload = $this._BuildXML("category")
        $Payload = $this._AddXMLText($Payload, "category", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes category by name
    [psobject] DeleteCategoryByName($Name) {
        $Resource = "categories/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes category by id
    [psobject] DeleteCategoryByID($ID) {
        $Resource = "categories/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /computerextensionattributes #####

    # Returns all computerextensionattributes
    [psobject] GetComputerExtensionAttributes() {
        $Resource = "computerextensionattributes"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerextensionattribute by name
    [psobject] GetComputerExtensionAttributeByName($Name) {
        $Resource = "computerextensionattributes/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerextensionattribute by id
    [psobject] GetComputerExtensionAttributeById($ID) {
        $Resource = "computerextensionattributes/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new computerextensionattribute
    [psobject] CreateComputerExtensionAttribute($Payload) {
        $Resource = "computerextensionattributes/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computerextensionattribute by name
    [psobject] UpdateComputerExtensionAttributeByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.LocalName)//name").InnerText
        $Resource = "computerextensionattributes/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computerextensionattribute by id
    [psobject] UpdateComputerExtensionAttributeByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.LocalName)//id").InnerText
        $Resource = "computerextensionattributes/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes computerextensionattribute by name
    [psobject] DeleteComputerExtensionAttributeByName($Name) {
        $Resource = "computerextensionattributes/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computerextensionattribute by id
    [psobject] DeleteComputerExtensionAttributeByID($ID) {
        $Resource = "computerextensionattributes/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /departments #####

    # Returns all departments
    [psobject] GetDepartments() {
        $Resource = "departments"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns department by name
    [psobject] GetDepartmentByName($Name) {
        $Resource = "departments/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns department by id
    [psobject] GetDepartmentById($ID) {
        $Resource = "departments/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new department
    [psobject] CreateDepartment($Name) {
        $Resource = "departments/id/0"
        $Method = "POST"
        $Payload = $this._BuildXML("department")
        $Payload = $this._AddXMLText($Payload, "department", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates department by name
    [psobject] UpdateDepartmentByName($OldName, $NewName) {
        $Resource = "departments/name/${OldName}"
        $Method = "PUT"
        $Payload = $this._BuildXML("department")
        $Payload = $this._AddXMLText($Payload, "department", "name", $NewName)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates department by id
    [psobject] UpdateDepartmentByID($ID, $Name) {
        $Resource = "departments/id/${ID}"
        $Method = "PUT"
        $Payload = $this._BuildXML("department")
        $Payload = $this._AddXMLText($Payload, "department", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes department by name
    [psobject] DeleteDepartmentByName($Name) {
        $Resource = "departments/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes department by id
    [psobject] DeleteDepartmentByID($ID) {
        $Resource = "departments/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /computergroups #####

    # Returns all computer groups
    [psobject] GetComputerGroups() {
        $Resource = "computergroups"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer group by name
    [psobject] GetComputerGroupByName($Name) {
        $Resource = "computergroups/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer group by id
    [psobject] GetComputerGroupById($ID) {
        $Resource = "computergroups/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new computer group
    [psobject] CreateComputerGroup($Payload) {
        $Resource = "computergroups/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer group by name
    [psobject] UpdateComputerGroupByName($Name, $Payload) {
        $Resource = "computergroups/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer group by id
    [psobject] UpdateComputerGroupByID($ID, $Payload) {
        $Resource = "computergroups/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes computer group by name
    [psobject] DeleteComputerGroupByName($Name) {
        $Resource = "computergroups/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computer group by id
    [psobject] DeleteComputerGroupByID($ID) {
        $Resource = "computergroups/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates static computer group by name (uses computer_additions and computer_deletions)
    [psobject] UpdateStaticComputerGroupByName($Group, $Computers, $Action) {
        $Resource = "computergroups/name/${Group}"
        $Method = "PUT"
        $Payload = $this._BuildXML("computer_group")
        $Payload = $this._AddXMLElement($Payload, "//computer_group", "computer_${Action}")
        $NestedNodes = $this.BuildXMLNode("computer", "name", $Computers)
        $Payload.DocumentElement.SelectSingleNode("//computer_${Action}").AppendChild($Payload.ImportNode($NestedNodes.($NestedNodes.FirstChild.NextSibling.LocalName), $true)) | Out-Null        
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates static computer group by id (uses computer_additions and computer_deletions)
    [psobject] UpdateStaticComputerGroupById($Group, $Computers, $Action) {
        $Resource = "computergroups/id/${Group}"
        $Method = "PUT"
        $Payload = $this._BuildXML("computer_group")
        $Payload = $this._AddXMLElement($Payload, "//computer_group", "computer_${Action}")
        $NestedNodes = $this.BuildXMLNode("computer", "id", $Computers)
        $Payload.DocumentElement.SelectSingleNode("//computer_${Action}").AppendChild($Payload.ImportNode($NestedNodes.($NestedNodes.FirstChild.NextSibling.LocalName), $true)) | Out-Null        
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /computers #####

    # Returns all computers
    [psobject] GetComputers() {
        $Resource = "computers"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all computers with a larger set of basic information
    [psobject] GetComputersBasic() {
        $Resource = "computers/subset/basic"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all computers that match the given value; uses the same format as the general search in the JPS; also supports wildcards (*).
    [psobject] SearchComputers($Match) {
        $Resource = "computers/match/${Match}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all computers that match the given name parameter
    [psobject] MatchComputersName($Match) {
        $Resource = "computers/match/name/${Match}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all computers that match the given name parameter with a larger set of basic information
    [psobject] MatchComputersNameBasic($Match) {
        $Resource = "computers/match/name/${Match}/subset/basic"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer by name
    [psobject] GetComputerByName($Name) {
        $Resource = "computers/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer by id
    [psobject] GetComputerById($ID) {
        $Resource = "computers/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer by udid
    [psobject] GetComputerByUDID($UDID) {
        $Resource = "computers/udid/${UDID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer by serialnumber
    [psobject] GetComputerBySerialNumber($SerialNumber) {
        $Resource = "computers/serialnumber/${SerialNumber}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer by macaddress
    [psobject] GetComputerByMACAddress($MACAddress) {
        $Resource = "computers/macaddress/${MACAddress}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer Subsets by name
    [psobject] GetComputerSubsetByName($Name, $Subset) {
        $Resource = "computers/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer Subsets by id
    [psobject] GetComputerSubsetById($ID, $Subset) {
        $Resource = "computers/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer Subsets by udid
    [psobject] GetComputerSubsetByUDID($UDID, $Subset) {
        $Resource = "computers/udid/${UDID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer Subsets by serialnumber
    [psobject] GetComputerSubsetBySerialNumber($SerialNumber, $Subset) {
        $Resource = "computers/serialnumber/${SerialNumber}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer Subsets by macaddress
    [psobject] GetComputerSubsetByMACAddress($MACAddress, $Subset) {
        $Resource = "computers/macaddress/${MACAddress}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new computer
    [psobject] CreateComputer($Payload) {
        $Resource = "computers/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by name
    [psobject] UpdateComputerByName($Name, $Payload) {
        $Resource = "computers/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by id
    [psobject] UpdateComputerByID($ID, $Payload) {
        $Resource = "computers/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by udid
    [psobject] UpdateComputerByUDID($UDID) {
        $Resource = "computers/udid/${UDID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates computer by serialnumber
    [psobject] UpdateComputerBySerialNumber($SerialNumber) {
        $Resource = "computers/serialnumber/${SerialNumber}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates computer by macaddress
    [psobject] UpdateComputerByMACAddress($MACAddress) {
        $Resource = "computers/macaddress/${MACAddress}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computer by name
    [psobject] DeleteComputerByName($Name) {
        $Resource = "computers/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computer by id
    [psobject] DeleteComputerByID($ID) {
        $Resource = "computers/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computer by udid
    [psobject] DeleteComputerByUDID($UDID) {
        $Resource = "computers/udid/${UDID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computer by serialnumber
    [psobject] DeleteComputerBySerialNumber($SerialNumber) {
        $Resource = "computers/serialnumber/${SerialNumber}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computer by macaddress
    [psobject] DeleteComputerByMACAddress($MACAddress) {
        $Resource = "computers/macaddress/${MACAddress}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /mobiledevicegroups #####

    # Returns all mobiledevicegroups
    [psobject] GetMobileDeviceGroups() {
        $Resource = "mobiledevicegroups"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device group by name
    [psobject] GetMobileDeviceGroupByName($Name) {
        $Resource = "mobiledevicegroups/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device group by id
    [psobject] GetMobileDeviceGroupById($ID) {
        $Resource = "mobiledevicegroups/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobile device group
    [psobject] CreateMobileDeviceGroup($Payload) {
        $Resource = "mobiledevicegroups/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device group by name
    [psobject] UpdateMobileDeviceGroupByName($Name, $Payload) {
        $Resource = "mobiledevicegroups/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device group by id
    [psobject] UpdateMobileDeviceGroupByID($ID, $Payload) {
        $Resource = "mobiledevicegroups/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes mobile device group by name
    [psobject] DeleteMobileDeviceGroupByName($Name) {
        $Resource = "mobiledevicegroups/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobile device group by id
    [psobject] DeleteMobileDeviceGroupByID($ID) {
        $Resource = "mobiledevicegroups/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates static mobile device group by name (uses mobile_device_additions and mobile_device_deletions)
    [psobject] UpdateStaticMobileDeviceGroupByName($Group, $MobileDevices, $Action) {
        $Resource = "mobiledevicegroups/name/${Group}"
        $Method = "PUT"
        $Payload = $this._BuildXML("mobile_device_group")
        $Payload = $this._AddXMLElement($Payload, "//mobile_device_group", "mobile_device_${Action}")
        $NestedNodes = $this.BuildXMLNode("mobile_device", "name", $MobileDevices)
        $Payload.DocumentElement.SelectSingleNode("//mobile_device_${Action}").AppendChild($Payload.ImportNode($NestedNodes.($NestedNodes.FirstChild.NextSibling.LocalName), $true)) | Out-Null        
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates static mobile device group by id (uses mobile_device_additions and mobile_device_deletions)
    [psobject] UpdateStaticMobileDeviceGroupById($Group, $MobileDevices, $Action) {
        $Resource = "mobiledevicegroups/id/${Group}"
        $Method = "PUT"
        $Payload = $this._BuildXML("mobile_device_group")
        $Payload = $this._AddXMLElement($Payload, "//mobile_device_group", "mobile_device_${Action}")
        $NestedNodes = $this.BuildXMLNode("mobile_device", "id", $MobileDevices)
        $Payload.DocumentElement.SelectSingleNode("//mobile_device_${Action}").AppendChild($Payload.ImportNode($NestedNodes.($NestedNodes.FirstChild.NextSibling.LocalName), $true)) | Out-Null        
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /mobiledevices #####

    # Returns all mobiledevices
    [psobject] GetMobileDevices() {
        $Resource = "mobiledevices"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all mobiledevices with a larger set of basic information
    [psobject] GetMobileDevicesBasic() {
        $Resource = "mobiledevices/subset/basic"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all mobiledevices that match the given value; uses the same format as the general search in the JPS; also supports wildcards (*).
    [psobject] SearchMobileDevices($Match) {
        $Resource = "mobiledevices/match/${Match}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all mobiledevices that match the given name parameter
    [psobject] MatchMobileDevicesName($Match) {
        $Resource = "mobiledevices/match/name/${Match}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns all mobiledevices that match the given name parameter with a larger set of basic information
    [psobject] MatchMobileDevicesNameBasic($Match) {
        $Resource = "mobiledevices/match/name/${Match}/subset/basic"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device by name
    [psobject] GetMobileDeviceByName($Name) {
        $Resource = "mobiledevices/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device by id
    [psobject] GetMobileDeviceById($ID) {
        $Resource = "mobiledevices/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device by udid
    [psobject] GetMobileDeviceByUDID($UDID) {
        $Resource = "mobiledevices/udid/${UDID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device by serialnumber
    [psobject] GetMobileDeviceBySerialNumber($SerialNumber) {
        $Resource = "mobiledevices/serialnumber/${SerialNumber}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device by macaddress
    [psobject] GetMobileDeviceByMACAddress($MACAddress) {
        $Resource = "mobiledevices/macaddress/${MACAddress}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device Subsets by name
    [psobject] GetMobileDeviceSubsetByName($Name, $Subset) {
        $Resource = "mobiledevices/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device Subsets by id
    [psobject] GetMobileDeviceSubsetById($ID, $Subset) {
        $Resource = "mobiledevices/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device Subsets by udid
    [psobject] GetMobileDeviceSubsetByUDID($UDID, $Subset) {
        $Resource = "mobiledevices/udid/${UDID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device Subsets by serialnumber
    [psobject] GetMobileDeviceSubsetBySerialNumber($SerialNumber, $Subset) {
        $Resource = "mobiledevices/serialnumber/${SerialNumber}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device Subsets by macaddress
    [psobject] GetMobileDeviceSubsetByMACAddress($MACAddress, $Subset) {
        $Resource = "mobiledevices/macaddress/${MACAddress}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobile device
    [psobject] CreateMobileDevice($Payload) {
        $Resource = "mobiledevices/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by name
    [psobject] UpdateMobileDeviceByName($Name, $Payload) {
        $Resource = "mobiledevices/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by id
    [psobject] UpdateMobileDeviceByID($ID, $Payload) {
        $Resource = "mobiledevices/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by udid
    [psobject] UpdateMobileDeviceByUDID($UDID) {
        $Resource = "mobiledevices/udid/${UDID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates mobile device by serialnumber
    [psobject] UpdateMobileDeviceBySerialNumber($SerialNumber) {
        $Resource = "mobiledevices/serialnumber/${SerialNumber}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates mobile device by macaddress
    [psobject] UpdateMobileDeviceByMACAddress($MACAddress) {
        $Resource = "mobiledevices/macaddress/${MACAddress}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobile device by name
    [psobject] DeleteMobileDeviceByName($Name) {
        $Resource = "mobiledevices/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobile device by id
    [psobject] DeleteMobileDeviceByID($ID) {
        $Resource = "mobiledevices/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobile device by udid
    [psobject] DeleteMobileDeviceByUDID($UDID) {
        $Resource = "mobiledevices/udid/${UDID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobile device by serialnumber
    [psobject] DeleteMobileDeviceBySerialNumber($SerialNumber) {
        $Resource = "mobiledevices/serialnumber/${SerialNumber}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobile device by macaddress
    [psobject] DeleteMobileDeviceByMACAddress($MACAddress) {
        $Resource = "mobiledevices/macaddress/${MACAddress}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /packages #####

    # Returns all packages
    [psobject] GetPackages() {
        $Resource = "packages"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns package by name
    [psobject] GetPackageByName($Name) {
        $Resource = "packages/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns package by id
    [psobject] GetPackageById($ID) {
        $Resource = "packages/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new package
    [psobject] CreatePackage($Payload) {
        $Resource = "packages/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates package by name
    [psobject] UpdatePackageByName($Name, $Payload) {
        $Resource = "packages/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates package by id
    [psobject] UpdatePackageByID($ID, $Payload) {
        $Resource = "packages/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes package by name
    [psobject] DeletePackageByName($Name) {
        $Resource = "packages/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes package by id
    [psobject] DeletePackageByID($ID) {
        $Resource = "packages/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /policies #####

    # Returns all policies
    [psobject] GetPolicies() {
        $Resource = "policies"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns policy by name
    [psobject] GetPolicyByName($Name) {
        $Resource = "policies/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns policy by id
    [psobject] GetPolicyById($ID) {
        $Resource = "policies/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns policy Subsets by name
    [psobject] GetPolicySubsetByName($Name, $Subset) {
        $Resource = "policies/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns policy Subsets by id
    [psobject] GetPolicySubsetById($ID, $Subset) {
        $Resource = "policies/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns policies by category
    [psobject] GetPoliciesByCategory($Category) {
        $Resource = "policies/category/${Category}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns policies by type
    [psobject] GetPoliciesByCreatedBy($CreatedBy) {
        $Resource = "policies/createdBy/${CreatedBy}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new policy
    [psobject] CreatePolicy($Payload) {
        $Resource = "policies/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates policy by name
    [psobject] UpdatePolicyByName($Name, $Payload) {
        $Resource = "policies/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates policy by id
    [psobject] UpdatePolicyByID($ID, $Payload) {
        $Resource = "policies/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes policy by name
    [psobject] DeletePolicyByName($Name) {
        $Resource = "policies/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes policy by id
    [psobject] DeletePolicyByID($ID) {
        $Resource = "policies/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Adds package by name to policy by name, specifying the action (cache, install, uninstall)
    [psobject] AddPackageToPolicyByName($PolicyName, $PackageName, $Action) {
        $Resource = "policies/name/${PolicyName}"
        $Method = "PUT"
        $Payload = $this._BuildXML("package_configuration")
        $Payload = $this._AddXMLElement($Payload, "package_configuration", "packages")
        $Payload = $this._AddXMLText($Payload, "packages", "name", $PackageName)
        $Payload = $this._AddXMLText($Payload, "packages", "action", $Action)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Helper to build a policy from Subsets
    [psobject] BuildPolicy($Subsets) {
        $Payload = $this._BuildXML("policy")
        $Payload = $this._AddXMLElement($Payload, "//policy", "package_configuration")
        $Payload = $this._AddXMLElement($Payload, "//package_configuration", "packages")
        $Payload = $this._AddXMLElement($Payload, "//policy", "scripts")
        $Payload = $this._AddXMLElement($Payload, "//policy", "printers")
        $Payload = $this._AddXMLElement($Payload, "//policy", "dock_items")
        $Payload = $this._AddXMLElement($Payload, "//policy", "account_maintenance")
        $Payload = $this._AddXMLElement($Payload, "//account_maintenance", "accounts")
        $Payload = $this._AddXMLElement($Payload, "//policy", "directory_bindings")

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


    ##### Resource Path:  /printers #####

    # Returns all printers
    [psobject] GetPrinters() {
        $Resource = "printers"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns printer by name
    [psobject] GetPrinterByName($Name) {
        $Resource = "printers/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns printer by id
    [psobject] GetPrinterById($ID) {
        $Resource = "printers/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new printer
    [psobject] CreatePrinter($Configuration) {
        $Resource = "printers/id/0"
        $Method = "POST"
        $Payload = $this.BuildXMLNode("printer",$Configuration)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates printer by name
    [psobject] UpdatePrinterByName($Name, $Configuration) {
        $Resource = "printers/name/${Name}"
        $Method = "PUT"
        $Payload = $this.BuildXMLNode("printer",$Configuration)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates printer by id
    [psobject] UpdatePrinterByID($ID, $Configuration) {
        $Resource = "printers/id/${ID}"
        $Method = "PUT"
        $Payload = $this.BuildXMLNode("printer",$Configuration)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes printer by name
    [psobject] DeletePrinterByName($Name) {
        $Resource = "printers/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes printer by id
    [psobject] DeletePrinterByID($ID) {
        $Resource = "printers/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /sites #####

    # Returns all sites
    [psobject] GetSites() {
        $Resource = "sites"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns site by name
    [psobject] GetSiteByName($Name) {
        $Resource = "sites/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns site by id
    [psobject] GetSiteById($ID) {
        $Resource = "sites/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new site
    [psobject] CreateSite($Name) {
        $Resource = "sites/id/0"
        $Method = "POST"
        $Payload = $this._BuildXML("site")
        $Payload = $this._AddXMLText($Payload, "site", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates site by name
    [psobject] UpdateSiteByName($OldName, $NewName) {
        $Resource = "sites/name/${OldName}"
        $Method = "PUT"
        $Payload = $this._BuildXML("site")
        $Payload = $this._AddXMLText($Payload, "site", "name", $NewName)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates site by id
    [psobject] UpdateSiteByID($ID, $Name) {
        $Resource = "sites/id/${ID}"
        $Method = "PUT"
        $Payload = $this._BuildXML("site")
        $Payload = $this._AddXMLText($Payload, "site", "name", $Name)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes site by name
    [psobject] DeleteSiteByName($Name) {
        $Resource = "sites/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes site by id
    [psobject] DeleteSiteByID($ID) {
        $Resource = "sites/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  / #####


}