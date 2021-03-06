<#
Name: zabbixapi.psml
PoSh: 3.0
Creation date: 2015-07-28
Author: Chistyakov V. 
Description:
#>

<#
.SYNOPSIS
Add property to the object.

.DESCRIPTION
Add/replase (if exist) property to the object. You can set check null or true.

.PARAMETER object
The object

.PARAMETER name
Name of property

.PARAMETER value
Value of property

.PARAMETER checknull
Switch to check of null value

.PARAMETER checktrue
Switch to check of true value

.INPUTS
You can pipe objects to Add-ZabbixAPIParameter

.OUTPUTS
System.Object. Add-ZabbixAPIParameter return new object with new property.

.EXAMPLE
Add-ZabbixAPIParameter -object $obj -Name jsonrpc -Value $jsonrpc

.EXAMPLE
Add-ZabbixAPIParameter -object $obj -Name hostids -Value $hostids -CheckNull

.EXAMPLE
$onj | Add-ZabbixAPIParameter -Name jsonrpc -Value $jsonrpc
#>
function Add-ZabbixAPIParameter {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
		[psobject]$object,

		[parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string]$name,

		[parameter(Mandatory = $true, Position = 2)]
		[AllowEmptyCollection()]
		[AllowNull()]
		[System.Object]$value,

		[parameter()]
		[switch]$checknull,

		[parameter()]
		[switch]$checktrue
	)
	
	process {
		switch ($true) {
			$checknull {
				if ($value -ne $null) {
					$object | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force -PassThru;
				}
			}
			$checktrue {
				if ($value -eq $true) {
					$object | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force -PassThru;
				}
			}
			default {
				$object | Add-Member -MemberType NoteProperty -Name $name -Value $value -Force -PassThru;
			}
		}
		return $object;
  }
}

<#
.SYNOPSIS
Convert DateTime to Unix long format.

.DESCRIPTION
Convert DateTime format to unix long format.

.PARAMETER date
Value of DateTime. Current value by default.

.INPUTS
You can pipe objects to ConvertTo-UnixTimeStamp

.OUTPUTS
Double.

.EXAMPLE
ConvertTo-UnixTimeStamp

.EXAMPLE
ConvertTo-UnixTimeStamp -date (Get-Date)

