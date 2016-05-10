function Measure-Unit {
<#
.SYNOPSIS
	Gives the appropriate unit for any byte amount

.DESCRIPTION
	Takes in a list of numbers (of bytes) and returns an array of the appropriate unit for each value, with each element having a Text (a string like "mb" or "kb") and Unit (an int like 1024 or 1048576) key.
	Note that the default unit text for "bytes" is "", as bytes are usually written plain.
	If only one number is passed in, only the object will be returned (not in an array).
	Accepts pipeline input.

.PARAMETER Units
	An array of int values to be processed. Implicit in unnamed arguments if not specified.

.PARAMETER RoundDown
	Aliased as "Lower". If Measure-Unit is called with -RoundDown, the lower unit will be used if there would be only 1 of the higher unit. E.g. 1048576 = 1mb would return kb rather than mb.

.PARAMETER BytesText
	By default, values >1024 will have no unit text. However, if -BytesText is passed, the unit text for bytes will be "b" (or "bytes" if passed in tandem with -Long).

.PARAMETER UpperCase
	Aliased as "Caps" and "Capital". If Measure-Unit is called with -UpperCase, text will be in uppercase. E.g. "MB" instead of "mb".

.PARAMETER TitleCase
	Capitalizes the first letter of each unit. Overriden by -UpperCase if both are passed.

.PARAMETER Long
	Enables un-abbreviated output, E.g. "kilobytes" instead of "kb".

.FUNCTIONALITY
	Used mainly in Format-Unit

.EXAMPLE
	PS> 1,1000,100000 | Measure-Unit
	Name                           Value
	----                           -----
	Text
	Unit                           1
	Text
	Unit                           1
	Text                           kb
	Unit                           1024

.EXAMPLE
	PS> Measure-Unit 1mb -RoundDown
	Name                           Value
	----                           -----
	Text                           kb
	Unit                           1024

.EXAMPLE
	Measure-Unit 1500 2mb 100 -Long
	Name                           Value
	----                           -----
	Text                           kilobytes
	Unit                           1024
	Text                           megabytes
	Unit                           1048576
	Text                           bytes
	Unit                           1

.EXAMPLE
	Measure-Unit 1500 2mb 100 -TitleCase -BytesText
	Name                           Value
	----                           -----
	Text                           Kb
	Unit                           1024
	Text                           Mb
	Unit                           1048576
	Text                           B
	Unit                           1
#>

	[CmdletBinding()]
	Param(
			#get unnamed params for units
			[Parameter(
				Position = 0,
				ValueFromRemainingArguments = $True,
				Mandatory=$True,
				ValueFromPipeline=$True
				)
			]
			[Int[]]$Units,

			[Alias("RoundDown")]
			[Switch]$Lower = $False,

			[Switch]$BytesText = $False,

			[Alias("Capital", "Caps")]
			[Switch]$UpperCase = $False,

			[Switch]$TitleCase = $False,

			[Switch]$Long = $False
		 )

	Process
	{
		#init out array
		$OutItems = New-Object System.Collections.ArrayList

		ForEach( $Size in [Array]$Units )
		{
			$Size -= [Int][Bool]$Lower
			#dirty hack
			#if the value is lower by 1, lower unit is returned
			#cast to bool to int, $true = 1, $false = 0
			#definitely cleaner than an if() but possibly less... good

			#test units
			If( $Size -lt 1kb )
			{
				$Unit = 1
				$UnitText = ""
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

			If( $Long )
			{
				#if we want longer units, add "bytes"
				$UnitText += "bytes"
			}
			ElseIf( ! ($Size -lt 1kb) )
			{
				#otherwise, take the first letter and add "b"
				#to get kb, mb, etc.
				$UnitText = "$($UnitText[0])b"
			}
			ElseIf( $BytesText )
			{
				#and if it's small and you want output
				#give em "b" for "bytes"
				$UnitText = "b"
			}

			If( $UpperCase )
			{
				$UnitText = $UnitText.ToUpper();
			}
			ElseIf( $TitleCase )
			{
				#probably not the best way of doing this
				$UnitText = "$($UnitText.ToUpper()[0])$($UnitText.SubString(1))"
			}

			#add elem to out array, don't display keys
			$OutItems.Add(
				@{Unit = $Unit
				Text = $UnitText
			}) > $null
		}
		return $OutItems
	}
}

function Format-Unit
{

	[CmdletBinding()]
	Param(
			[Int]$Decimals = 2,

			[Parameter(
				Position = 0,
				ValueFromRemainingArguments = $True,
				AcceptFromPipeline = $True,
				Mandatory = $True
				)
			]
			[String[]]$Amounts

		 )

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
