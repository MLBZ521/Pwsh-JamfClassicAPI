#Requires -Version 4.0

[CmdletBinding()]
Param()

Write-Verbose "Importing all public functions in:  ${PSScriptRoot}"

foreach ( $Folder in @( 'Private', 'Public' ) ) {

    $Root = Join-Path -Path $PSScriptRoot -ChildPath $Folder
    if ( Test-Path -Path $Root ) {
        Write-Verbose "Processing files in:  ${Root}"

        $Files = Get-ChildItem -Path $Root -Filter *.ps1 -Recurse

        # Dot source each file.
        $Files | ForEach-Object { Write-Verbose $_.basename; . $PSItem.FullName }
    }
}

Export-ModuleMember -Function ( Get-ChildItem -Path "${PSScriptRoot}\Public\*.ps1" ).BaseName