.EXAMPLE
Get-Date | ConvertTo-UnixTimeStamp
#>
function ConvertTo-UnixTimeStamp {
	[cmdletbinding()]
	param (
		[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
		[datetime]$date = (Get-Date)
	)
	
	Begin {
		$startDate = Get-Date -Date '01/01/1970';
	}

	Process {
		return (New-TimeSpan -Start $startDate -End $date).TotalSeconds;
	}
}

<#
.SYNOPSIS
Convert Unix long format to DateTime.

.DESCRIPTION
Convert unix long format to DateTime format.

.PARAMETER timestamp
Value of double (unix datetime format).

.INPUTS
You can pipe objects to ConvertFrom-UnixTimeStamp

.OUTPUTS
DateTime.

.EXAMPLE
ConvertFrom-UnixTimeStamp

.EXAMPLE
ConvertTo-UnixTimeStamp -timestamp 1441126694.52411

.EXAMPLE
ConvertTo-UnixTimeStamp | ConvertTo-UnixTimeStamp
#>
function ConvertFrom-UnixTimeStamp {
	[cmdletbinding()]
	Param(
		[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
		[double]$timestamp
	)

	Begin {
		$startDate = Get-Date -Date '01/01/1970';
	}
	Process {
		if(!$timestamp) {
			return Get-Date;
		}
		return $startDate.AddSeconds($timestamp);
	}
}

<#
.SYNOPSIS
Invoke zabbix request 

.DESCRIPTION
Invoke zabbix request. It uses the JSON-RPC 2.0 protocol. Input object will convered to json object. 

.PARAMETER object
Object containing the query parameters

.PARAMETER session
Object contains the user session atributes

.PARAMETER url
URL address zabbix api

.INPUTS
You can pipe objects to Invoke-ZabbixAPI

.OUTPUTS
psobject.

.EXAMPLE
Invoke-ZabbixAPI -object $obj -url 'http://myzabbix/api'

.EXAMPLE
Invoke-ZabbixAPI -object $obj -session $session

.EXAMPLE
$obj | Invoke-ZabbixAPI -session $session
#>
function Invoke-ZabbixAPI {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
		[System.Object]$object,
		
		[parameter(Mandatory = $true, Position = 1, ParameterSetName="Session")]
		[System.object]$session,
		
		[parameter(Mandatory = $true, Position = 1, ParameterSetName="URL")]
		[alias('URL', 'ApiURl')]
		[String]$uri
	)
	process {
		try {
			switch ($PsCmdlet.ParameterSetName) {
				'URL' {
					return ((Invoke-WebRequest -Uri $uri -Body ($object | ConvertTo-Json) -Method Post -ContentType 'application/json' -UseBasicParsing).Content | ConvertFrom-Json);
				}
				'Session' {
					return ((Invoke-WebRequest -Uri $session.uri -Body ($object | ConvertTo-Json) -Method Post -ContentType 'application/json' -UseBasicParsing).Content | ConvertFrom-Json);
				}
			}
		}
		catch [System.Net.WebException] {
			$err = $_.Exception;
			return (New-Object psobject | Add-Member -PassThru -MemberType NoteProperty -Name error -Value @{code = $err.Response.StatusCode; message = $err.Message; data = $err.Data});
		}
	}
}

function Connect-Zabbix {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true, Position = 0)]
		[PSCredential]$credential,
		
		[parameter(Mandatory = $true, position = 1)]
		[alias('URL', 'ApiURl')]
		[string]$uri,

		[parameter(Position = 2)]
		[string]$jsonrpc = '2.0'
	)
	
	process {
		$params = New-Object psobject |
			Add-ZabbixAPIParameter -Name user -Value $credential.getNetworkCredential().userName |
			Add-ZabbixAPIParameter -Name password -Value $credential.getNetworkCredential().password;
		
		$objUser = New-Object psobject | 
			Add-ZabbixAPIParameter -Name jsonrpc -Value $jsonrpc |
			Add-ZabbixAPIParameter -Name method -Value user.login |
			Add-ZabbixAPIParameter -Name params -Value $params |
			Add-ZabbixAPIParameter -Name id -Value (Get-Random -Minimum 1);

		$respone = Invoke-ZabbixAPI -Object $objUser -URI $uri;
		return (
			New-Object psobject | 
				Add-Member -PassThru -MemberType NoteProperty -Name user -Value $credential.getNetworkCredential().userName |
				Add-Member -PassThru -MemberType NoteProperty -Name uri -Value $uri |
				Add-Member -PassThru -MemberType NoteProperty -Name id -Value $respone.id |
				Add-Member -PassThru -MemberType NoteProperty -Name jsonrpc -Value $respone.jsonrpc |
				Add-Member -PassThru -MemberType NoteProperty -Name auth -Value $respone.result | 
				Add-Member -PassThru -MemberType NoteProperty -Name error -Value $respone.error
		);
	}
}

