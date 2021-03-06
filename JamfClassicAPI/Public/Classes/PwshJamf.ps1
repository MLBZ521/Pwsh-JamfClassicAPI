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

        # Encode (aka escape) any chacters in the resource url path.
        $Resource = $this._URLEncode($Resource)

        try {
            $Results = Invoke-RestMethod -Uri "$($this.Server)JSSResource/$Resource" -Method $Method -Headers $this.Headers -Verbose -ErrorAction SilentlyContinue
            $Return = $this._Verbosity($Method, $Results)
            return $Return
        }
        catch {
            if ( $Resource.Split("/")[0] -ne "sites" ) {
                $this._StatusCodeCheck($_.Exception.Response.StatusCode.value__)
            }
            return $this._FormatExceptionMessage($_)
        }
    }

    # Generic helper method to invoke POST and PUT REST Methods against a Jamf Pro Server.
    [psobject] InvokeAPI($Resource, $Method, $Payload) {

        # Encode (aka escape) any chacters in the resource url path.
        $Resource = $this._URLEncode($Resource)

        try {
            $Results = Invoke-RestMethod -Uri "$($this.Server)JSSResource/$Resource" -Method $Method -Headers $this.Headers -ContentType "application/xml" -Body $Payload -Verbose -ErrorAction SilentlyContinue
            $Return = $this._Verbosity($Method, $Results)
            return $Return
        }
        catch {
            $this._StatusCodeCheck($_.Exception.Response.StatusCode.value__)
            return $this._FormatExceptionMessage($_)
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
        Write-Host -Message "Response:  $($errorDescription[5]) - $($errorDescription[6])" -ForegroundColor "Magenta"
        return $errorDescription[6]
    }

    # Helper method to sanitize text for use in a URL
    [psobject] _URLEncode($DirtyText) {
        $DirtyText = [System.Net.WebUtility]::HTMLDecode($DirtyText)
        $CleanText = ($DirtyText).Replace($DirtyText.Split('/')[-1], [System.Net.WebUtility]::UrlEncode($DirtyText.Split('/')[-1]))
        return $CleanText
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
            return $this._FormatExceptionMessage($_)
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
    [psobject] GetAccountByUserName($Name) {
        $Resource = "accounts/username/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns account by userid
    [psobject] GetAccountByUserID($ID) {
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
    [psobject] UpdateAccountByUserName($Name, $Payload) {
        $Resource = "accounts/username/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by username
    [psobject] UpdateAccountByUserName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "accounts/username/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by userid
    [psobject] UpdateAccountByUserID($ID, $Payload) {
        $Resource = "accounts/userid/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by userid
    [psobject] UpdateAccountByUserID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "accounts/userid/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes account by username
    [psobject] DeleteAccountByUserName($Name) {
        $Resource = "accounts/username/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes account by userid
    [psobject] DeleteAccountByUserID($ID) {
        $Resource = "accounts/userid/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns account by groupname
    [psobject] GetAccountByGroupName($Name) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns account by groupid
    [psobject] GetAccountByGroupID($ID) {
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
    [psobject] UpdateAccountByGroupName($Name, $Payload) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates account by groupname
    [psobject] UpdateAccountByGroupName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates account by groupid
    [psobject] UpdateAccountByGroupID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "accounts/groupid/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes account by groupname
    [psobject] DeleteAccountByGroupName($Name) {
        $Resource = "accounts/groupname/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes account by groupid
    [psobject] DeleteAccountByGroupID($ID) {
        $Resource = "accounts/groupid/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /activationcode #####

    # Returns all activationcode
    [psobject] GetActivationCode() {
        $Resource = "activationcode"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates activationcode
    [psobject] UpdateActivationCode($Code) {
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
    [psobject] GetAdvancedComputerSearchByID($ID) {
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

    # Updates advanced computer search by name
    [psobject] UpdateAdvancedComputerSearchByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates advanced computer search by id
    [psobject] UpdateAdvancedComputerSearchByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
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
    [psobject] GetAdvancedMobileDeviceSearchByID($ID) {
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

    # Updates advanced mobile device search by name
    [psobject] UpdateAdvancedMobileDeviceSearchByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates advanced mobile device search by id
    [psobject] UpdateAdvancedMobileDeviceSearchByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
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
    [psobject] GetAdvancedUserSearchByID($ID) {
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

    # Updates advanced user search by name
    [psobject] UpdateAdvancedUserSearchByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates advanced user search by id
    [psobject] UpdateAdvancedUserSearchByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
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

    # Helper to build an advanced search from Subsets
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
    [psobject] GetBuildingByID($ID) {
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


    ##### Resource Path:  /byoprofiles #####

    # Returns all byoprofiles
    [psobject] GetBYOProfiles() {
        $Resource = "byoprofiles"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns byoprofile by name
    [psobject] GetBYOProfileByName($Name) {
        $Resource = "byoprofiles/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns byoprofile by id
    [psobject] GetBYOProfileByID($ID) {
        $Resource = "byoprofiles/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns byoprofile by site name
    [psobject] GetBYOProfileBySiteName($SiteName) {
        $Resource = "byoprofiles/site/name/${SiteName}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns byoprofile by site id
    [psobject] GetBYOProfileBySiteId($SiteID) {
        $Resource = "byoprofiles/site/id/${SiteID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new byoprofile
    [psobject] CreateBYOProfile($Payload) {
        $Resource = "byoprofiles/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by name
    [psobject] UpdateBYOProfileByName($Name, $Payload) {
        $Resource = "byoprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by name
    [psobject] UpdateBYOProfileByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "byoprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by site name
    [psobject] UpdateBYOProfileBySiteName($SiteName, $Payload) {
        $Resource = "byoprofiles/site/name/${SiteName}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by site name
    [psobject] UpdateBYOProfileBySiteName($Payload) {
        $SiteName = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//site/name").InnerText
        $Resource = "byoprofiles/site/name/${SiteName}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by id
    [psobject] UpdateBYOProfileByID($ID, $Payload) {
        $Resource = "byoprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by id
    [psobject] UpdateBYOProfileByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "byoprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by site id
    [psobject] UpdateBYOProfileBySiteID($SiteID, $Payload) {
        $Resource = "byoprofiles/site/id/${SiteID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates byoprofile by site id
    [psobject] UpdateBYOProfileBySiteID($Payload) {
        $SiteID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalID)//site/id").InnerText
        $Resource = "byoprofiles/site/id/${SiteID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes byoprofile by name
    [psobject] DeleteBYOProfileByName($Name) {
        $Resource = "byoprofiles/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes byoprofile by id
    [psobject] DeleteBYOProfileByID($ID) {
        $Resource = "byoprofiles/id/${ID}"
        $Method = "DELETE"
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
    [psobject] GetCategoryByID($ID) {
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

    # Creates new category
    [psobject] CreateCategory($Name, $Priority) {
        $Resource = "categories/id/0"
        $Method = "POST"
        $Payload = $this._BuildXML("category")
        $Payload = $this._AddXMLText($Payload, "category", "name", $Name)
        $Payload = $this._AddXMLText($Payload, "category", "priority", $Priority)
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

    # Updates category by name
    [psobject] UpdateCategoryByName($OldName, $NewName, $Priority) {
        $Resource = "categories/name/${OldName}"
        $Method = "PUT"
        $Payload = $this._BuildXML("category")
        $Payload = $this._AddXMLText($Payload, "category", "name", $NewName)
        $Payload = $this._AddXMLText($Payload, "category", "priority", $Priority)
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

    # Updates category by id
    [psobject] UpdateCategoryByID($ID, $Name, $Priority) {
        $Resource = "categories/id/${ID}"
        $Method = "PUT"
        $Payload = $this._BuildXML("category")
        $Payload = $this._AddXMLText($Payload, "category", "name", $Name)
        $Payload = $this._AddXMLText($Payload, "category", "priority", $Priority)
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


    ##### Resource Path:  /classes #####

    # Returns all classes
    [psobject] GetClasses() {
        $Resource = "classes"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns class by name
    [psobject] GetClassByName($Name) {
        $Resource = "classes/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns class by id
    [psobject] GetClassByID($ID) {
        $Resource = "classes/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new class
    [psobject] CreateClass($Payload) {
        $Resource = "classes/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates class by name
    [psobject] UpdateClassByName($Name, $Payload) {
        $Resource = "classes/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates class by name
    [psobject] UpdateClassByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "classes/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates class by id
    [psobject] UpdateClassByID($ID, $Payload) {
        $Resource = "classes/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates class by id
    [psobject] UpdateClassByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "classes/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes class by name
    [psobject] DeleteClassByName($Name) {
        $Resource = "classes/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes class by id
    [psobject] DeleteClassByID($ID) {
        $Resource = "classes/id/${ID}"
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


    ##### Resource Path:  /computercheckin #####

    # Returns all computercheckin
    [psobject] GetComputerCheckin() {
        $Resource = "computercheckin"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates computercheckin
    [psobject] UpdateComputerCheckin($Payload) {
        $Resource = "computercheckin"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /computerconfigurations #####

    # Returns all computerconfigurations
    [psobject] GetComputerConfigurations() {
        $Resource = "computerconfigurations"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerconfiguration by name
    [psobject] GetComputerConfigurationByName($Name) {
        $Resource = "computerconfigurations/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerconfiguration by id
    [psobject] GetComputerConfigurationByID($ID) {
        $Resource = "computerconfigurations/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new computerconfiguration
    [psobject] CreateComputerConfiguration($Payload) {
        $Resource = "computerconfigurations/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computerconfiguration by name
    [psobject] UpdateComputerConfigurationByName($Name, $Payload) {
        $Resource = "computerconfigurations/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computerconfiguration by name
    [psobject] UpdateComputerConfigurationByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "computerconfigurations/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computerconfiguration by id
    [psobject] UpdateComputerConfigurationByID($ID, $Payload) {
        $Resource = "computerconfigurations/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computerconfiguration by id
    [psobject] UpdateComputerConfigurationByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "computerconfigurations/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes computerconfiguration by name
    [psobject] DeleteComputerConfigurationByName($Name) {
        $Resource = "computerconfigurations/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computerconfiguration by id
    [psobject] DeleteComputerConfigurationByID($ID) {
        $Resource = "computerconfigurations/id/${ID}"
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
    [psobject] GetComputerExtensionAttributeByID($ID) {
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
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "computerextensionattributes/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computerextensionattribute by id
    [psobject] UpdateComputerExtensionAttributeByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
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


    ##### Resource Path:  /computerinventorycollection #####

    # Returns all computerinventorycollection
    [psobject] GetComputerInventoryCollection() {
        $Resource = "computerinventorycollection"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates computerinventorycollection
    [psobject] UpdateComputerInventoryCollection($Payload) {
        $Resource = "computerinventorycollection"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
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
    [psobject] GetComputerGroupByID($ID) {
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

    # Updates computer group by name
    [psobject] UpdateComputerGroupByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates computer group by id
    [psobject] UpdateComputerGroupByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
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
    [psobject] UpdateStaticComputerGroupByName($GroupName, $DeviceIdentifier, $ArrayOf_Computers, $Action) {
        $Resource = "computergroups/name/${GroupName}"
        $Method = "PUT"

        switch ($DeviceIdentifier) {
            "serial" { $DeviceIdentifier = "serial_number" }
            "uuid" { $DeviceIdentifier = "udid" }
            "udid" { $DeviceIdentifier = "udid" }
            "id" { $DeviceIdentifier = "id" }
            "mac" { $DeviceIdentifier = "wifi_mac_address" }
            "name" { $DeviceIdentifier = "name" }
        }

        switch ($Action) {
            "add" { $Action = "additions" }
            "remove" { $Action = "deletions" }
            "delete" { $Action = "deletions" }
        }

        $Payload = $this._BuildXML("computer_group")
        $Payload = $this._AddXMLElement($Payload, "//computer_group", "computer_${Action}")

        ForEach ( $Computer in $ArrayOf_Computers ) {
            $Element = $this._BuildXML("computer")
            $Element = $this._AddXMLText($Element, "computer", "${DeviceIdentifier}", $Computer)
            $Payload.DocumentElement.SelectSingleNode("//computer_${Action}").AppendChild($Payload.ImportNode($Element.($Element.FirstChild.NextSibling.LocalName), $true)) | Out-Null
        }

        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates static computer group by id (uses computer_additions and computer_deletions)
    [psobject] UpdateStaticComputerGroupByID($GroupID, $DeviceIdentifier, $ArrayOf_Computers, $Action) {
        $Resource = "computergroups/id/${GroupID}"
        $Method = "PUT"

        switch ($DeviceIdentifier) {
            "serial" { $DeviceIdentifier = "serial_number" }
            "uuid" { $DeviceIdentifier = "udid" }
            "udid" { $DeviceIdentifier = "udid" }
            "id" { $DeviceIdentifier = "id" }
            "mac" { $DeviceIdentifier = "wifi_mac_address" }
            "name" { $DeviceIdentifier = "name" }
        }

        switch ($Action) {
            "add" { $Action = "additions" }
            "remove" { $Action = "deletions" }
            "delete" { $Action = "deletions" }
        }

        $Payload = $this._BuildXML("computer_group")
        $Payload = $this._AddXMLElement($Payload, "//computer_group", "computer_${Action}")

        ForEach ( $Computer in $ArrayOf_Computers ) {
            $Element = $this._BuildXML("computer")
            $Element = $this._AddXMLText($Element, "computer", "${DeviceIdentifier}", $Computer)
            $Payload.DocumentElement.SelectSingleNode("//computer_${Action}").AppendChild($Payload.ImportNode($Element.($Element.FirstChild.NextSibling.LocalName), $true)) | Out-Null
        }

        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /computerinvitations #####

    # Returns all computerinvitations
    [psobject] GetComputerInvitations() {
        $Resource = "computerinvitations"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerinvitation by name
    [psobject] GetComputerInvitationByName($Name) {
        $Resource = "computerinvitations/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerinvitation by id
    [psobject] GetComputerInvitationByID($ID) {
        $Resource = "computerinvitations/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computerinvitation by invitation
    [psobject] GetComputerInvitationByInvitation($Invitation) {
        $Resource = "computerinvitations/Invitation/${Invitation}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new computerinvitation
    [psobject] CreateComputerInvitation($Payload) {
        $Resource = "computerinvitations/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes computerinvitation by name
    [psobject] DeleteComputerInvitationByName($Name) {
        $Resource = "computerinvitations/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computerinvitation by id
    [psobject] DeleteComputerInvitationByID($ID) {
        $Resource = "computerinvitations/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
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
    [psobject] GetComputerByID($ID) {
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
    [psobject] GetComputerSubsetByID($ID, $Subset) {
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

    # Updates computer by name
    [psobject] UpdateComputerByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates computer by id
    [psobject] UpdateComputerByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "computers/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by udid
    [psobject] UpdateComputerByUDID($UDID, $Payload) {
        $Resource = "computers/udid/${UDID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by udid
    [psobject] UpdateComputerByUDID($Payload) {
        $UDID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//udid").InnerText
        $Resource = "computers/udid/${UDID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by serialnumber
    [psobject] UpdateComputerBySerialNumber($SerialNumber, $Payload) {
        $Resource = "computers/serialnumber/${SerialNumber}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by serialnumber
    [psobject] UpdateComputerBySerialNumber($Payload) {
        $SerialNumber = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//serial_number").InnerText
        $Resource = "computers/serialnumber/${SerialNumber}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by macaddress
    [psobject] UpdateComputerByMACAddress($MACAddress, $Payload) {
        $Resource = "computers/macaddress/${MACAddress}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer by macaddress
    [psobject] UpdateComputerByMACAddress($Payload) {
        $MACAddress = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//mac_address").InnerText
        $Resource = "computers/macaddress/${MACAddress}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
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
    [psobject] GetDepartmentByID($ID) {
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


    ##### Resource Path:  /directorybindings #####

    # Returns all directorybindings
    [psobject] GetDirectoryBindings() {
        $Resource = "directorybindings"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns directorybinding by name
    [psobject] GetDirectoryBindingByName($Name) {
        $Resource = "directorybindings/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns directorybinding by id
    [psobject] GetDirectoryBindingByID($ID) {
        $Resource = "directorybindings/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new directorybinding
    [psobject] CreateDirectoryBinding($Payload) {
        $Resource = "directorybindings/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates directorybinding by name
    [psobject] UpdateDirectoryBindingByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "directorybindings/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates directorybinding by id
    [psobject] UpdateDirectoryBindingByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "directorybindings/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes directorybinding by name
    [psobject] DeleteDirectoryBindingByName($Name) {
        $Resource = "directorybindings/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes directorybinding by id
    [psobject] DeleteDirectoryBindingByID($ID) {
        $Resource = "directorybindings/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /diskencryptionconfigurations #####

    # Returns all diskencryptionconfigurations
    [psobject] GetDiskEncryptionConfigurations() {
        $Resource = "diskencryptionconfigurations"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns diskencryptionconfigurations by name
    [psobject] GetDiskEncryptionConfigurationByName($Name) {
        $Resource = "diskencryptionconfigurations/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns diskencryptionconfigurations by id
    [psobject] GetDiskEncryptionConfigurationByID($ID) {
        $Resource = "diskencryptionconfigurations/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new diskencryptionconfigurations
    [psobject] CreateDiskEncryptionConfiguration($Payload) {
        $Resource = "diskencryptionconfigurations/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates diskencryptionconfigurations by name
    [psobject] UpdateDiskEncryptionConfigurationByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "diskencryptionconfigurations/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates diskencryptionconfigurations by id
    [psobject] UpdateDiskEncryptionConfigurationByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "diskencryptionconfigurations/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes diskencryptionconfigurations by name
    [psobject] DeleteDiskEncryptionConfigurationByName($Name) {
        $Resource = "diskencryptionconfigurations/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes diskencryptionconfigurations by id
    [psobject] DeleteDiskEncryptionConfigurationByID($ID) {
        $Resource = "diskencryptionconfigurations/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /ebooks #####

    # Returns all ebooks
    [psobject] GeteBooks() {
        $Resource = "ebooks"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ebook by name
    [psobject] GeteBookByName($Name) {
        $Resource = "ebooks/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ebook by id
    [psobject] GeteBookByID($ID) {
        $Resource = "ebooks/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ebook Subsets by name
    [psobject] GeteBookSubsetByName($Name, $Subset) {
        $Resource = "ebooks/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ebook Subsets by id
    [psobject] GeteBookSubsetByID($ID, $Subset) {
        $Resource = "ebooks/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new ebook
    [psobject] CreateeBook($Payload) {
        $Resource = "ebooks/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ebook by name
    [psobject] UpdateeBookByName($Name, $Payload) {
        $Resource = "ebooks/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ebook by name
    [psobject] UpdateeBookByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "ebooks/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ebook by id
    [psobject] UpdateeBookByID($ID, $Payload) {
        $Resource = "ebooks/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ebook by id
    [psobject] UpdateeBookByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "ebooks/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes ebook by name
    [psobject] DeleteeBookByName($Name) {
        $Resource = "ebooks/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes ebook by id
    [psobject] DeleteeBookByID($ID) {
        $Resource = "ebooks/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /gsxconnection #####

    # Returns all gsxconnection
    [psobject] GetGSXConnection() {
        $Resource = "gsxconnection"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates gsxconnection
    [psobject] UpdateGSXConnection($Payload) {
        $Resource = "gsxconnection"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /ibeacons #####

    # Returns all ibeacons
    [psobject] GetiBeacons() {
        $Resource = "ibeacons"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ibeacons by name
    [psobject] GetiBeaconByName($Name) {
        $Resource = "ibeacons/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ibeacons by id
    [psobject] GetiBeaconByID($ID) {
        $Resource = "ibeacons/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new ibeacons
    [psobject] CreateiBeacon($Payload) {
        $Resource = "ibeacons/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ibeacons by name
    [psobject] UpdateiBeaconByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "ibeacons/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ibeacons by id
    [psobject] UpdateiBeaconByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "ibeacons/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes ibeacons by name
    [psobject] DeleteiBeaconByName($Name) {
        $Resource = "ibeacons/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes ibeacons by id
    [psobject] DeleteiBeaconByID($ID) {
        $Resource = "ibeacons/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /ldapservers #####

    # Returns all ldapservers
    [psobject] GetLDAPServers() {
        $Resource = "ldapservers"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ldapserver by name
    [psobject] GetLDAPServerByName($Name) {
        $Resource = "ldapservers/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns ldapserver by id
    [psobject] GetLDAPServerByID($ID) {
        $Resource = "ldapservers/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns information for matching user from ldap server by name
    [psobject] LookupUserInLDAPServerByName($Name, $User) {
        $Resource = "ldapservers/name/${Name}/user/${User}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns information for matching user from ldap server by id
    [psobject] LookupUserInLDAPServerByID($ID, $User) {
        $Resource = "ldapservers/id/${ID}/user/${User}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns information for matching group from ldap server by name
    [psobject] LookupGroupInLDAPServerByName($Name, $Group) {
        $Resource = "ldapservers/name/${Name}/group/${Group}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns information for matching group from ldap server by id
    [psobject] LookupGroupInLDAPServerByID($ID, $Group) {
        $Resource = "ldapservers/id/${ID}/group/${Group}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns information for user membership in group from ldap server by name
    [psobject] LookupMembershipInLDAPServerByName($Name, $Group, $User) {
        $Resource = "ldapservers/name/${Name}/group/${Group}/user/${User}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns information for user membership in group from ldap server by id
    [psobject] LookupMembershipInLDAPServerByID($ID, $Group, $User) {
        $Resource = "ldapservers/id/${ID}/group/${Group}/user/${User}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new ldapserver
    [psobject] CreateLDAPServer($Payload) {
        $Resource = "ldapservers/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ldapserver by name
    [psobject] UpdateLDAPServerByName($Payload) {
        $Name = $Payload.SelectSingleNode("//name").InnerText
        $Resource = "ldapservers/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates ldapserver by id
    [psobject] UpdateLDAPServerByID($Payload) {
        $ID = $Payload.SelectSingleNode("//id").InnerText
        $Resource = "ldapservers/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes ldapserver by name
    [psobject] DeleteLDAPServerByName($Name) {
        $Resource = "ldapservers/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes ldapserver by id
    [psobject] DeleteLDAPServerByID($ID) {
        $Resource = "ldapservers/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /licensedsoftware #####

    # Returns all licensedsoftware
    [psobject] GetLicensedSoftware() {
        $Resource = "licensedsoftware"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns licensedsoftware by name
    [psobject] GetLicensedSoftwareByName($Name) {
        $Resource = "licensedsoftware/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns licensedsoftware by id
    [psobject] GetLicensedSoftwareByID($ID) {
        $Resource = "licensedsoftware/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new licensedsoftware
    [psobject] CreateLicensedSoftware($Payload) {
        $Resource = "licensedsoftware/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates licensedsoftware by name
    [psobject] UpdateLicensedSoftwareByName($Name, $Payload) {
        $Resource = "licensedsoftware/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates licensedsoftware by name
    [psobject] UpdateLicensedSoftwareByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "licensedsoftware/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates licensedsoftware by id
    [psobject] UpdateLicensedSoftwareByID($ID, $Payload) {
        $Resource = "licensedsoftware/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates licensedsoftware by id
    [psobject] UpdateLicensedSoftwareByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "licensedsoftware/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes licensedsoftware by name
    [psobject] DeleteLicensedSoftwareByName($Name) {
        $Resource = "licensedsoftware/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes licensedsoftware by id
    [psobject] DeleteLicensedSoftwareByID($ID) {
        $Resource = "licensedsoftware/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /macapplications #####

    # Returns all macapplications
    [psobject] GetMacApplications() {
        $Resource = "macapplications"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns macapplication by name
    [psobject] GetMacApplicationByName($Name) {
        $Resource = "macapplications/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns macapplication by id
    [psobject] GetMacApplicationByID($ID) {
        $Resource = "macapplications/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns macapplication Subsets by name
    [psobject] GetMacApplicationSubsetByName($Name, $Subset) {
        $Resource = "macapplications/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns macapplication Subsets by id
    [psobject] GetMacApplicationSubsetByID($ID, $Subset) {
        $Resource = "macapplications/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new macapplication
    [psobject] CreateMacApplication($Payload) {
        $Resource = "macapplications/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates macapplication by name
    [psobject] UpdateMacApplicationByName($Name, $Payload) {
        $Resource = "macapplications/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates macapplication by name
    [psobject] UpdateMacApplicationByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "macapplications/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates macapplication by id
    [psobject] UpdateMacApplicationByID($ID, $Payload) {
        $Resource = "macapplications/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates macapplication by id
    [psobject] UpdateMacApplicationByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "macapplications/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes macapplication by name
    [psobject] DeleteMacApplicationByName($Name) {
        $Resource = "macapplications/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes macapplication by id
    [psobject] DeleteMacApplicationByID($ID) {
        $Resource = "macapplications/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /managedpreferenceprofiles #####

    # Returns all managedpreferenceprofiles
    [psobject] GetManagedPreferenceProfiles() {
        $Resource = "managedpreferenceprofiles"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns managedpreferenceprofile by name
    [psobject] GetManagedPreferenceProfileByName($Name) {
        $Resource = "managedpreferenceprofiles/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns managedpreferenceprofile by id
    [psobject] GetManagedPreferenceProfileByID($ID) {
        $Resource = "managedpreferenceprofiles/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns managedpreferenceprofile Subsets by name
    [psobject] GetManagedPreferenceProfileSubsetByName($Name, $Subset) {
        $Resource = "managedpreferenceprofiles/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns managedpreferenceprofile Subsets by id
    [psobject] GetManagedPreferenceProfileSubsetByID($ID, $Subset) {
        $Resource = "managedpreferenceprofiles/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new managedpreferenceprofile
    [psobject] CreateManagedPreferenceProfile($Payload) {
        $Resource = "managedpreferenceprofiles/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by name
    [psobject] UpdateManagedPreferenceProfileByName($Name, $Payload) {
        $Resource = "managedpreferenceprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by name
    [psobject] UpdateManagedPreferenceProfileByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "managedpreferenceprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by id
    [psobject] UpdateManagedPreferenceProfileByID($ID, $Payload) {
        $Resource = "managedpreferenceprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by id
    [psobject] UpdateManagedPreferenceProfileByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "managedpreferenceprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes managedpreferenceprofile by name
    [psobject] DeleteManagedPreferenceProfileByName($Name) {
        $Resource = "managedpreferenceprofiles/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes managedpreferenceprofile by id
    [psobject] DeleteManagedPreferenceProfileByID($ID) {
        $Resource = "managedpreferenceprofiles/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /mobiledeviceapplications #####

    # Returns all mobiledeviceapplications
    [psobject] GetMobileDeviceApplications() {
        $Resource = "mobiledeviceapplications"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceapplication by name
    [psobject] GetMobileDeviceApplicationByName($Name) {
        $Resource = "mobiledeviceapplications/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceapplication by id
    [psobject] GetMobileDeviceApplicationByID($ID) {
        $Resource = "mobiledeviceapplications/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceapplication by bundleid
    [psobject] GetMobileDeviceApplicationByBundleID($BundleID) {
        $Resource = "mobiledeviceapplications/bundleid/${BundleID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceapplication by bundleid and version
    [psobject] GetMobileDeviceApplicationByBundleIDAndVersion($BundleID, $Version) {
        $Resource = "mobiledeviceapplications/bundleid/${BundleID}/version/${Version}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceapplication Subsets by name
    [psobject] GetMobileDeviceApplicationSubsetByName($Name, $Subset) {
        $Resource = "mobiledeviceapplications/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceapplication Subsets by id
    [psobject] GetMobileDeviceApplicationSubsetByID($ID, $Subset) {
        $Resource = "mobiledeviceapplications/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobiledeviceapplication
    [psobject] CreateMobileDeviceApplication($Payload) {
        $Resource = "mobiledeviceapplications/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceapplication by name
    [psobject] UpdateMobileDeviceApplicationByName($Name, $Payload) {
        $Resource = "mobiledeviceapplications/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceapplication by name
    [psobject] UpdateMobileDeviceApplicationByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "mobiledeviceapplications/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceapplication by id
    [psobject] UpdateMobileDeviceApplicationByID($ID, $Payload) {
        $Resource = "mobiledeviceapplications/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceapplication by id
    [psobject] UpdateMobileDeviceApplicationByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "mobiledeviceapplications/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceapplication by bundleid
    [psobject] UpdateMobileDeviceApplicationByBundleID($BundleID, $Payload) {
        $Resource = "mobiledeviceapplications/bundleid/${BundleID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceapplication by bundleid and version
    [psobject] UpdateMobileDeviceApplicationByBundleID($BundleID, $Payload, $Version) {
        $Resource = "mobiledeviceapplications/bundleid/${BundleID}/version/${Version}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceapplication by bundleid
    [psobject] UpdateMobileDeviceApplicationByBundleID($Payload) {
        $BundleID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//bundleid").InnerText
        $Resource = "mobiledeviceapplications/bundleid/${BundleID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes mobiledeviceapplication by name
    [psobject] DeleteMobileDeviceApplicationByName($Name) {
        $Resource = "mobiledeviceapplications/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceapplication by id
    [psobject] DeleteMobileDeviceApplicationByID($ID) {
        $Resource = "mobiledeviceapplications/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceapplication by bundleid
    [psobject] DeleteMobileDeviceApplicationByBundleID($BundleID) {
        $Resource = "mobiledeviceapplications/bundleid/${BundleID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceapplication by bundleid and version
    [psobject] DeleteMobileDeviceApplicationByBundleID($BundleID, $Version) {
        $Resource = "mobiledeviceapplications/bundleid/${BundleID}/version/${Version}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /mobiledeviceenrollmentprofiles #####

    # Returns all mobiledeviceenrollmentprofiles
    [psobject] GetMobileDeviceEnrollmentProfiles() {
        $Resource = "mobiledeviceenrollmentprofiles"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceenrollmentprofile by name
    [psobject] GetMobileDeviceEnrollmentProfileByName($Name) {
        $Resource = "mobiledeviceenrollmentprofiles/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceenrollmentprofile by id
    [psobject] GetMobileDeviceEnrollmentProfileByID($ID) {
        $Resource = "mobiledeviceenrollmentprofiles/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceenrollmentprofile by invitation
    [psobject] GetMobileDeviceEnrollmentProfileByInvitation($Invitation) {
        $Resource = "mobiledeviceenrollmentprofiles/invitation/${Invitation}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceenrollmentprofile Subsets by name
    [psobject] GetMobileDeviceEnrollmentProfileSubsetByName($Name, $Subset) {
        $Resource = "mobiledeviceenrollmentprofiles/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceenrollmentprofile Subsets by id
    [psobject] GetMobileDeviceEnrollmentProfileSubsetByID($ID, $Subset) {
        $Resource = "mobiledeviceenrollmentprofiles/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceenrollmentprofile Subsets by invitation
    [psobject] GetMobileDeviceEnrollmentProfileSubsetByInvitation($Invitation, $Subset) {
        $Resource = "mobiledeviceenrollmentprofiles/invitation/${Invitation}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobiledeviceenrollmentprofile
    [psobject] CreateMobileDeviceEnrollmentProfile($Payload) {
        $Resource = "mobiledeviceenrollmentprofiles/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceenrollmentprofile by name
    [psobject] UpdateMobileDeviceEnrollmentProfileByName($Name, $Payload) {
        $Resource = "mobiledeviceenrollmentprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceenrollmentprofile by name
    [psobject] UpdateMobileDeviceEnrollmentProfileByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "mobiledeviceenrollmentprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceenrollmentprofile by id
    [psobject] UpdateMobileDeviceEnrollmentProfileByID($ID, $Payload) {
        $Resource = "mobiledeviceenrollmentprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceenrollmentprofile by id
    [psobject] UpdateMobileDeviceEnrollmentProfileByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "mobiledeviceenrollmentprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceenrollmentprofile by invitation
    [psobject] UpdateMobileDeviceEnrollmentProfileByInvitation($Invitation, $Payload) {
        $Resource = "mobiledeviceenrollmentprofiles/invitation/${Invitation}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceenrollmentprofile by invitation
    [psobject] UpdateMobileDeviceEnrollmentProfileByInvitation($Payload) {
        $Invitation = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//invitation").InnerText
        $Resource = "mobiledeviceenrollmentprofiles/invitation/${Invitation}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes mobiledeviceenrollmentprofile by name
    [psobject] DeleteMobileDeviceEnrollmentProfileByName($Name) {
        $Resource = "mobiledeviceenrollmentprofiles/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceenrollmentprofile by id
    [psobject] DeleteMobileDeviceEnrollmentProfileByID($ID) {
        $Resource = "mobiledeviceenrollmentprofiles/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceenrollmentprofile by invitation
    [psobject] DeleteMobileDeviceEnrollmentProfileByInvitation($Invitation) {
        $Resource = "mobiledeviceenrollmentprofiles/invitation/${Invitation}"
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
    [psobject] GetMobileDeviceGroupByID($ID) {
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

    # Updates mobile device group by name
    [psobject] UpdateMobileDeviceGroupByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates mobile device group by id
    [psobject] UpdateMobileDeviceGroupByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
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
    [psobject] UpdateStaticMobileDeviceGroupByName($GroupName, $DeviceIdentifier, $ArrayOf_MobileDevices, $Action) {
        $Resource = "mobiledevicegroups/name/${GroupName}"
        $Method = "PUT"

        switch ($DeviceIdentifier) {
            "serial" { $DeviceIdentifier = "serial_number" }
            "uuid" { $DeviceIdentifier = "udid" }
            "udid" { $DeviceIdentifier = "udid" }
            "id" { $DeviceIdentifier = "id" }
            "mac" { $DeviceIdentifier = "wifi_mac_address" }
            "name" { $DeviceIdentifier = "name" }
        }

        switch ($Action) {
            "add" { $Action = "additions" }
            "remove" { $Action = "deletions" }
            "delete" { $Action = "deletions" }
        }

        $Payload = $this._BuildXML("mobile_device_group")
        $Payload = $this._AddXMLElement($Payload, "//mobile_device_group", "mobile_device_${Action}")

        # Loop through each configuration item and create a node from it.
        ForEach ($Device in $ArrayOf_MobileDevices) {
            $Element = $this._BuildXML("mobile_device")
            $Element = $this._AddXMLText($Element, "mobile_device", "${DeviceIdentifier}", $Device)
            $Payload.DocumentElement.SelectSingleNode("//mobile_device_${Action}").AppendChild($Payload.ImportNode($Element.($Element.FirstChild.NextSibling.LocalName), $true)) | Out-Null
        }

        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates static mobile device group by id (uses mobile_device_additions and mobile_device_deletions)
    [psobject] UpdateStaticMobileDeviceGroupByID($GroupID, $DeviceIdentifier, $ArrayOf_MobileDevices, $Action) {
        $Resource = "mobiledevicegroups/id/${GroupID}"
        $Method = "PUT"

        switch ($DeviceIdentifier) {
            "serial" { $DeviceIdentifier = "serial_number" }
            "uuid" { $DeviceIdentifier = "udid" }
            "udid" { $DeviceIdentifier = "udid" }
            "id" { $DeviceIdentifier = "id" }
            "mac" { $DeviceIdentifier = "wifi_mac_address" }
            "name" { $DeviceIdentifier = "name" }
        }

        switch ($Action) {
            "add" { $Action = "additions" }
            "remove" { $Action = "deletions" }
            "delete" { $Action = "deletions" }
        }

        $Payload = $this._BuildXML("mobile_device_group")
        $Payload = $this._AddXMLElement($Payload, "//mobile_device_group", "mobile_device_${Action}")

        # Loop through each configuration item and create a node from it.
        ForEach ($Device in $ArrayOf_MobileDevices) {
            $Element = $this._BuildXML("mobile_device")
            $Element = $this._AddXMLText($Element, "mobile_device", "${DeviceIdentifier}", $Device)
            $Payload.DocumentElement.SelectSingleNode("//mobile_device_${Action}").AppendChild($Payload.ImportNode($Element.($Element.FirstChild.NextSibling.LocalName), $true)) | Out-Null
        }

        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /mobiledeviceinvitations #####

    # Returns all mobiledeviceinvitations
    [psobject] GetMobileDeviceInvitations() {
        $Resource = "mobiledeviceinvitations"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceinvitation by id
    [psobject] GetMobileDeviceInvitationByID($ID) {
        $Resource = "mobiledeviceinvitations/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceinvitation by invitation
    [psobject] GetMobileDeviceInvitationByInvitation($Invitation) {
        $Resource = "mobiledeviceinvitations/invitation/${Invitation}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobiledeviceinvitation
    [psobject] CreateMobileDeviceInvitation($Payload) {
        $Resource = "mobiledeviceinvitations/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceinvitation by id
    [psobject] UpdateMobileDeviceInvitationByID($ID, $Payload) {
        $Resource = "mobiledeviceinvitations/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceinvitation by id
    [psobject] UpdateMobileDeviceInvitationByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "mobiledeviceinvitations/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceinvitation by invitation
    [psobject] UpdateMobileDeviceInvitationByInvitation($Invitation, $Payload) {
        $Resource = "mobiledeviceinvitations/invitation/${Invitation}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceinvitation by invitation
    [psobject] UpdateMobileDeviceInvitationByInvitation($Payload) {
        $Invitation = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//invitation").InnerText
        $Resource = "mobiledeviceinvitations/invitation/${Invitation}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes mobiledeviceinvitation by id
    [psobject] DeleteMobileDeviceInvitationByID($ID) {
        $Resource = "mobiledeviceinvitations/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceinvitation by invitation
    [psobject] DeleteMobileDeviceInvitationByInvitation($Invitation) {
        $Resource = "mobiledeviceinvitations/invitation/${Invitation}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /mobiledeviceprovisioningprofiles #####

    # Returns all mobiledeviceprovisioningprofiles
    [psobject] GetMobileDeviceProvisioningProfiles() {
        $Resource = "mobiledeviceprovisioningprofiles"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceprovisioningprofile by name
    [psobject] GetMobileDeviceProvisioningProfileByName($Name) {
        $Resource = "mobiledeviceprovisioningprofiles/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceprovisioningprofile by id
    [psobject] GetMobileDeviceProvisioningProfileByID($ID) {
        $Resource = "mobiledeviceprovisioningprofiles/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceprovisioningprofile by uuid
    [psobject] GetMobileDeviceProvisioningProfileByUUID($UUID) {
        $Resource = "mobiledeviceprovisioningprofiles/uuid/${UUID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceprovisioningprofile Subsets by name
    [psobject] GetMobileDeviceProvisioningProfileSubsetByName($Name, $Subset) {
        $Resource = "mobiledeviceprovisioningprofiles/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceprovisioningprofile Subsets by id
    [psobject] GetMobileDeviceProvisioningProfileSubsetByID($ID, $Subset) {
        $Resource = "mobiledeviceprovisioningprofiles/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceprovisioningprofile Subsets by uuid
    [psobject] GetMobileDeviceProvisioningProfileSubsetByUUID($UUID, $Subset) {
        $Resource = "mobiledeviceprovisioningprofiles/uuid/${UUID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobiledeviceprovisioningprofile
    [psobject] CreateMobileDeviceProvisioningProfile($Payload) {
        $Resource = "mobiledeviceprovisioningprofiles/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceprovisioningprofile by name
    [psobject] UpdateMobileDeviceProvisioningProfileByName($Name, $Payload) {
        $Resource = "mobiledeviceprovisioningprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceprovisioningprofile by name
    [psobject] UpdateMobileDeviceProvisioningProfileByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "mobiledeviceprovisioningprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceprovisioningprofile by id
    [psobject] UpdateMobileDeviceProvisioningProfileByID($ID, $Payload) {
        $Resource = "mobiledeviceprovisioningprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceprovisioningprofile by id
    [psobject] UpdateMobileDeviceProvisioningProfileByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "mobiledeviceprovisioningprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceprovisioningprofile by uuid
    [psobject] UpdateMobileDeviceProvisioningProfileByUUID($UUID, $Payload) {
        $Resource = "mobiledeviceprovisioningprofiles/uuid/${UUID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceprovisioningprofile by uuid
    [psobject] UpdateMobileDeviceProvisioningProfileByUUID($Payload) {
        $UUID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//uuid").InnerText
        $Resource = "mobiledeviceprovisioningprofiles/uuid/${UUID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes mobiledeviceprovisioningprofile by name
    [psobject] DeleteMobileDeviceProvisioningProfileByName($Name) {
        $Resource = "mobiledeviceprovisioningprofiles/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceprovisioningprofile by id
    [psobject] DeleteMobileDeviceProvisioningProfileByID($ID) {
        $Resource = "mobiledeviceprovisioningprofiles/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceprovisioningprofile by uuid
    [psobject] DeleteMobileDeviceProvisioningProfileByUUID($UUID) {
        $Resource = "mobiledeviceprovisioningprofiles/uuid/${UUID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
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
    [psobject] GetMobileDeviceByID($ID) {
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
    [psobject] GetMobileDeviceSubsetByID($ID, $Subset) {
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

    # Updates mobile device by name
    [psobject] UpdateMobileDeviceByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates mobile device by id
    [psobject] UpdateMobileDeviceByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "mobiledevices/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by udid
    [psobject] UpdateMobileDeviceByUDID($UDID, $Payload) {
        $Resource = "mobiledevices/udid/${UDID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by udid
    [psobject] UpdateMobileDeviceByUDID($Payload) {
        $UDID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//udid").InnerText
        $Resource = "mobiledevices/udid/${UDID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by serialnumber
    [psobject] UpdateMobileDeviceBySerialNumber($SerialNumber, $Payload) {
        $Resource = "mobiledevices/serialnumber/${SerialNumber}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by serialnumber
    [psobject] UpdateMobileDeviceBySerialNumber($Payload) {
        $SerialNumber = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//serial_number").InnerText
        $Resource = "mobiledevices/serialnumber/${SerialNumber}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by macaddress
    [psobject] UpdateMobileDeviceByMACAddress($MACAddress, $Payload) {
        $Resource = "mobiledevices/macaddress/${MACAddress}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device by macaddress
    [psobject] UpdateMobileDeviceByMACAddress($Payload) {
        $MACAddress = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//wifi_mac_address").InnerText
        $Resource = "mobiledevices/macaddress/${MACAddress}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
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


    ##### Resource Path:  /mobiledeviceconfigurationprofiles #####

    # Returns all mobile device configuration profiles
    [psobject] GetMobileDeviceConfigurationProfiles() {
        $Resource = "mobiledeviceconfigurationprofiles"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device configuration profile by name
    [psobject] GetMobileDeviceConfigurationProfileByName($Name) {
        $Resource = "mobiledeviceconfigurationprofiles/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device configuration profile by id
    [psobject] GetMobileDeviceConfigurationProfileByID($ID) {
        $Resource = "mobiledeviceconfigurationprofiles/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobile device configuration profile
    [psobject] CreateMobileDeviceConfigurationProfile($Payload) {
        $Resource = "mobiledeviceconfigurationprofiles/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device configuration profile by name
    [psobject] UpdateMobileDeviceConfigurationProfileByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "mobiledeviceconfigurationprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device configuration profile by name
    [psobject] UpdateMobileDeviceConfigurationProfileByName($Name, $Payload) {
        $Resource = "mobiledeviceconfigurationprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device configuration profile by id
    [psobject] UpdateMobileDeviceConfigurationProfileByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "mobiledeviceconfigurationprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobile device configuration profile by id
    [psobject] UpdateMobileDeviceConfigurationProfileByID($ID, $Payload) {
        $Resource = "mobiledeviceconfigurationprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes mobile device configuration profile by name
    [psobject] DeleteMobileDeviceConfigurationProfileByName($Name) {
        $Resource = "mobiledeviceconfigurationprofiles/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobile device configuration profile by id
    [psobject] DeleteMobileDeviceConfigurationProfileByID($ID) {
        $Resource = "mobiledeviceconfigurationprofiles/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device configuration profile Subsets by name
    [psobject] GetMobileDeviceConfigurationProfileSubsetByName($Name, $Subset) {
        $Resource = "mobiledeviceconfigurationprofiles/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobile device configuration profile Subsets by id
    [psobject] GetMobileDeviceConfigurationProfileSubsetByID($ID, $Subset) {
        $Resource = "mobiledeviceconfigurationprofiles/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /mobiledeviceextensionattributes #####

    # Returns all mobiledeviceextensionattributes
    [psobject] GetMobileDeviceExtensionAttributes() {
        $Resource = "mobiledeviceextensionattributes"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceextensionattribute by name
    [psobject] GetMobileDeviceExtensionAttributeByName($Name) {
        $Resource = "mobiledeviceextensionattributes/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns mobiledeviceextensionattribute by id
    [psobject] GetMobileDeviceExtensionAttributeByID($ID) {
        $Resource = "mobiledeviceextensionattributes/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new mobiledeviceextensionattribute
    [psobject] CreateMobileDeviceExtensionAttribute($Payload) {
        $Resource = "mobiledeviceextensionattributes/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceextensionattribute by name
    [psobject] UpdateMobileDeviceExtensionAttributeByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "mobiledeviceextensionattributes/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates mobiledeviceextensionattribute by id
    [psobject] UpdateMobileDeviceExtensionAttributeByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "mobiledeviceextensionattributes/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes mobiledeviceextensionattribute by name
    [psobject] DeleteMobileDeviceExtensionAttributeByName($Name) {
        $Resource = "mobiledeviceextensionattributes/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes mobiledeviceextensionattribute by id
    [psobject] DeleteMobileDeviceExtensionAttributeByID($ID) {
        $Resource = "mobiledeviceextensionattributes/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /networksegments #####

    # Returns all networksegments
    [psobject] GetNetworkSegments() {
        $Resource = "networksegments"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns networksegments by name
    [psobject] GetNetworkSegmentByName($Name) {
        $Resource = "networksegments/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns networksegments by id
    [psobject] GetNetworkSegmentByID($ID) {
        $Resource = "networksegments/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new networksegments
    [psobject] CreateNetworkSegment($Payload) {
        $Resource = "networksegments/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates networksegments by name
    [psobject] UpdateNetworkSegmentByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "networksegments/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates networksegments by id
    [psobject] UpdateNetworkSegmentByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "networksegments/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes networksegments by name
    [psobject] DeleteNetworkSegmentByName($Name) {
        $Resource = "networksegments/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes networksegments by id
    [psobject] DeleteNetworkSegmentByID($ID) {
        $Resource = "networksegments/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /osxconfigurationprofiles #####

    # Returns all computer configuration profiles
    [psobject] GetComputerConfigurationProfiles() {
        $Resource = "osxconfigurationprofiles"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer configuration profile by name
    [psobject] GetComputerConfigurationProfileByName($Name) {
        $Resource = "osxconfigurationprofiles/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer configuration profile by id
    [psobject] GetComputerConfigurationProfileByID($ID) {
        $Resource = "osxconfigurationprofiles/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new computer configuration profile
    [psobject] CreateComputerConfigurationProfile($Payload) {
        $Resource = "osxconfigurationprofiles/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer configuration profile by name
    [psobject] UpdateComputerConfigurationProfileByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "osxconfigurationprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer configuration profile by name
    [psobject] UpdateComputerConfigurationProfileByName($Name, $Payload) {
        $Resource = "osxconfigurationprofiles/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer configuration profile by id
    [psobject] UpdateComputerConfigurationProfileByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "osxconfigurationprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates computer configuration profile by id
    [psobject] UpdateComputerConfigurationProfileByID($ID, $Payload) {
        $Resource = "osxconfigurationprofiles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes computer configuration profile by name
    [psobject] DeleteComputerConfigurationProfileByName($Name) {
        $Resource = "osxconfigurationprofiles/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes computer configuration profile by id
    [psobject] DeleteComputerConfigurationProfileByID($ID) {
        $Resource = "osxconfigurationprofiles/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer configuration profile Subsets by name
    [psobject] GetComputerConfigurationProfileSubsetByName($Name, $Subset) {
        $Resource = "osxconfigurationprofiles/name/${Name}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns computer configuration profile Subsets by id
    [psobject] GetComputerConfigurationProfileSubsetByID($ID, $Subset) {
        $Resource = "osxconfigurationprofiles/id/${ID}/subset/${Subset}"
        $Method = "GET"
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
    [psobject] GetPackageByID($ID) {
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

    # Updates package by name
    [psobject] UpdatePackageByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
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

    # Updates package by id
    [psobject] UpdatePackageByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
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


    ##### Resource Path:  /patchsoftwaretitles #####

    # Returns all patchsoftwaretitles
    [psobject] GetPatchSoftwareTitles() {
        $Resource = "patchsoftwaretitles"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns patchsoftwaretitle by id
    [psobject] GetPatchSoftwareTitleByID($ID) {
        $Resource = "patchsoftwaretitles/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new patchsoftwaretitle
    [psobject] CreatePatchSoftwareTitle($Payload) {
        $Resource = "patchsoftwaretitles/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates patchsoftwaretitle by id
    [psobject] UpdatePatchSoftwareTitleByID($ID, $Payload) {
        $Resource = "patchsoftwaretitles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates patchsoftwaretitle by id
    [psobject] UpdatePatchSoftwareTitleByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "patchsoftwaretitles/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes patchsoftwaretitle by id
    [psobject] DeletePatchSoftwareTitleByID($ID) {
        $Resource = "patchsoftwaretitles/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # This endpoint doesn't seem to work; thinking the documentation has a typo...
    # # Deletes patchsoftwaretitle by name
    # [psobject] DeletePatchSoftwareTitleByName($Name) {
    #     $Resource = "patchsoftwaretitles/name/${Name}"
    #     $Method = "DELETE"
    #     $Results = $this.InvokeAPI($Resource, $Method)
    #     return $Results
    # }


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
    [psobject] GetPolicyByID($ID) {
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
    [psobject] GetPolicySubsetByID($ID, $Subset) {
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

    # Updates policy by name
    [psobject] UpdatePolicyByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//general/name").InnerText
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

    # Updates policy by id
    [psobject] UpdatePolicyByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//general/id").InnerText
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
    [psobject] GetPrinterByID($ID) {
        $Resource = "printers/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new printer
    [psobject] CreatePrinter($Payload) {
        $Resource = "printers/id/0"
        $Method = "POST"
        $Payload = $this.BuildXMLNode("printer",$Payload)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates printer by name
    [psobject] UpdatePrinterByName($Name, $Payload) {
        $Resource = "printers/name/${Name}"
        $Method = "PUT"
        $Payload = $this.BuildXMLNode("printer",$Payload)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates printer by name
    [psobject] UpdatePrinterByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "printers/name/${Name}"
        $Method = "PUT"
        $Payload = $this.BuildXMLNode("printer",$Payload)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates printer by id
    [psobject] UpdatePrinterByID($ID, $Payload) {
        $Resource = "printers/id/${ID}"
        $Method = "PUT"
        $Payload = $this.BuildXMLNode("printer",$Payload)
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates printer by id
    [psobject] UpdatePrinterByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "printers/id/${ID}"
        $Method = "PUT"
        $Payload = $this.BuildXMLNode("printer",$Payload)
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


    ##### Resource Path:  /restrictedsoftware #####

    # Returns all restrictedsoftware
    [psobject] GetRestrictedSoftware() {
        $Resource = "restrictedsoftware"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns managedpreferenceprofile by name
    [psobject] GetRestrictedSoftwareByName($Name) {
        $Resource = "restrictedsoftware/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns managedpreferenceprofile by id
    [psobject] GetRestrictedSoftwareByID($ID) {
        $Resource = "restrictedsoftware/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new managedpreferenceprofile
    [psobject] CreateRestrictedSoftware($Payload) {
        $Resource = "restrictedsoftware/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by name
    [psobject] UpdateRestrictedSoftwareByName($Name, $Payload) {
        $Resource = "restrictedsoftware/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by name
    [psobject] UpdateRestrictedSoftwareByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "restrictedsoftware/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by id
    [psobject] UpdateRestrictedSoftwareByID($ID, $Payload) {
        $Resource = "restrictedsoftware/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates managedpreferenceprofile by id
    [psobject] UpdateRestrictedSoftwareByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "restrictedsoftware/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes managedpreferenceprofile by name
    [psobject] DeleteRestrictedSoftwareByName($Name) {
        $Resource = "restrictedsoftware/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes managedpreferenceprofile by id
    [psobject] DeleteRestrictedSoftwareByID($ID) {
        $Resource = "restrictedsoftware/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /scripts #####

    # Returns all scripts
    [psobject] GetScripts() {
        $Resource = "scripts"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns script by name
    [psobject] GetScriptByName($Name) {
        $Resource = "scripts/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns script by id
    [psobject] GetScriptByID($ID) {
        $Resource = "scripts/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new script
    [psobject] CreateScript($Payload) {
        $Resource = "scripts/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates script by name
    [psobject] UpdateScriptByName($Name, $Payload) {
        $Resource = "scripts/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates script by name
    [psobject] UpdateScriptByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "scripts/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates script by id
    [psobject] UpdateScriptByID($ID, $Payload) {
        $Resource = "scripts/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates script by id
    [psobject] UpdateScriptByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "scripts/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes script by name
    [psobject] DeleteScriptByName($Name) {
        $Resource = "scripts/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes script by id
    [psobject] DeleteScriptByID($ID) {
        $Resource = "scripts/id/${ID}"
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
    [psobject] GetSiteByID($ID) {
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
        $Results = $this._DeleteSiteHelper($Name)
        return $Results
    }

    # Deletes site by id
    [psobject] DeleteSiteByID($ID) {
        $Resource = "sites/id/${ID}"
        $Method = "GET"
        $Site = $this.InvokeAPI($Resource, $Method)
        $Name = $Site.SelectSingleName("//name")
        $Results = $this._DeleteSiteHelper($Name)

        return $Results
    }

    [psobject] _DeleteSiteHelper($Name) {
        $Resource = "sites/name/${Name}"
        $Method = "DELETE"

        # Collect all objects that are deleted...
        $DeletedItems = @()

        # Frist, we'll have to manually search for items that may be in a Site to delete them.
        # Delete Groups
        $allItems = $this.GetAccounts()
        if ( ($allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)")).Count -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                if ( $eachItem.SelectSingleNode("./site/name").InnerText -eq $Name ) {
                    $this.DeleteAccountByGroupID($eachItem.SelectSingleNode("./id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$(${eachItem}.name)" } )
                }
            }
        }

        ### All Advanced Searches are commented out as the process to "lookup" the configuration of an advanced search, also performs the search...  I think it's best not to run every search...so these will need to be a manual check/delete in the JPS.

        # # Delete Advanced Computer Searches
        # $allItems = $this.GetAdvancedComputerSearches()
        # if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
        #     ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
        #         $detailedItem = $this.GetAdvancedComputerSearchByID($eachItem.id)
        #         if ( $detailedItem.SelectSingleNode("./site/name").InnerText -eq $Name ) {
        #             $this.DeleteAdvancedComputerSearchByID($detailedItem.SelectSingleNode("//id").InnerText)
        #             $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
        #         }
        #     }
        # }
        # # Delete Advanced Mobile Device Searches
        # $allItems = $this.GetAdvancedMobileDeviceSearches()
        # if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
        #     ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
        #         $detailedItem = $this.GetAdvancedMobileDeviceSearchByID($eachItem.id)
        #         if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
        #             $this.DeleteAdvancedMobileDeviceSearchByID($detailedItem.SelectSingleNode("//id").InnerText)
        #             $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
        #         }
        #     }
        # }
        # # Delete Advanced User Searches
        # $allItems = $this.GetAdvancedUserSearches()
        # if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
        #     ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
        #         $detailedItem = $this.GetAdvancedUserSearchByID($eachItem.id)
        #         if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
        #             $this.DeleteAdvancedUserSearchByID($detailedItem.SelectSingleNode("//id").InnerText)
        #             $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
        #         }
        #     }
        # }
        # Delete Classes
        $allItems = $this.GetClasses()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetClassByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteClassByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete Computer Configurations
        $allItems = $this.GetComputerConfigurations()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetComputerConfigurationByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteComputerConfigurationByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete Managed Preference Profiles
        $allItems = $this.GetManagedPreferenceProfiles()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetManagedPreferenceProfileByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteManagedPreferenceProfileByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete Computer Invitations
        $allItems = $this.GetComputerInvitations()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetComputerInvitationByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteComputerInvitationByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete Licensed Software
        $allItems = $this.GetLicensedSoftware()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//licensed_software/licensed_software") ) {
                $detailedItem = $this.GetLicensedSoftwareByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteLicensedSoftwareByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete Mobile Device Enrollment Profiles
        $allItems = $this.GetMobileDeviceEnrollmentProfiles()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetMobileDeviceEnrollmentProfileByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteMobileDeviceEnrollmentProfileByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete Mobile Device Provisioning Profiles
        $allItems = $this.GetMobileDeviceProvisioningProfiles()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetMobileDeviceProvisioningProfileByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteMobileDeviceProvisioningProfileByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete Mobile Device Invitations
        $allItems = $this.GetMobileDeviceInvitations()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetMobileDeviceInvitationByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteMobileDeviceInvitationByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete BYO Profiles
        $allItems = $this.GetBYOProfiles()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetBYOProfileByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteBYOProfileByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }
        # Delete VPP Accounts
        $allItems = $this.GetVPPAccounts()
        if ( $allItems.SelectSingleNode("//size").InnerText -ne 0 ) {
            ForEach ( $eachItem in $allItems.SelectNodes("//$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)") ) {
                $detailedItem = $this.GetVPPAccountByID($eachItem.id)
                if ( $detailedItem.SelectSingleNode("//site/name").InnerText -eq $Name ) {
                    $this.DeleteVPPAccountByID($detailedItem.SelectSingleNode("//id").InnerText)
                    $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="$($allItems.FirstChild.NextSibling.FirstChild.NextSibling.LocalName)"; name="$($detailedItem.SelectSingleNode("//name").InnerText)" } )
                }
            }
        }

        # Try deleting the Site now...
        $Results = $this.InvokeAPI($Resource, $Method)

        # If the delete failed because items exist in the Site, delete those items.
        if ( $Results -ne $null ) {

            $allPolicies = $this.GetPolicies()
            $allComputerConfigurationProfiles = $this.GetComputerConfigurationProfiles()
            $allRestrictedSoftware = $this.GetRestrictedSoftware()
            $allComputerGroups = $this.GetComputerGroups()
            $allMobileDeviceGroups = $this.GetMobileDeviceGroups()
            $allMobileDeviceConfigurationProfiles = $this.GetMobileDeviceConfigurationProfiles()
            $allMobileDeviceApplications = $this.GetMobileDeviceApplications()
            $alleBooks = $this.GeteBooks()
            $allUserGroups = $this.GetUserGroups()
            $allMacApplications = $this.GetMacApplications()
            $allVPPAssignments = $this.GetVPPAssignments()
            $allVPPInvitations = $this.GetVPPInvitations()

            (($Results -split ':',2)[1]).Split(",") | ForEach-Object {
                $ObjectType = $_.Split(":")[0]
                $ObjectName = $_.Split(":")[1]

                switch ( $ObjectType ) {
                    "Policy" {
                        $allPolicies.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetPolicyByID($_.id)

                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    # Write-host "Delete:  $($_.id) - $($_.name)"
                                    $this.DeletePolicyByID($_.id)
                                }
                            }
                        }
                    }
                    "OS X Configuration Profile" {
                        $allComputerConfigurationProfiles.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetComputerConfigurationProfileByID($_.id)

                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteComputerConfigurationProfileByID($_.id)
                                }
                            }
                        }
                    }
                    "Restricted Software" {
                        $allRestrictedSoftware.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetRestrictedSoftwareByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteRestrictedSoftwareByID($_.id)
                                }
                            }
                        }
                    }
                    "Smart Computer Group" {
                        $allComputerGroups.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetComputerGroupByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    # Write-host "Delete:  $($_.id) - $($_.name)"
                                    $this.DeleteComputerGroupByID($_.id)
                                }
                            }
                        }
                    }
                    "Static Computer Group" {
                        $allComputerGroups.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {

                                $Object = $this.GetComputerGroupByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteComputerGroupByID($_.id)
                                }
                            }
                        }
                    }
                    "Smart Mobile Device Group" {
                        $allMobileDeviceGroups.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetMobileDeviceGroupByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    # Write-host "Delete:  $($_.id) - $($_.name)"
                                    $this.DeleteMobileDeviceGroupByID($_.id)
                                }
                            }
                        }
                    }
                    "Static Mobile Device Group" {
                        $allMobileDeviceGroups.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetMobileDeviceGroupByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteMobileDeviceGroupByID($_.id)
                                }
                            }
                        }
                    }
                    "Mobile Device Configuration Profile" {
                        $allMobileDeviceConfigurationProfiles.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetMobileDeviceConfigurationProfileByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteMobileDeviceConfigurationProfileByID($_.id)
                                }
                            }
                        }
                    }
                    "Mobile Device Application" {
                        $allMobileDeviceApplications.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetMobileDeviceApplicationByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteMobileDeviceApplicationByID($_.id)
                                }
                            }
                        }
                    }
                    "eBook" {
                        $alleBooks.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {

                                $Object = $this.GeteBookByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteeBookByID($_.id)
                                }
                            }
                        }
                    }
                    "Smart User Group" {
                        $allUserGroups.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetUserGroupByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteUserGroupByID($_.id)
                                }
                            }
                        }
                    }
                    "Static User Group" {
                        $allUserGroups.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetUserGroupByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteUserGroupByID($_.id)
                                }
                            }
                        }
                    }
                    "Patch Management Software Title" {
                        Write-Host "You will need to manually delete Patch Object:  ${ObjectName}"
                    }
                    "Mac Application" {
                        $allMacApplications.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetMacApplicationByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteMacApplicationByID($_.id)
                                }
                            }
                        }
                    }
                    "VPP Assignment" {
                        $allVPPAssignments.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetVPPAssignmentByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteVPPAssignmentByID($_.id)
                                }
                            }
                        }
                    }
                    "VPP Invitation" {
                        $allVPPInvitations.SelectNodes("/child::*/descendant::*") | ForEach-Object {
                            if ( $ObjectName -eq "$($_.name)" ) {
                                $Object = $this.GetVPPInvitationByID($_.id)
 
                                if ( $Object.SelectNodes("//site/name").InnerText -eq $Name ) {
                                    $this.DeleteVPPInvitationByID($_.id)
                                }
                            }
                        }
                    }
                    Default {
                        Write-host "Something I don't know how to delete is in this Site."
                    }
                }

                $DeletedItems += New-Object PSObject -Property ([ordered]@{ Type="${ObjectType}"; name="$(${ObjectName})" } )
            }

            # Try deleting the Site again
            $Results = $this.InvokeAPI($Resource, $Method)
        }

        return "Deleted (or attempted) the following items:",$DeletedItems, $Results
    }


    ##### Resource Path:  /smtpserver #####

    # Returns all smtpserver
    [psobject] GetSMTPServer() {
        $Resource = "smtpserver"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Updates smtpserver
    [psobject] UpdateSMTPServer($Payload) {
        $Resource = "smtpserver"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }


    ##### Resource Path:  /softwareupdateservers #####

    # Returns all softwareupdateservers
    [psobject] GetSoftwareUpdateServers() {
        $Resource = "softwareupdateservers"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns softwareupdateservers by name
    [psobject] GetSoftwareUpdateServerByName($Name) {
        $Resource = "softwareupdateservers/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns softwareupdateservers by id
    [psobject] GetSoftwareUpdateServerByID($ID) {
        $Resource = "softwareupdateservers/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new softwareupdateservers
    [psobject] CreateSoftwareUpdateServer($Payload) {
        $Resource = "softwareupdateservers/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates softwareupdateservers by name
    [psobject] UpdateSoftwareUpdateServerByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "softwareupdateservers/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates softwareupdateservers by id
    [psobject] UpdateSoftwareUpdateServerByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "softwareupdateservers/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes softwareupdateservers by name
    [psobject] DeleteSoftwareUpdateServerByName($Name) {
        $Resource = "softwareupdateservers/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes softwareupdateservers by id
    [psobject] DeleteSoftwareUpdateServerByID($ID) {
        $Resource = "softwareupdateservers/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /userextensionattributes #####

    # Returns all userextensionattributes
    [psobject] GetUserExtensionAttributes() {
        $Resource = "userextensionattributes"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns userextensionattribute by name
    [psobject] GetUserExtensionAttributeByName($Name) {
        $Resource = "userextensionattributes/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns userextensionattribute by id
    [psobject] GetUserExtensionAttributeByID($ID) {
        $Resource = "userextensionattributes/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new userextensionattribute
    [psobject] CreateUserExtensionAttribute($Payload) {
        $Resource = "userextensionattributes/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates userextensionattribute by name
    [psobject] UpdateUserExtensionAttributeByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "userextensionattributes/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates userextensionattribute by id
    [psobject] UpdateUserExtensionAttributeByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "userextensionattributes/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes userextensionattribute by name
    [psobject] DeleteUserExtensionAttributeByName($Name) {
        $Resource = "userextensionattributes/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes userextensionattribute by id
    [psobject] DeleteUserExtensionAttributeByID($ID) {
        $Resource = "userextensionattributes/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /usergroups #####

    # Returns all usergroups
    [psobject] GetUserGroups() {
        $Resource = "usergroups"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns usergroup by name
    [psobject] GetUserGroupByName($Name) {
        $Resource = "usergroups/name/${Name}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns usergroup by id
    [psobject] GetUserGroupByID($ID) {
        $Resource = "usergroups/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new usergroup
    [psobject] CreateUserGroup($Payload) {
        $Resource = "usergroups/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates usergroup by name
    [psobject] UpdateUserGroupByName($Name, $Payload) {
        $Resource = "usergroups/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates usergroup by name
    [psobject] UpdateUserGroupByName($Payload) {
        $Name = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//name").InnerText
        $Resource = "usergroups/name/${Name}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates usergroup by id
    [psobject] UpdateUserGroupByID($ID, $Payload) {
        $Resource = "usergroups/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates usergroup by id
    [psobject] UpdateUserGroupByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "usergroups/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes usergroup by name
    [psobject] DeleteUserGroupByName($Name) {
        $Resource = "usergroups/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes usergroup by id
    [psobject] DeleteUserGroupByID($ID) {
        $Resource = "usergroups/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /vppaccounts #####

    # Returns all vppaccounts
    [psobject] GetVPPAccounts() {
        $Resource = "vppaccounts"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns vppaccount by id
    [psobject] GetVPPAccountByID($ID) {
        $Resource = "vppaccounts/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new vppaccount
    [psobject] CreateVPPAccount($Payload) {
        $Resource = "vppaccounts/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates vppaccount by id
    [psobject] UpdateVPPAccountByID($ID, $Payload) {
        $Resource = "vppaccounts/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates vppaccount by id
    [psobject] UpdateVPPAccountByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "vppaccounts/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes vppaccount by id
    [psobject] DeleteVPPAccountByID($ID) {
        $Resource = "vppaccounts/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /vppassignments #####

    # Returns all vppassignments
    [psobject] GetVPPAssignments() {
        $Resource = "vppassignments"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns vppassignment by id
    [psobject] GetVPPAssignmentByID($ID) {
        $Resource = "vppassignments/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new vppassignment
    [psobject] CreateVPPAssignment($Payload) {
        $Resource = "vppassignments/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates vppassignment by id
    [psobject] UpdateVPPAssignmentByID($ID, $Payload) {
        $Resource = "vppassignments/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates vppassignment by id
    [psobject] UpdateVPPAssignmentByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "vppassignments/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

     # Deletes vppassignment by id
    [psobject] DeleteVPPAssignmentByID($ID) {
        $Resource = "vppassignments/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes vppassignment by name
    # Not 100% sure this resourse/endpoint works/is valid -- will update when tested.
    [psobject] DeleteVPPAssignmentByName($Name) {
        $Resource = "vppassignments/Name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  /vppinvitations #####

    # Returns all vppinvitations
    [psobject] GetVPPInvitations() {
        $Resource = "vppinvitations"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns vppinvitation by id
    [psobject] GetVPPInvitationByID($ID) {
        $Resource = "vppinvitations/id/${ID}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Returns vppinvitation Subsets by id
    [psobject] GetVPPInvitationSubsetByID($ID, $Subset) {
        $Resource = "vppinvitations/id/${ID}/subset/${Subset}"
        $Method = "GET"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Creates new vppinvitation
    [psobject] CreateVPPInvitation($Payload) {
        $Resource = "vppinvitations/id/0"
        $Method = "POST"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates vppinvitation by id
    [psobject] UpdateVPPInvitationByID($ID, $Payload) {
        $Resource = "vppinvitations/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Updates vppinvitation by id
    [psobject] UpdateVPPInvitationByID($Payload) {
        $ID = $Payload.SelectSingleNode("$($Payload.FirstChild.NextSibling.LocalName)//id").InnerText
        $Resource = "vppinvitations/id/${ID}"
        $Method = "PUT"
        $Results = $this.InvokeAPI($Resource, $Method, $Payload)
        return $Results
    }

    # Deletes vppinvitation by id
    [psobject] DeleteVPPInvitationByID($ID) {
        $Resource = "vppinvitations/id/${ID}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }

    # Deletes vppinvitation by name
    # Not 100% sure this resourse/endpoint works/is valid -- will update when tested.
    [psobject] DeleteVPPInvitationByName($Name) {
        $Resource = "vppinvitations/name/${Name}"
        $Method = "DELETE"
        $Results = $this.InvokeAPI($Resource, $Method)
        return $Results
    }


    ##### Resource Path:  / #####


}