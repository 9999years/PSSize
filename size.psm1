<#
.SYNOPSIS
	Gives the appropriate unit for any byte amount

.DESCRIPTION
	Takes in a list of numbers (of bytes) and returns an array of the appropriate unit for each value, with each element having a Text (a string like "mb" or "kb") and Unit (an int like 1024 or 1048576) key.
	Note that the default unit text for "bytes" is "", as bytes are usually written plain.
	Accepts pipeline input.

.PARAMETER Units
	An array of int values to be processed. Implicit in unnamed arguments if not specified.

.PARAMETER RoundDown
	Aliased as "Lower". If Measure-Unit is called with -RoundDown, the lower unit will always be used. E.g. 1576 would return kb rather than b.

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
function Measure-Unit
{
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
			[UInt64[]]$Units,

			[Alias("Lower")]
			[Switch]$RoundDown = $False,

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

			If( $RoundDown )
			{
				$Size /= 1024
			}

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
			Else
			{
				#for future-compatibility with 2044
				$Unit = 1024pb
				$UnitText = "exa"
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
		return [Array]$OutItems
	}
}

<#
.SYNOPSIS
	Gives the appropriately formatted number for any byte amount

.DESCRIPTION
	Takes in an array of int values of bytes and returns properly formatted units, like 1.54 mb.
	Note that the default unit text for "bytes" is "", as bytes are usually written plain.
	If only one number is passed in, only the object will be returned (not in an array).
	Accepts pipeline input.
	Note that byte values greater than 18446744073709551615 = 16 exabytes will not fit into a UInt64 and will cause a casting error.

.PARAMETER Units
	An array of int values to be processed. Implicit in unnamed arguments if not specified.

.PARAMETER RoundDown
	Aliased as "Lower". If Measure-Unit is called with -RoundDown, the lower unit will always be used. E.g. 1900000 would return 1,855.47 kb rather than 1.81 mb.

.PARAMETER BytesText
	By default, values >1024 will have no unit text. However, if -BytesText is passed, the unit text for bytes will be "b" (or "bytes" if passed in tandem with -Long).

.PARAMETER UpperCase
	Aliased as "Caps" and "Capital". If Measure-Unit is called with -UpperCase, unit text will be in uppercase. E.g. "MB" instead of "mb".

.PARAMETER TitleCase
	Capitalizes the first letter of each unit. Overriden by -UpperCase if both are passed.

.PARAMETER Long
	Enables un-abbreviated unit text output, E.g. "10 kilobytes" instead of "10 kb".

.PARAMETER FormatString
	A number formatting string, such as "D", "X", or "P". See msdn.microsoft.com/en-us/library/26etazsy.aspx for more information and a list of valid format strings.
	Note that if -FormatString is "X" the value will be rounded to the nearest integer.

.PARAMETER PrefixString
	A string to prefix the units with. If -FormatString is set to "X", -PrefixString will default to "0x"

.COMPONENT
	Measure-Unit

.EXAMPLE
	19999 | Format-Unit -Decimals 4 -Capital -Long
	19.5303 KILOBYTES

.EXAMPLE
	Format-Unit 1000 -ExtraByteDigits -Decimals 1 -BytesText
	1,000.0 b

.EXAMPLE
	Format-Unit 1024 -RoundDown -Long -TitleCase
	1,024 Bytes

.EXAMPLE
	 @(1025, 9999, 108085) | Format-Unit -Decimals 4
	105.5518 kb

.EXAMPLE
	Format-Unit @(5777, 233, 89999) -BytesText -FormatString "X" -NoSpace
	0x6kb
	0xE9b
	0x58kb
#>
function Format-Unit
{
	[CmdletBinding()]
	Param(
			[Parameter(
				Position = 0,
				ValueFromRemainingArguments = $True,
				ValueFromPipeline = $True,
				Mandatory = $True
				)
			]
			[System.UInt64[]]$Amounts,

			[Int]$Decimals = 2,

			[Switch]$ExtraByteDigits = $False,

			[Alias("Lower")]
			[Switch]$RoundDown = $False,

			[Switch]$BytesText = $False,

			[Alias("Capital", "Caps")]
			[Switch]$UpperCase = $False,

			[Switch]$TitleCase = $False,

			[Switch]$Long = $False,

			[Switch]$NoSpace = $False,

			[Char]$FormatString = "N",

			[String]$PrefixText
		 )

	Process
	{
		$OutItems = New-Object System.Collections.ArrayList
		[Array]$Units = Invoke-Expression "Measure-Unit $Amounts $(
			if($RoundDown) { "-RoundDown " }
			if($BytesText) { "-BytesText " }
			if($UpperCase) { "-UpperCase " }
			if($TitleCase) { "-TitleCase " }
			if($Long) { "-Long "}
			)"

		ForEach( $i in 0..($Amounts.Count - 1) )
		{
			If($Units[$i].Unit -eq 1 -and ! $ExtraByteDigits) {
				#Would be kinda weird to show 12.00 bytes
				$TempDecimals = 0
			}
			Else
			{
				$TempDecimals = $Decimals
			}

			$TempAmount = ($Amounts[$i] / $Units[$i].Unit)

			If(([String]$FormatString).ToUpper() -eq "X")
			{
				$PrefixString = "0x"
				$TempDecimals = $Null
				$TempAmount = [int]$TempAmount
			}

			$OutItems.Add(
				"$($PrefixString){0:$($FormatString)$($TempDecimals)}$(
				if( ! $NoSpace ) { " " }
				)$($Units[$i].Text)" -f
				$TempAmount
				) > $null
		}
		return $OutItems
	}
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

	$Items = Invoke-Expression "(Get-ChildItem $PathSpec -recurse $(if( $Force ){`"-Force`"}) | Measure-Object -property length -sum)"

	Write-Verbose "The cumulative size of all $($Items.Count) file$(if($Items.Count -ne 1){'s'}) matching $($PathSpec)"

	Write-Verbose (Invoke-Expression "([String](Get-ChildItem $PathSpec -recurse $(if( $Force ){`"-Force`"})))")
	$Average = $Items.sum/$Items.count
	Write-Verbose "(average of $(Format-Unit $Average) / file)"

	"$(Format-Unit $Items.sum)"

}
