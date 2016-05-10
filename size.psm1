function Measure-Unit {
<#
.SYNOPSIS
	Gives the appropriate unit for any byte amount

.DESCRIPTION
	Takes in a list of numbers (of bytes) and returns an array of the appropriate unit for each value, with each element having a Text and Unit key. Note that the default unit text for "bytes" is "", as bytes are usually written plain.  If only one number is passed in, only the object will be returned (not in an array)

	Example usage:
	PS>Measure-Unit 100 1500 1500000
	Name                           Value
	----                           -----
	Text
	Unit                           1
	Text                           kb
	Unit                           1024
	Text                           kb
	Unit                           1024

.PARAMETER Units
	An array of int values to be processed. Implicit in unnamed arguments if not specified.

.PARAMETER Lower
	If Measure-Unit is called with -Lower, the lower unit will be used if there would be only 1 of the higher unit. E.g. 1048576 = 1mb would return kb rather than mb.

.PARAMETER BytesText
	By default, values >1024 will have no unit text. However, BytesText can specify an optional text.

.PARAMETER Uppercase
	Aliased as "Caps" and "Capital". If Measure-Unit is called with -Uppercase, text will be in uppercase. E.g. "MB" instead of "mb"

.PARAMETER Long
	

#>

	[CmdletBinding()]
	Param(
			#get unnamed params for units
			[Parameter(
				 Position = 0
				,ValueFromRemainingArguments = $True
				)
			]
			[Int[]]$Units,

			[Switch]$Lower = $False,

			[String]$BytesText = "",

			[Alias("Capital", "Caps")]
			[Switch]$Uppercase = $False,

			[Switch]$Long = $False
		 )

	$OutItems = New-Object System.Collections.ArrayList
	ForEach( $Size in $Units )
	{
		#dirty hack
		#if the value is lower by 1, lower unit is returned
		#switch to bool to int, $true = 1, $false = 0
		#definitely cleaner than an if() but possibly less... good
		$Size -= [Int][Bool]$Lower

		#test units
		If( $Size -lt 1kb )
		{
			$Unit = 1
			$UnitText = $BytesText
		}
		ElseIf( $Size -lt 1mb )
		{
			$Unit = 1kb
			$UnitText = "kilo"
		}
		ElseIf( $Size -lt 1gb )
		{
			$Unit = 1mb
			$UnitText = "mega"
		}
		ElseIf( $Size -lt 1tb )
		{
			$Unit = 1gb
			$UnitText = "giga"
		}
		ElseIf( $Size -lt 1pb )
		{
			#if you ever ask powershell to measure the size of
			#a terabytes-large file, godspeed. may you never
			#need this case
			$Unit = 1tb
			$UnitText = "tera"
		}

		If( $Long -and (-not ($Size -lt 1kb -and $BytesText) ))
		{
			#if we want longer units, add "bytes" unless
			#called with -BytesText, in which case skip
			$UnitText += "$(if( $BytesText )
			{
				$BytesText
			}
			else
			{
				'bytes'
			})"
		}
		ElseIf( ! ($Long -and $Size -lt 1kb) )
		{
			$UnitText = "$($UnitText[0])b"
		}

		#if called with -Uppercase make it uppercase
		if( $Uppercase )
		{
			$UnitText = $UnitText.ToUpper();
		}

		#add elem to out array, don't display output
		$OutItems.Add(
			@{Unit = $Unit
			Text = $UnitText
		}) > $null
	}

	return $OutItems
}

function Format-Unit
{
	[CmdletBinding()]
	Param(
			[Switch]$help = $False,
			
			[Parameter(
				Mandatory = $False
				)
			]
			[Int]$Decimals = 2,

			[Parameter(
				 Position = 0
				,ValueFromRemainingArguments = $True
				)
			]
			[String[]]$Amounts

		 )

	If( $help -or ! $Amounts)
	{
		"Takes in a list of numbers (of bytes) and returns an array"
		"of the appropriately formatted units for each value"
		"`n`rExample usage:"
		"PS>Format-Unit 100 1500 1500000"
		"[0]: 100"
		"[1]: 1.46kb"
		"[2]: 1.43mb"
		return
	}
	$OutItems = New-Object System.Collections.ArrayList
	ForEach( $Size in $Amounts )
	{
		$Units = Measure-Unit $Size

		If($Units.Text -eq "") {
#Would be kinda weird to show 12.00 bytes
			$Decimals = 0
		}

		$OutItems.Add(
			"{0:N$($Decimals)} $($Units.Text)" -f ($Size / $Units.Unit)
			) > $null
	}
	return $OutItems
}

function Get-Size
{
	[CmdletBinding()]
	Param(
			[Parameter(
				 Position=0
				,ValueFromPipeline=$True
				,ValueFromRemainingArguments = $True
				)
			]
			[String]$PathSpec = ".\",

			[Switch]$help = $False,

			[alias("All")]
			[Switch]$Force = $False
		 )

	if($help)
	{
		"Takes in a path-spec (default `".\`") like .\ or l* and returns the cumulative"
		"sum of the sizes of all files (and folders and sub-folders)"
		"that match that path"
		"Accepts -Verbose and -All"
		"`n`rExample usage:"
		"PS>Get-Size"
		"10.36 kb"
		"`n`rPS>Get-Size -Verbose"
		"VERBOSE: The cumulative size of all 5 files matching .\"
		"VERBOSE: C:\Users\user\Documents\PowerShell Modules\size\size.ps1 C:\Users\user\Documents\PowerShell Modules\size\size.psd1 C:\Users\user\Documents\PowerShell Modules\size\size.psm1"
		"VERBOSE: (average of 2.59 kb / file)"
		"10.36 kb"
		return
	}

	if( !(Test-Path $PathSpec) )
	{
		"Error: Nothing matches that path."
		return
	}

	$Items = iex "(Get-ChildItem $PathSpec -recurse $(if( $Force ){`"-Force`"}) | Measure-Object -property length -sum)"

	Write-Verbose "The cumulative size of all $($Items.Count) file$(if($Items.Count -ne 1){'s'}) matching $($PathSpec)"

	Write-Verbose (iex "([String](Get-ChildItem $PathSpec -recurse $(if( $Force ){`"-Force`"})))")
	$Average = $Items.sum/$Items.count
	Write-Verbose "(average of $(Format-Unit $Average) / file)"

	"$(Format-Unit $Items.sum)"

}
