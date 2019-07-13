Pwsh-JamfClassicAPI
======

#### PowerShell Module for the Jamf Classic API ####

**Finally added some [examples](../master/Examples)!**

This module essentially provides a Jamf Classic API focused wrapper for the `Invoke-RestMethod` cmdlet while also providing some additional functionality.  As expressed in the name, this Module only supports the Classic API and not the Jamf Pro API (formally UAPI/Universal API).

This will provide very similar functionality to several projects, [python-jss](https://github.com/jssimporter/python-jss) and [jss_helper](https://github.com/sheagcraig/jss_helper) by Shea Craig and [ruby-jss](https://github.com/PixarAnimationStudios/ruby-jss) from Pixar Animation Studios, as well as other available tools I've come across:
  * https://github.com/eventbrite/Casper-API-Tools
  * https://github.com/beyondthebox/JSS-Resource-Tools

## Goal ##

The goal currently stands to be able to provide all the functionality of the Jamf API via an easily accessible and predictable PowerShell syntax, through both "cmdlet"-like functions and a PowerShell Class.Method syntax. 

Hopefully this will help some of the more Windows-minded Admins or even, environments where the Windows environment "rules" the Jamf environment, and so creating automated processes via other similar projects (python-jss) may not be as welcomed.

This is just another alternative available for Jamf Admins to use, I make no claims nor do I imply it is any better than all the pre-existing projects.

## Requirements ##

This module is supported in both Windows PowerShell as well and PowerShell Core, so it can be used on macOS!
  * The "cmdlet"-like functionality requires PowerShell v4.0
  * The PwshJamf Class, requires PowerShell v5.0

## Functionality ##

Functionality wise, the module is useable.  While current resource endpoints that are available in the PwshJamf Class are likely ones that I'm using in production scripts or workflows, eventually, there will likely be resource endpoints that I haven't tested as I don't use them on a regular basis, or at all.  But for the most part, majority of the logic behind the code is quite similar, so most should work as intended.

The following items have been tested:
  * PwshJamf Class
    * Most endpoints have been tested to some degree, but I still recommend testing before running in production
  * Invoke-JamfClassicAPI
    * Resource Parameter "auto completes" as desired
    * Methods
      * GET
      * DELETE
      * PUSH
      * PUT
    * Headers
      * json
      * xml
    * Verifies Method is supported by the supplied Resource
    * Data passed via the $Endpoints Parameter will successfully transpose into the requested $Resource (so far in testing)
  * Get-JamfAPIResources
    * Successfully grabs all API Resources from the provided Jamf Pro Server
  * Set-JamfServer
    * Successfully sets the Jamf Pro Server URL to the session environment

## Needs to be tested ##

While it should work, I haven't tested the following functionality:
  * Invoke-JamfClassicAPI
    * Pipeline (To/From)
  * Set-JamfServer
    * Disable SSL Validation (For Self Signed Certs)

## To Do ##

Most of the "pretty features" of the cmdlet functions have taken a back seat as I've been focusing on adding Class Methods for all API endpoint resources.  Hope to eventually make it back around to these.  But I've really been using the Class Methods in new scripts and my daily worklows, so those are of a higher value to me at this time.

The following items are what are on the list to be done:
  * (Much) more testing
  * Documentation, Examples, etc
  * Invoke-JamfClassicAPI
    * Improve the -Authentication method
  * Set-JamfServer
    * Save Jamf Pro Server URL to user environment
  * Set-JamfAuthentication
    * Save credentials to the Credential Manager
  * And hopefully plenty more built-in functionality

## Reporting Issues / Contributing ##

Please report any issues to this repository.  It would probably be helpful, if you @me in the issue so I get a notification.

If you would like to contribute, feel free to create a pull request.

## Acknowledgments ##

@koalatee - Thanks for listening to me babble on about this idea.

## Warranty ##

Please see the license; that said, please test this code, and yours, in a dev environment.  Don't be that guy that tests in production.  **You** are responsible if **you** break it.