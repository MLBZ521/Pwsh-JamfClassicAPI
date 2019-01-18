Class Buildings {
 
    [ValidatePattern("^[a-zA-Z0-9]+$")]
    [string]$Name
    [string]$Action
    #hidden [string]$Uri
    #hidden [XML]$Xml

    #Constructors
    Buildings([String]$Name,$Action) {
        #Setting properties
        $this.Name = $Name
        $this.Parameters = [Buildings]::BuildURI($Name,$Action)
        $this.Method = $this.Parameters.Method
        $this.Uri = $this.Parameters.Path
        #$this.Xml = [Buildings]::CreateXML($Name)
    }
 
    #Methods
    # [string]static CreateXML([string]$Name) {
    #     [xml]$Payload = "<?xml version='1.0' encoding='UTF-8'?><building><name>${Name}</name></building>"
    #     return $Payload
    # }

    [string]static BuildURI([string]$Name,[string]$Action) {
        $Parameters = $global:APIResources.Methods  | Where-Object { $_.Nickname -eq $Action } | Select-Object Path, Method        
        $Parameters.Path = $( $Parameters.Path | Where-Object { $_ -match "[{]\w+[}]" } ) -replace "[{]\w+[}]", $Name
        return $Parameters
    }

    [Buildings]Create() {
        Invoke-JamfClassicAPI -Resource $this.Uri -Method $this.Method -Caller "Class"
        return $this
    }
}
