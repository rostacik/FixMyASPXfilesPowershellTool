[CmdletBinding()]
param(
  [string]$file, #run against particular file,
  [string]$folder #run against particular folder, if not specified current work folder will be used
)

#get all .aspx files
function Get-AllAspx {
	[CmdletBinding()]
	Param($folder = $PSScriptRoot)

	Process {
		#$folder
		#Get-ChildItem "$folder" -Recurse -Include "*.aspx"
		dir $folder -filter "*.aspx" -rec
	}
 }

#generic replacing snippet
function My-ReplaceText {
	[CmdletBinding()]
	Param([array]$fileContent, [string]$oldString, [string]$newString)

	Process {
		#$fileName
		return ($fileContent | Foreach-Object {$_ -replace $oldString, $newString})
	}
} 

#find row that starts with string specified, replace it with new string
function My-ReplaceRowThatStartsWith {
	[CmdletBinding()]
	Param([array]$fileContent, [string]$startsWithString, [string]$newString)

	Process {
		$wantedRow = $fileContent | Where-Object { ([string]$_).StartsWith($startsWithString) }
		
		if ($wantedRow) {
			$fileContent = $fileContent.Replace($wantedRow, $newString)
		}

		return $fileContent
	}
}

#generic removing snippet
function My-RemoveText {
	[CmdletBinding()]
	Param([array]$fileContent, [string]$removeString)

	Process {
		#$fileName
		return ($fileContent | select-string -pattern $removeString -notmatch)
	}
 }

#generic move snippet
function My-MoveText {
	[CmdletBinding()]
	Param([array]$fileContent, [string]$whatString, [string]$whereString)

	Process {
		#zero length check
		if ($fileContent.Length -gt 0) {
			$foundMatches = @($fileContent | select-string -pattern $whatString)
		
			if ([regex]::Matches($fileContent, "</body>", "SingleLine,IgnoreCase").Count -eq 1) {
				$foundMatches | Foreach-Object { $fileContent = ($fileContent | select-string -pattern $_ -notmatch) }

				$foundMatches += "</body>"

				$foundMatches | Foreach-Object { $foundMatchesProp += ([string]$_ + [System.Environment]::NewLine) }

				return ($fileContent -replace "</body>", ($foundMatchesProp))
			}
			else { throw "Houston, Houston, we have a problem here. None or more than one closing body tag found for file : " + $fileName }
		}
		else { throw "Found file with zero file length - skipping. File name : " + $fileName }
	}
 }

#return rows from string as array matched to pattern
function My-GetRowsFromPattern {
	[CmdletBinding()]
	Param([Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]$fileContent, [string]$patternString)

	Process {
		$fileContent | select-string -pattern $patternString
	}
}

#replace old html4 head with html5 one
function My-FixHead {
	[CmdletBinding()]
	Param([Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][array]$fileContent)

	Process {
		Write-Verbose "fixing head tag"

		if ($fileContent) {
			return My-ReplaceRowThatStartsWith -fileContent $fileContent -startsWithString "<!DOCTYPE HTML " -newString "<!DOCTYPE html>"
		}
	}
 }

#fix namespace in html starting tag
function My-FixHTMLNamespace {
	[CmdletBinding()]
	Param([Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][array]$fileContent)

	Process {
		Write-Verbose "fixing html namespace"

		if ($fileContent) {
			return My-ReplaceRowThatStartsWith -fileContent $fileContent -startsWithString "<html xmlns=" -newString "<html>"
		}
	}
 }

#replace starting body tag with possible scroll empty tag
function My-ReplaceBodyStartTag {
	[CmdletBinding()]
	Param([array]$fileContent)

	Process {
		Write-Verbose "fixing body start tag"
		#$fileName
		return My-ReplaceText -fileContent $fileContent -oldString "(<body\b[^>]*>)" -newString '<body>'
	}
 }

#remove head meta tag
function My-ReplaceHeadMetaTag {
	[CmdletBinding()]
	Param([array]$fileContent)

	Process {
		Write-Verbose "deleting old vs meta tag"
		#$fileName
		return My-RemoveText -fileContent $fileContent -removeString "name=""vs_targetSchema"""
	}
 }

#all scripts down to page
function My-MoveScriptsToBottomOfThePage {
	[CmdletBinding()]
	Param([array]$fileContent)

	Process {
		Write-Verbose "moving script references down - speed optimization"

		try {
			My-MoveText -fileContent $fileContent -whatString "(<script\b[^>]*>((.)*?)</script>)" -whereString "</body>"
		}
		catch {
			"error while moving scripts to the bottom of page"
		}
	}
 }

#returns rows with 
function My-GetAllIDs {
	[CmdletBinding()]
	Param([Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]$fileContent, [array]$exclTags)

	Process {
		return $fileContent | My-GetRowsFromPattern -patternString "(?i)(id)=""(.*?)""" | My-FindIDsInString -excludedTags $exclTags
	}
}

