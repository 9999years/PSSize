function Expand-Array
{
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline = $True
			)]
		$Array
		)

	Process {
		If( $Array -eq $Null )
		{
			Return
		}
		While( ($Array.Count -eq 1 -xor $Array[0].Count -eq 1) -and $Array.GetType().Name -eq "String" )
		{
			$Array = $Array[0]
		}
		Write-Output $Array
	}
}

function Expand-Together
{
<#
.SYNOPSIS
	Removes all nesting from an array, to make each key at the top level.

.DESCRIPTION
	E.g. an array
	[1,2,3,4,[5,6,7,[8,9,10]],11]
	would become
	[1,2,3,4,5,6,7,8,9,10,11].
	Useful for removing duplicate keys.
#>
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline = $True
			)]
		$Array
		)

	Begin {
		$OutArray = New-Object System.Collections.ArrayList
	}

	Process {
		$ExpandedArray = (Expand-Array $Array)
		ForEach($Key in $ExpandedArray) {
			If($Key.Count -ne 1)
			{
				Expand-Together $Key
			}
			Else
			{
				$OutArray.Add(
					$Key
					) > $Null
			}
		}
	}

	End {
		Write-Output $OutArray
	}
}

function Test-FileInfoEquality
{
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline = $True,
			Position = 0
			)]
		$First,

		[Parameter(
			Position = 1
			)]
		$Second
		)
	
	Process {
		If( $First -eq $Null -or
			$Second -eq $Null )
		{
			Write-Output $False
			#lol im sure this is fine
		}
		#If($First)
		ElseIf( $First -is [System.IO.DirectoryInfo] -or
				$Second -is [System.IO.DirectoryInfo] )
		{
			Write-Output $False
		}
		ElseIf( $First.FullName -eq $Second.FullName )
		{
			Write-Output $True
		}
		Else
		{
			Write-Output $False
		}
	}
}

function Remove-DirectoryEntries
{
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline = $True,
			ValueFromRemainingArguments = $True
			)]
		[System.IO.FileSystemInfo[]]$Array
	)

	Process {
		$ProcessedArray = New-Object System.Collections.ArrayList
		ForEach($File in $Array)
		{
			If($File.GetType().Name -ne "DirectoryInfo")
			{
				$ProcessedArray.Add($File) > $Null
			}
		}
		Write-Output $ProcessedArray
	}
}

function Remove-Duplicates
{
<#
.SYNOPSIS
	Removes duplicates from an array of FileSystemInfo objects.

.DESCRIPTION
	Removes duplicates from an array of FileSystemInfo objects. Make sure the array is sorted and not nested before calling Remove-Duplicates or you'll get all kinds of errors or bad results. Pipe it through Expand-Together if necessary.
#>
	[CmdletBinding()]
	Param(
		[Parameter(
			ValueFromPipeline = $True,
			ValueFromRemainingArguments = $True
			)]
		<#[System.Collections.ArrayList]#>[System.IO.FileSystemInfo[]]$Array
	)

	Process {

		$ProcessedArray = (Remove-DirectoryEntries $Array)

		$OutArray = New-Object System.Collections.ArrayList
		For($i = 0; $i -lt $ProcessedArray.Count; $i++)
		{
			If( ! (Test-FileInfoEquality -First $ProcessedArray[$i] -Second $ProcessedArray[$i+1]) -and
				! (Test-FileInfoEquality -First $ProcessedArray[$i] -Second $OutArray[-1]) )
			{
				$OutArray.Add($ProcessedArray[$i]) > $Null
			}
		}
		Write-Output $OutArray
	}
}

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
				Mandatory = $True,
				ValueFromRemainingArguments = $True,
				ValueFromPipeline = $True
				)
			]
			[UInt64[]]$Amounts,

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

<#
.SYNOPSIS
	Gives the appropriately formatted number for any byte amount