function Disconect-Zabbix {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Token')]
		[alias('Authentication')]
		[String]$token,
		
		[parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Token')]
		[alias('URL', 'ApiURl')]
		[string]$uri,

		[parameter(Position = 2, ParameterSetName = 'Token')]
		[int]$id = 0,

		[parameter(Position = 3, ParameterSetName = 'Token')]
		[string]$jsonrpc = '2.0',

		[parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Session')]
		[psobject]$session
	)
	
	process {
		$objUser = New-Object psobject |
			Add-ZabbixAPIParameter -Name method -Value 'user.logout' |
			Add-ZabbixAPIParameter -Name params -Value @{};
		switch ($PsCmdlet.ParameterSetName) {
			'Token' {
				$objUser = $objUser | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $id |
					Add-ZabbixAPIParameter -Name auth -Value $token;
				return (Invoke-ZabbixAPI -object $objUser -uri $uri);
			}
			'Session' {
				$objUser = $objUser | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $session.jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $session.id |
					Add-ZabbixAPIParameter -Name auth -Value $session.auth;
				return (Invoke-ZabbixAPI -object $objUser -session $session);
			}
		}
	}
}

function Get-ZabbixApiInfo {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Token')]
		[alias('URL', 'ApiURl')]
		[string]$uri,

		[parameter(Position = 2, ParameterSetName = 'Token')]
		[int]$id = 0,

		[parameter(Position = 3, ParameterSetName = 'Token')]
		[string]$jsonrpc = '2.0',

		[parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Session')]
		[psobject]$session
	)
	
	process {
		$objApiinfo = New-Object psobject | 
			Add-ZabbixAPIParameter -Name method -Value 'apiinfo.version' |
			Add-ZabbixAPIParameter -Name params -Value @{};
		switch ($PsCmdlet.ParameterSetName) {
			'Token' {
				$objApiinfo = $objApiinfo | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $id;
				return (Invoke-ZabbixAPI -object $objUser -uri $uri);
			}
			'Session' {
				$objApiinfo = $objApiinfo | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $session.jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $session.id;
				return (Invoke-ZabbixAPI -object $objApiinfo -session $session);
			}
		}
	}
}

function Get-ZabbixHistory {
	[cmdletbinding()]
	param(
		[parameter(Mandatory = $true, ParameterSetName = 'Token')]
		[alias('Authentication')]
		[String]$token,
		
		[parameter(Mandatory = $true, ParameterSetName = 'Token')]
		[alias('URL', 'ApiURl')]
		[string]$uri,

		[parameter(ParameterSetName = 'Token')]
		[int]$id = 0,

		[parameter(ParameterSetName = 'Token')]
		[string]$jsonrpc = '2.0',

		[parameter(Mandatory = $true, ParameterSetName = 'Session')]
		[psobject]$session,

		[parameter()]
		[ValidateSet('float', 'string', 'log', 'integer', 'text')]
		[string]$history = 'integer',

		[parameter(Mandatory = $false, ParameterSetName = 'Token')]
		[parameter(Mandatory = $false, ParameterSetName = 'Session')]
		##[parameter(Mandatory =$true, ParameterSetName = 'Host')]
		[ValidateNotNullOrEmpty()]
		[string[]]$hostids,

		[parameter(Mandatory = $false, ParameterSetName = 'Token')]
		[parameter(Mandatory = $false, ParameterSetName = 'Session')]
		##[parameter(Mandatory =$true, ParameterSetName = 'Item')]
		[ValidateNotNullOrEmpty()]
		[string[]]$itemids,

		[parameter()]
		[ValidateNotNull()]
		[datetime]$startDate,

		[parameter()]
		[ValidateNotNull()]
		[datetime]$endDate,

		[parameter()]
		[ValidateSet('ASC', 'DESC')]
		[string]$sortorder,

		[parameter()]
		[switch]$countOutput,

		[parameter()]
		[int]$limit
	)

	begin {
		switch ($history) {
			'float' { $historyVal = 0;}
			'string' { $historyVal = 1;}
			'log' { $historyVal = 2;}
			'integer' {$historyVal = 3;}
			'text' {$historyVal = 4;}
		}
	}

	process {
		$params = New-Object psobject |
			Add-ZabbixAPIParameter -Name history -Value $historyVal -CheckNull |
			Add-ZabbixAPIParameter -Name hostids -Value $hostids -CheckNull |
			Add-ZabbixAPIParameter -Name itemids -Value $itemids -CheckNull |
			Add-ZabbixAPIParameter -Name time_from -Value (ConvertTo-UnixTimeStcamp $startDate) -CheckNull |
			Add-ZabbixAPIParameter -Name time_till -Value (ConvertTo-UnixTimeStcamp $endDate) -CheckNull |
			Add-ZabbixAPIParameter -Name sortorder -Value $sortorder -CheckNull |
			Add-ZabbixAPIParameter -Name countOutput -Value $true -CheckNull |
			Add-ZabbixAPIParameter -Name limit -Value ([System.Math]::Abs($limit)) -CheckNull;

		$objHistory = New-Object psobject |
			Add-ZabbixAPIParameter -Name method -Value 'history.get' |
			Add-ZabbixAPIParameter -Name params -Value $params;
		switch ($PsCmdlet.ParameterSetName) {
			'Token' {
				$objHistory = $objHistory | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $id |
					Add-ZabbixAPIParameter -Name auth -Value $token;
				return (Invoke-ZabbixAPI -object $objHistory -uri $uri);				
			}
			'Session' {
				$objHistory = $objHistory | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $session.jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $session.id |
					Add-ZabbixAPIParameter -Name auth -Value $session.auth;
				return (Invoke-ZabbixAPI -object $objHistory -session $session);
			}
		}
	}
}

function Get-ZabbixHostExists {
	[cmdletbinding()]
	param (
		[parameter(Mandatory = $true, ParameterSetName = 'Token')]
		[alias('Authentication')]
		[String]$token,
		
		[parameter(Mandatory = $true, ParameterSetName = 'Token')]
		[alias('URL', 'ApiURl')]
		[string]$uri,
		
		[parameter(ParameterSetName = 'Token')]
		[int]$id = 0,

		[parameter(ParameterSetName = 'Token')]
		[string]$jsonrpc = '2.0',
		
		[parameter(Mandatory = $true, ParameterSetName = 'Session')]
		[psobject]$session,

		[parameter()]
		[string[]]$hostid,

		[parameter()]
		[string[]]$host,

		[parameter()]
		[string[]]$name
	)

	process {
		$params = New-Object psobject |
			Add-ZabbixAPIParameter -Name hostid -Value $hostid -CheckNull |
			Add-ZabbixAPIParameter -Name host -Value $hostid -CheckNull |
			Add-ZabbixAPIParameter -Name name -Value $name -CheckNull;

		$objHostExists = New-Object psobject |
			Add-ZabbixAPIParameter -Name method -Value 'host.exists' |
			Add-ZabbixAPIParameter -name params -Value $params;
		switch ($PsCmdlet.ParameterSetName) {
			'Token' {
				$objHostExists = $objHostExists | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $id |
					Add-ZabbixAPIParameter -Name auth -Value $token;
				return (Invoke-ZabbixAPI -object $objHostExists -uri $uri);				
			}
			'Session' {
				$objHostExists = $objHostExists | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $session.jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $session.id |
					Add-ZabbixAPIParameter -Name auth -Value $session.auth;
				return (Invoke-ZabbixAPI -object $objHostExists -session $session);
			}
		}
	}
}

function Get-ZabbixHost {
	[cmdletbinding()]
	param (
		[parameter(Mandatory = $true, ParameterSetName = 'Token')]
		[alias('Authentication')]
		[String]$token,
		
		[parameter(Mandatory = $true, ParameterSetName = 'Token')]
		[alias('URL', 'ApiURl')]
		[string]$uri,
		
		[parameter(ParameterSetName = 'Token')]
		[int]$id = 0,

		[parameter(ParameterSetName = 'Token')]
		[string]$jsonrpc = '2.0',
		
		[parameter(Mandatory = $true, ParameterSetName = 'Session')]
		[psobject]$session,

		[parameter()]
		[string[]]$groupids,

		[parameter()]
		[string[]]$applicationids,

		[parameter()]
		[string[]]$dserviceids,

		[parameter()]
		[string[]]$graphids,

		[parameter()]
		[string[]]$hostids,

		[parameter()]
		[string[]]$httptestids,

		[parameter()]
		[string[]]$interfaceids,

		[parameter()]
		[string[]]$itemids,

		[parameter()]
		[string[]]$maintenanceids,

		[parameter()]
		[switch]$monitored_hosts,

		[parameter()]
		[switch]$proxy_hosts,

		[parameter()]
		[string[]]$proxyids,

		[parameter()]
		[switch]$templated_hosts,

		[parameter()]
		[string[]]$templateids,

		[parameter()]
		[string[]]$triggerids,

		[parameter()]
		[switch]$with_items,

		[parameter()]
		[switch]$with_applications,

		[parameter()]
		[switch]$with_graphs,

		[parameter()]
		[switch]$with_httptests,

		[parameter()]
		[switch]$with_monitored_httptests,

		[parameter()]
		[switch]$with_monitored_items,

		[parameter()]
		[switch]$with_monitored_triggers,

		[parameter()]
		[switch]$with_simple_graph_items,

		[parameter()]
		[switch]$with_triggers,

		[parameter()]
		[switch]$withInventory,

		[parameter()]
		[ValidateSet('hostid', 'host', 'name', 'status')]
		[string]$sortfield,

		[parameter()]
		[ValidateSet('ASC', 'DESC')]
		[string]$sortorder,

		[parameter()]
		[switch]$countOutput,

		[parameter()]
		[int]$limit
	)

	process {
		$params = New-Object psobject |
			Add-ZabbixAPIParameter -Name groupids -Value $groupids -CheckNull |
			Add-ZabbixAPIParameter -Name applicationids -Value $applicationids -CheckNull |
			Add-ZabbixAPIParameter -Name dserviceids -Value $dserviceids -CheckNull |
			Add-ZabbixAPIParameter -Name graphids -Value $graphids -CheckNull |
			Add-ZabbixAPIParameter -Name hostids -Value $hostids -CheckNull |
			Add-ZabbixAPIParameter -Name httptestids -Value $httptestids -CheckNull |
			Add-ZabbixAPIParameter -Name interfaceids -Value $interfaceids -CheckNull |
			Add-ZabbixAPIParameter -Name itemids -Value $itemids -CheckNull |
			Add-ZabbixAPIParameter -Name maintenanceids -Value $maintenanceids -CheckNull |
			Add-ZabbixAPIParameter -Name monitored_hosts -Value $monitored_hosts -CheckTrue |
			Add-ZabbixAPIParameter -Name proxy_hosts -Value $proxy_hosts -CheckTrue |
			Add-ZabbixAPIParameter -Name proxyids -Value $proxyids -CheckNull |
			Add-ZabbixAPIParameter -Name templated_hosts -Value $templated_hosts -CheckTrue |
			Add-ZabbixAPIParameter -Name templateids -Value $templateids -CheckNull |
			Add-ZabbixAPIParameter -Name triggerids -Value $triggerids -CheckNull |
			Add-ZabbixAPIParameter -Name with_items -Value $with_items -CheckTrue |
			Add-ZabbixAPIParameter -Name with_applications -Value $with_applications -CheckTrue |
			Add-ZabbixAPIParameter -Name with_graphs -Value $with_graphs -CheckTrue |
			Add-ZabbixAPIParameter -Name with_httptests -Value $with_httptests -CheckTrue |
			Add-ZabbixAPIParameter -Name with_monitored_httptests -Value $with_monitored_httptests -CheckTrue |
			Add-ZabbixAPIParameter -Name with_monitored_items -Value $with_monitored_items -CheckTrue |
			Add-ZabbixAPIParameter -Name with_monitored_triggers -Value $with_monitored_triggers -CheckTrue |
			Add-ZabbixAPIParameter -Name with_simple_graph_items -Value $with_simple_graph_items -CheckTrue |
			Add-ZabbixAPIParameter -Name with_triggers -Value $with_triggers -CheckTrue |
			Add-ZabbixAPIParameter -Name withInventory -Value $withInventory -CheckTrue |
			Add-ZabbixAPIParameter -Name sortfield -Value $sortfield -CheckNull |
			Add-ZabbixAPIParameter -Name sortorder -Value $sortorder -CheckNull |
			Add-ZabbixAPIParameter -Name countOutput -Value $countOutput -CheckTrue |
			Add-ZabbixAPIParameter -Name limit -Value $limit -CheckNull;

		$objHost = New-Object psobject |
			Add-ZabbixAPIParameter -Name method -Value 'host.get' |
			Add-ZabbixAPIParameter -name params -Value $params;
		switch ($PsCmdlet.ParameterSetName) {
			'Token' {
				$objHost = $objHost | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $id |
					Add-ZabbixAPIParameter -Name auth -Value $token;
				return (Invoke-ZabbixAPI -object $objHostExists -uri $uri);				
			}
			'Session' {
				$objHost = $objHost | 
					Add-ZabbixAPIParameter -Name jsonrpc -Value $session.jsonrpc |
					Add-ZabbixAPIParameter -Name id -Value $session.id |
					Add-ZabbixAPIParameter -Name auth -Value $session.auth;
				return (Invoke-ZabbixAPI -object $objHostExists -session $session);
			}
		}
	}
}