#find IDs in string row, exclude search if one of excludeTags present
function My-FindIDsInString {
	[CmdletBinding()]
	Param([Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$fileRow, [array]$excludedTags)

	Process {
		$foundExcludedTags = $excludedTags | Where-Object { $fileRow.Contains("<" + $_) }

		if (-not $foundExcludedTags) {

			$splittedRow = $fileRow.Split("""").Split("'")

			for ($i=0; $i -le $splittedRow.Length - 1; $i++) {

				if ($splittedRow[$i] -imatch "id=") {
					return $splittedRow[$i + 1]
				}
			}
		}
	}
}

#testing of found row with token for suitabilitz of replacing
function My-LineSearchForBannedToken {
	[CmdletBinding()]
	Param([Parameter(Mandatory=$True)][string]$rowToAnalyze, [array]$bannedTokens = @("<cond>", "<!-- ", "//", "* *", "**", " * "))

	Process {
		if ($rowToAnalyze) {
			$bannedTokens | % {
				if ($rowToAnalyze.Contains($_)) {
					return 1
				}
			}
			return 0
		}
		else {
			return 0
		}
	}
}

#swap all calls in JS code from reference by ID to more propper way
function My-SwapIDsInJSToJsFwCalls {
	[CmdletBinding()]
	Param([array]$fileContent)

	Process {
		Write-Verbose "fixing calls to plain IDs in JS code"

		$exclTags = @("navjoin", "p2plus:DataSrc", "NavView", "p2plus:Func", "values")
		$uniqueIDs = $fileContent | My-GetAllIDs -exclTags $exclTags | Select -Unique

		$uniqueIDs | Foreach-Object {
			
			$currentUniqueID = $_
			write-Verbose $currentUniqueID

			$uniqueIdRows = ($fileContent | select-string -pattern ("(?i)(.*)( (" + $_ + ")\.\b)" ))

			write-Verbose $uniqueIdRows.Count
			
			$uniqueIdRows | % {
				if (-not (My-LineSearchForBannedToken -rowToAnalyze $_)) {
					#we have row that could be replaced

					$newRow = $_ -replace $currentUniqueID, ("fwModule.getById(""" + $currentUniqueID + """)")

					write-Verbose $newRow

					$fileContent = $fileContent -replace $_, $newRow
				}
			}
		}

		return $fileContent
	}
}

#checking the file
function My-FileCheck {
	[CmdletBinding()]
	Param([Parameter(Mandatory=$True)][string]$fileName)

	Process {
		#we have some input, lets test it
		if ((Test-Path $fileName) -and ($fileName.ToLower().EndsWith(".aspx"))) {
			return 1
		}
		else {
			return 0
		}			
	}
}

#remove msthemecompatible head tag
function My-RemoveThemeCompatible {
	[CmdletBinding()]
	Param([array]$fileContent)

	Process {
		Write-Verbose "deleting row with old http-equiv=MSThemeCompatible"
		#$fileName
		return My-RemoveText -fileContent $fileContent -removeString "=""MSThemeCompatible"""
	}
}

#program "main" function
"welcome to the wonderful world of automated .aspx files fixing. sit back, get a coffee or even better, run this during the night, it takes some time (lots of regexing on single core). friendly reminder - check all changes I made to the files, mostly I mess up JS code, sry guys, I did what I could. enjoy.`nPS> say good bye to one of your cores`n`n"

if (($file) -and -not ($folder)) {
	#woohoo, we have a file here
	("running against file : " + $file)

	if (My-FileCheck -fileName $file) {
		$whatToProcess = dir $file
	}
	else {
		write-error "awkward.... either we are unable to find file, or you didn't specified file that has .aspx extension, please try again"
	}
}
elseif (($folder) -and -not ($file)) {
	#folder specified
	("folder specified : " + $folder)
	$whatToProcess = Get-AllAspx -folder $folder
	
}
elseif (($file) -and ($folder)) {
	write-Error "both parameter specified at the same time"
}
else {
	#default work folder will be used
	$whatToProcess = Get-AllAspx
}

if ($whatToProcess) {
$whatToProcess | % {
		if ($_.FullName) {
			$whenWeStarted = [DateTime]::Now
			#log to console file name processed
			("currently messing up : " + $_.FullName + "`n")

			#load content
			$fileContent = (get-content $_.FullName -Encoding utf8)

			#zero length check
			if ($fileContent) {
				#process
				$fileContent = (My-FixHead -fileContent $fileContent)
				$fileContent = (My-RemoveThemeCompatible -fileContent $fileContent)
				$fileContent = (My-FixHTMLNamespace -fileContent $fileContent)
				$fileContent = (My-ReplaceBodyStartTag -fileContent $fileContent)
				$fileContent = (My-ReplaceHeadMetaTag -fileContent $fileContent)
				$fileContent = (My-MoveScriptsToBottomOfThePage -fileContent $fileContent)
				$fileContent = (My-SwapIDsInJSToJsFwCalls -fileContent $fileContent)

				#save the stuff
				Set-Content $_.FullName $fileContent -Encoding utf8
			}

			("wow, done, finished in just : " + ([DateTime]::Now - $whenWeStarted))
		}
		else {
			write-Error ("no FullName property found")
		}
	}
}

("exiting, bye")