.DESCRIPTION
	Takes in an array of path values, sums all the file sizes and their
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
function Get-Size
{
	[CmdletBinding()]
	Param(
			[Parameter(
				Position = 0,
				ValueFromRemainingArguments = $True,
				ValueFromPipeline = $True
				)
			]
			$PathSpec = @(".\"),

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

			[Switch]$Force = $False,

			[Char]$FormatString = "N",

			[String]$PrefixText = "",

			[Switch]$Raw
		 )


	Begin{
		$Files = New-Object System.Collections.ArrayList
		$Directories = New-Object System.Collections.ArrayList
		If($PathSpec -isnot [String])
		{
			$PathSpec = ($PathSpec | Expand-Together | Sort-Object | Select-Object -Unique)
		}

		$FormatUnitOptions = "$(
			if($Decimals -ne 2) { "-Decimals $Decimals " }
			if($RoundDown) { "-RoundDown " }
			if($BytesText) { "-BytesText " }
			if($UpperCase) { "-UpperCase " }
			if($TitleCase) { "-TitleCase " }
			if($Long) { "-Long " }
			if($ExtraByteDigits) { "-ExtraByteDigits " }
			if($NoSpace) { "-NoSpace " }
			if($FormatString -ne "N") { "-FormatString $FormatString " }
			if($PrefixText -ne '') { "-PrefixText $PrefixText " }
			)"
	}

	Process{

		$ExpandedPathSpec = ($PathSpec | Expand-Array)

		ForEach($Path in $ExpandedPathSpec)
		{
			if( !(Test-Path $Path) )
			{
				Write-Warning "Nothing matches path ``$Path``"
				continue
			}

			Write-Verbose "Searching path ``$Path``"

			$Files.Add(
				( (Invoke-Expression ( "Get-ChildItem $Path -File -Recurse $(
					If($Force) { `"-Force`" }
				)" ) ) ) ) > $Null

			$Directories.Add(
				( (Invoke-Expression ( "Get-ChildItem $Path -Directory -Recurse $(
					If($Force) { `"-Force`" }
				)" ) ) ) ) > $Null
		}
	}

	End{
		$NewFiles = New-Object System.Collections.ArrayList
		$Files = (Expand-Together $Files | Sort-Object)
		$Directories = (Expand-Together $Directories | Sort-Object)
		#"`n`r" + ($Directories | Format-Table -HideTableHeaders -Property FullName -Auto | Out-String -Width ((Get-Host).UI.RawUI.WindowSize.Width-2)).Trim() | Write-Verbose
		$NewFiles = (Remove-Duplicates $Files)


		If($NewFiles.Count -eq 0)
		{
			Write-Warning "No files found."
			$ItemCount = 0
			$FileStats = 0
			$Average = 0
		}
		Else
		{
			$Duplicates = $Files.Count - $NewFiles.Count
			Write-Verbose "$($NewFiles.Count) files found$(If($Duplicates) { ", not including $Duplicates extra duplicate$( If($Duplicates -gt 1) { "s" } ) that occured in more than one path"}):"
			"`n`r" + ($NewFiles | Format-Table -HideTableHeaders -Property FullName -Auto | Out-String -Width ((Get-Host).UI.RawUI.WindowSize.Width-2)).Trim() | Write-Verbose
			$FileStats = ($NewFiles | Measure-Object -Property Length -Sum -Average -Minimum -Maximum)
		}

		Write-Verbose "Total bytes: $($FileStats.Sum)"

		#Sorry about this line:
		"`n`rAvg  : $(Invoke-Expression "Format-Unit $($FileStats.Average) $FormatUnitOptions")`n`rSum  : $(Invoke-Expression "Format-Unit $($FileStats.Sum) $FormatUnitOptions")`n`rMax  : $(Invoke-Expression "Format-Unit $($FileStats.Maximum) $FormatUnitOptions") `n`rMin  : $(Invoke-Expression "Format-Unit $($FileStats.Minimum) $FormatUnitOptions")" | Write-Verbose

		If( $Raw )
		{
			Write-Output $FileStats.Sum
		}
		Else
		{
			Write-Output (Invoke-Expression "Format-Unit $($FileStats.Sum) $FormatUnitOptions")
		}
	}
}
