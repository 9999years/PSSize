function Measure-Unit {
	If( $args[0] -eq "-help" -or
		$args[0] -eq "--help" -or
		$args[0] -eq "-?" -or
		$args[0] -eq $null )
	{
		"Takes in a list of numbers (of bytes) and returns an array"
		"of the appropriate unit for each value"
		"Note that the unit text for `"bytes`" is `"`", as bytes are"
		"usually written plain."
		"If only one number is passed in, only the object will be"
		"returned (not in an array)"
		"`n`rExample usage:"
		"PS>Measure-Unit 100 1500 1500000"
		"[0]: Text: "
		"     Unit: 1"
		"[1]: Text: kb"
		"     Unit: 1024"
		"[2]: Text: mb"
		"     Unit: 1048576"
		return
	}
	$OutItems = New-Object System.Collections.ArrayList
	ForEach( $Size in $args )
	{
		If( $Size -lt 1kb )
		{
			$Unit = 1
			$UnitText = ""
		}
		ElseIf( $Size -lt 1mb )
		{
			$Unit = 1kb
			$UnitText = "kb"
		}
		ElseIf( $Size -lt 1gb )
		{
			$Unit = 1mb
			$UnitText = "mb"
		}
		ElseIf( $Size -lt 1tb )
		{
			$Unit = 1gb
			$UnitText = "gb"
		}
		ElseIf( $Size -lt 1pb )
		{ #i hope nobody ever needs this
			$Unit = 1tb
			$UnitText = "tb"
		}
	$OutItems.Add(
			@{Unit = $Unit
			Text = $UnitText
			}) > $null
	}
	return $OutItems
}

function Format-Unit
{
	If( $args[0] -eq "-help" -or
		$args[0] -eq "--help" -or
		$args[0] -eq "-?" -or
		$args[0] -eq $null )
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
	ForEach( $Size in $args )
	{
		$Units = Measure-Unit $Size

		$Decimals = 2
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
