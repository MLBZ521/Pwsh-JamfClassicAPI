####################################################################################################
# Dot source the PwshJamf Class so it's available.
. ./PS-JamfClassicAPI/JamfClassicAPI/Public/Classes/PwshJamf.ps1

# Setup sessions
$JamfProd = [PwshJamf]::new($(Get-Credential))
$JamfProd.Server = "https://production.jps.company.com:8443/"
$JamfProd.Headers['Accept'] = "application/xml"

$JamfDev = [PwshJamf]::new($(Get-Credential))
$JamfDev.Server = "https://dev.jps.company.com:8443/"
$JamfDev.Headers['Accept'] = "application/xml"


####################################################################################################
# Sites Examples

# Define an array of Site Names and then create them
$Sites = "Site A", "Site B", "Site C", "Testing", "QA", "dev"
$Sites | ForEach-Object { $JamfDev.CreateSite($_) }

# Get the id of a specific Site
$ProdSites = $JamfProd.GetSites()
$devID = $ProdSites.sites.site | Where-Object { $_.name -eq "dev" } | Select-Object id


####################################################################################################
# Jamf Pro Accounts and Groups Examples

# Get all accounts
$prod_AllAccounts = $JamfProd.GetAccounts()

# Get only the groups that have "dev" in them
$prod_DevGroups = $prod_AllAccounts.accounts.groups.group | Where-Object { $_.name -match "dev" }

# Remove a specific group
$prod_DevGroups = $prod_DevGroups | Where-Object { $_.name -notmatch "Site A.dev" }

# For each group, get the groups configuration, change some of it's configuration, and then create in the dev environment
$prod_DevGroups | ForEach-Object { $group = $JamfProd.GetAccountByGroupname($_.name)
    $group.group.site.name = "$(${group}.group.site.name).dev" # Change the Site Name
    $group.group.RemoveChild($group.group.site.id) # Remove the Site ID
    $group.group.ldap_server.id = "3" # Change teh ldap_server ID
    $JamfDev.CreateAccountGroup($group)
}


####################################################################################################
# Working with Categories

# Get all Categories
$devCategories = $JamfDev.GetCategories()
$prodCategories = $JamfProd.GetCategories()

# Create a Category and set priority
$JamfProd.CreateCategory("Maintenance", 10)

# Update a Category
$JamfDev.UpdateCategoryByName("dev","Development")

# Delete a Category
$JamfDev.DeleteCategoryByName("32bit Software")

# Select specific categories
$delete_devCategories = $devCategories.categories.category | Where-Object { $_.name -match "Testing" -or $_.name -match "Unknown" -or $_.name -match "Workflow A" }

# Delete categories
$delete_devCategories | ForEach-Object { $JamfDev.DeleteCategoryByID($_.id) }

# Compare Categories
Compare-Object $prodCategories.categories.category.name $devCategories.categories.category.name 


####################################################################################################
# Working with Computers

$computerObjects = New-Object System.Collections.Arraylist
$siteAComputers = New-Object System.Collections.Arraylist

$deviceIDArray=7, 69, 94, 190, 667, 1859, 1917, 2139, 2896, 3421, 4843, 5100, 5638, 6132, 6399

ForEach ( $id in $deviceIDArray ) {
    $record = $JamfProd.GetComputerById($id)
    $computerObjects.add($record) | Out-Null
}

$computerObjects.Count

ForEach ( $computer in $computerObjects) {
    if ( $computer.computer.general.site.name -match "Site A" ) {
        $siteAComputers.add($computer.computer.general.serial_number) | Out-Null
    }
}

$siteAComputers.Count


####################################################################################################
# Working with Groups

$add_deviceIDArray=7, 69, 190, 667, 1859, 2896, 4843, 5638, 6132
$remove_deviceIDArray=94, 1917, 2139, 3421, 5100, 6399

$JamfProd.UpdateStaticMobileDeviceGroupByName("AV iPads", "id", $add_deviceIDArray, "add")
$JamfProd.UpdateStaticMobileDeviceGroupByName("AV iPads", "id", $remove_deviceIDArray, "remove")


####################################################################################################
# Copy a single extension attribute from Dev to Production

# Get the configuration of an EA.
$DevEA5 = $JamfDev.GetComputerExtensionAttributeById(5)

# Remove the EA's ID -- pretty sure this isn't required, but just as an example
$DevEA5.computer_extension_attribute.RemoveChild($DevEA5.SelectSingleNode("//id"))

# Create the EA in Production
$JamfProd.CreateComputerExtensionAttribute($DevEA5)


####################################################################################################
# Copy all extension attribute from Dev to Prouction

# Get all the EAs
$devEAs = $JamfDev.GetComputerExtensionAttributes()

# For each EA id, get the get the EA's full configuration and create it in Production
$devEAs.computer_extension_attributes.computer_extension_attribute | ForEach-Object { 
    $JamfProd.CreateComputerExtensionAttribute($JamfDev.GetComputerExtensionAttributeById($_.id))
}


####################################################################################################
# Import Buildings from a CSV

# CSV had two columns:
#       column 1 = Full Building Name
#       column 2 = Building Code (aka Abbreviation)
#
# The format I wanted to use in Jamf Pro was:  Code - Full Building Name

# Import the CSV
$csvContents = Import-Csv "/path/to/Buildings.csv"

# My building list had all text in captial letters, but this wasn't the format I wanted to use, so did a little text manipulation on it.
$textInfo = (Get-Culture).TextInfo

# For each object in $allBuildings, edit the building name attribute to be like "Building Name" instead of "BUILDING NAME"
$allBuildings | ForEach-Object { ($_.bldg_name = ($_.bldg_name).Replace($_.bldg_name,$textInfo.ToTitleCase($_.bldg_name.ToLower()))) | Out-Null }

# Create each building in the format desired; used $_.trim() to clear off undsired white space that was present
$allBuildings | ForEach-Object { $JamfProSession.CreateBuilding("$($_.code.trim()) - $($_.bldg_name.trim())") }

