function Get-PASAccount {
	<#
.SYNOPSIS
Returns details of matching accounts. (Version 10.4 onwards)
Returns information about a single account. (Version 9.3 - 10.3)

.DESCRIPTION
Version 10.4+:
This method returns a list of either a specific, or all the accounts in the Vault.
Requires the following permission in the Safe: List accounts.

Version 9.3 - 10.3:
Returns information about an account. If more than one account meets the search criteria,
only the first account will be returned (the Count output parameter will display the number
of accounts that were found).
Only the following users can access this account:
    - Users who are members of the Safe where the account is stored
    - Users who have access to this specific account.
    - The user who runs this web service requires the following permission in the Safe:
    - Retrieve account
This method does not display the actual password.
If ten or more accounts are found, the Count Output parameter will show 10.

.PARAMETER id
A specific account ID to return details for.

.PARAMETER search
The search term or keywords.

.PARAMETER searchType
Get accounts that either contain or start with the value specified in the Search parameter.

.PARAMETER sort
Property or properties by which to sort returned accounts,
followed by asc (default) or desc to control sort direction.
Separate multiple properties with commas, up to a maximum of three properties.

.PARAMETER offset
An offset for the search results (to discard the first x results for instance).

.PARAMETER limit
Maximum number of returned accounts. If not specified, the default value is 50.
The maximum number that can be specified is 1000. When used together with the Offset parameter,
this value determines the number of accounts to return, starting from the first account that is returned.

.PARAMETER filter
A filter for the search.
Requires format: "SafeName eq 'YourSafe'"

.PARAMETER Keywords
Keyword to search for.
If multiple keywords are specified, the search will include all the keywords.
Separate keywords with a space.
Relevant for CyberArk versions earlier than 10.4

.PARAMETER Safe
The name of a Safe to search. The search will be carried out only in the Safes in the Vault
that the authenticated used is authorized to access.
Relevant for CyberArk versions earlier than 10.4

.PARAMETER TimeoutSec
See Invoke-WebRequest
Specify a timeout value in seconds

.EXAMPLE
Get-PASAccount

Returns  all accounts on safes where your user has "List accounts" rights.
This will only work from version 10.4 onwards.

.EXAMPLE
Get-PASAccount -search root -sort name -offset 100 -limit 5

Returns all accounts matching "root", sorted by AccountName, Search results offset by 100 and limited to 5.

.EXAMPLE
Get-PASAccount -search XUser -searchType startswith

Returns all accounts starting with "XUser".

.EXAMPLE
Get-PASAccount -filter "SafeName eq TargetSafe"

Returns all accounts found in TargetSafe

.EXAMPLE
Get-PASAccount -filter "SafeName eq 'TargetSafe'" -sort "userName desc"

Returns all accounts found in TargetSafe, sort by username in descending order.

.EXAMPLE
Get-PASAccount -Keywords root -Safe UNIX

Finds account(s) matching keywords in UNIX safe:

AccountID  : 19_6
Safe       : UNIX
Folder     : Root
Name       : UNIXSSH-machine-root
UserName   : root
PlatformID : UNIXSSH
DeviceType : Operating System
Address    : machine

.EXAMPLE
Get-PASAccount -Keywords xtest

Finds accounts matching the specified keyword.
Only the first matching account will be returned.
If multiple accounts are found, a warning will be displayed before the result:

WARNING: 3 matching accounts found. Only the first result will be returned

AccountID  : 19_9
Safe       : TestSafe
Folder     : Root
Name       : Application-Cyberark-10.10.10.20-xTest3
UserName   : xTest3
PlatformID : Cyberark
DeviceType : Application
Address    : 10.10.10.20

.INPUTS
All parameters can be piped by property name
Should accept pipeline objects from other *-PASAccount functions

.OUTPUTS
Outputs Object of Custom Type psPAS.CyberArk.Vault.Account
AccountID, Account Safe, Safe Folder, Account Name,
and any other set property of the account are contained in output.

Output format is defined via psPAS.Format.ps1xml.
To force all output to be shown, pipe to Select-Object *
Output format is defined via psPAS.Format.ps1xml.
To force all output to be shown, pipe to Select-Object *

.NOTES
New functionality added in version 10.4, limited functionality before this version.
As of psPAS v2.5.1+, the use of 'limit' and 'offset' parameters is discouraged - nextLink functionality was added

.LINK
https://pspas.pspete.dev/commands/Get-PASAccount

#>

	[CmdletBinding(DefaultParameterSetName = "v10ByQuery")]
	param(
		[parameter(
			Mandatory = $true,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v10ByID"
		)]
		[Alias("AccountID")]
		[string]$id,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v10ByQuery"
		)]
		[string]$search,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v10ByQuery"
		)]
		[ValidateSet("startswith", "contains")]
		[string]$searchType,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v10ByQuery"
		)]
		[string[]]$sort,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v10ByQuery"
		)]
		[int]$offset,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v10ByQuery"
		)]
		[ValidateRange(1, 1000)]
		[int]$limit,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v10ByQuery"
		)]
		[string]$filter,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v9"
		)]
		[ValidateLength(0, 500)]
		[string]$Keywords,

		[parameter(
			Mandatory = $false,
			ValueFromPipelinebyPropertyName = $true,
			ParameterSetName = "v9"
		)]
		[ValidateLength(0, 28)]
		[string]$Safe,

		[parameter(
			Mandatory = $false,
			ValueFromPipelineByPropertyName = $false
		)]
		[int]$TimeoutSec

	)

	BEGIN {
		$MinimumVersion = [System.Version]"10.4"
		$RequiredVersion = [System.Version]"11.2"
	}#begin

	PROCESS {

		#Get Parameters to include in request
		$boundParameters = $PSBoundParameters | Get-PASParameter

		#Create Query String, escaped for inclusion in request URL
		$queryString = $boundParameters | ConvertTo-QueryString

		#Version 10.4 process
		If ($PSCmdlet.ParameterSetName -match "v10") {

			#check version
			if ($PSBoundParameters.ContainsKey("searchType")) {

				#check required version
				Assert-VersionRequirement -ExternalVersion $Script:ExternalVersion -RequiredVersion $RequiredVersion

			}
			Else {

				#check minimum version
				Assert-VersionRequirement -ExternalVersion $Script:ExternalVersion -RequiredVersion $MinimumVersion

			}

			#assign new type name
			$typeName = "psPAS.CyberArk.Vault.Account.V10"

			#define base URL
			$URI = "$Script:BaseURI/api/Accounts"

			If ($PSCmdlet.ParameterSetName -eq "v10ByQuery") {
				if ($queryString) {

					#Build URL from base URL
					$URI = "$URI`?$queryString"

				}
			}

			If ($PSCmdlet.ParameterSetName -eq "v10ByID") {

				#define "by ID" URL
				$URI = "$URI/$id"

			}

		}

		#legacy process
		If ($PSCmdlet.ParameterSetName -eq "v9") {

			#assign type name
			$typeName = "psPAS.CyberArk.Vault.Account"

			#Create request URL
			$URI = "$Script:BaseURI/WebServices/PIMServices.svc/Accounts"

			if ($queryString) {

				#Build URL from base URL
				$URI = "$URI`?$queryString"

			}

		}

		#Send request to web service
		$result = Invoke-PASRestMethod -Uri $URI -Method GET -WebSession $Script:WebSession -TimeoutSec $TimeoutSec

		if ($result) {

			#Get count of accounts found
			$count = $($result.count)

			#Version 10.4 individual account process
			If ($PSCmdlet.ParameterSetName -eq "v10ByID") {

				#return expected single result
				$return = $result

			}

			#If accounts found
			if ($count -gt 0) {

				#Version 10.4 query process
				If ($PSCmdlet.ParameterSetName -eq "v10ByQuery") {

					#to store list of query results
					$AccountList = [Collections.Generic.List[Object]]@()

					#add resultst to list
					$null = $AccountList.Add($result.value)

					#iterate any nextLinks
					$NextLink = $result.nextLink
					While ( $null -ne $NextLink ) {
						$URI = "$Script:BaseURI/$NextLink"
						$result = Invoke-PASRestMethod -Uri $URI -Method GET -WebSession $Script:WebSession -TimeoutSec $TimeoutSec
						$NextLink = $result.nextLink
						$null = $AccountList.AddRange(($result.value))
					}

					#return list
					$return = $AccountList

				}

				#legacy process
				If ($PSCmdlet.ParameterSetName -eq "v9") {

					#If multiple accounts found
					if ($count -gt 1) {

						#Alert that web service only displays information on first result
						Write-Warning "$count matching accounts found. Only the first result will be returned"

					}

					#Get account details from search result
					$account = ($result | Select-Object accounts).accounts

					#Get account properties from found account
					$properties = ($account | Select-Object -ExpandProperty properties)

					#Get internal properties from found account
					$InternalProperties = ($account | Select-Object -ExpandProperty InternalProperties)

					$InternalProps = New-Object -TypeName psobject

					#For every account property
					For ($int = 0; $int -lt $InternalProperties.length; $int++) {

						$InternalProps |

						#Add each property name and value as object property of $InternalProps
						Add-ObjectDetail -PropertyToAdd @{$InternalProperties[$int].key = $InternalProperties[$int].value } -Passthru $false

					}

					#Create output object
					$return = New-object -TypeName psobject -Property @{

						#Internal Unique ID of Account
						"AccountID"          = $($account | Select-Object -ExpandProperty AccountID)

						#InternalProperties object
						"InternalProperties" = $InternalProps

					}

					#For every account property
					For ($int = 0; $int -lt $properties.length; $int++) {

						$return |

						#Add each property name and value to results
						Add-ObjectDetail -PropertyToAdd @{$properties[$int].key = $properties[$int].value } -Passthru $false

					}

				}

			}

		}

		if ($return) {

			#Return Results
			$return | Add-ObjectDetail -typename $typeName

		}

	}#process

	END { }#end

}