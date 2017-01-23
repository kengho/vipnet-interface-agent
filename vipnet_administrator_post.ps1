param([string]$FirstRun = "false", [string]$Debug = "false")

#https://gist.github.com/hsmalley/3836383
Function Get-IniContent ($filePath) {
  $ini = @{}
  switch -regex -file $FilePath {
    "^\[(.+)\]" { # Section
      $section = $matches[1]
      $ini[$section] = @{}
      $CommentCount = 0
    }
    "^(;.*)$" { # Comment
      $value = $matches[1]
      $CommentCount = $CommentCount + 1
      $name = "Comment" + $CommentCount
      $ini[$section][$name] = $value
    }
    "(.+?)\s*=(.*)" { # Key
      $name,$value = $matches[1..2]
      $ini[$section][$name] = $value
    }
  }
  return $ini
}

# reads INFOTECS.RE file
# returns vipnet network number
Function Get-NetworkNumber {
  $REFilePath = "C:\Program Files\InfoTeCS\ViPNet Administrator\NCC\INFOTECS.RE"
  If ([System.IO.File]::Exists($REFilePath)) {
    $REFileContent = Get-Content $REFilePath
    # 4-th line is network number
    return $REFileContent[3]
  }
  Else {
    echo "ERROR! Unable to find RE file C:\Program Files\InfoTeCS\ViPNet Administrator\NCC\INFOTECS.RE. Please make sure that ViPNet Administrator is installed."
    return
  }
}

$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$ini = Get-IniContent "$ScriptPath\vipnet_administrator_post.ini"
$CurlPath = $ini["settings"]["CurlPath"]
$NCCLogLastLineReadNumberPath = $ini["settings"]["NCCLogLastLineReadNumberPath"]
$WebAuthToken = $ini["settings"]["WebAuthToken"]
$WebPathNodename = $ini["settings"]["WebPathNodename"]
$NetworkNumber = Get-NetworkNumber
$OK_RESPONSE = "ok"
$NodenamePath = "C:\Program Files\InfoTeCS\ViPNet Administrator\NCC\DB\NODENAME.DOC"
$NCCLogPath="C:\Program Files\InfoTeCS\ViPNet Administrator\NCC\CCC.LOG"
$LockFilePath = "$ScriptPath\_lock"
$MessageRegexp = "(?<datetime>\d\d\.\d\d\.\d\d\s\d\d:\d\d:\d\d)\s(?<event>.*)$"
$CreateNodenameEvent = "Create DB\NodeName 0"

$Lock = Test-Path $LockFilePath
If ($Lock -eq "True") {
  If ($Debug -eq "true") {
  	Write-Host "lockfile is present, exiting"
  }
  return
}

$NCCLogLines = (Get-Content $NCCLogPath | measure-object -line).Lines

If ($FirstRun -eq "true") {
  $NCCLogLines > $NCCLogLastLineReadNumberPath

  If ($Debug -eq "true") {
    Write-Host "$CurlPath -s --max-time 50 -X POST -F "file=@$NodenamePath" -F "network_vid=$NetworkNumber" -H "Authorization: Token token=$WebAuthToken" $WebPathNodename"
  }

  $Response = &$CurlPath -s --max-time 50 -X POST -F "file=@$NodenamePath" -F "network_vid=$NetworkNumber" -H "Authorization: Token token=$WebAuthToken" $WebPathNodename
  If (-Not ($Response -eq $OK_RESPONSE)) {
	  Write-Host $Response
	  return
  }
  Write-Host $Response
  return
}

$NCCLogLastLineReadNumber = Get-Content $NCCLogLastLineReadNumberPath
[int]$NCCLogLastLineReadNumber = [convert]::ToInt32($NCCLogLastLineReadNumber, 10)

# in case of CCC.log overflow
if ($NCCLogLines -lt $NCCLogLastLineReadNumber) {
  If ($Debug -eq "true") {
  	Write-Host "NCCLogLines = $NCCLogLines > NCCLogLastLineReadNumber = $NCCLogLastLineReadNumber"
  }
  $NCCLogLastLineReadNumber = 0
  $NCCLogLastLineReadNumber - 10 > $NCCLogLastLineReadNumberPath
  If ($Debug -eq "true") {
  	Write-Host "NCCLogLastLineReadNumber := 0 written to $NCCLogLastLineReadNumberPath"
  }
}

$NCCLogPreviouslyUnreadMessages = @(Get-Content $NCCLogPath | select -skip $NCCLogLastLineReadNumber)
$NCCLogPreviouslyUnreadMessagesLength = $NCCLogPreviouslyUnreadMessages.length
If ($Debug -eq "true") {
	Write-Host "NCCLogPreviouslyUnreadMessages.length = $NCCLogPreviouslyUnreadMessagesLength"
}

If ($NCCLogPreviouslyUnreadMessagesLength -gt 0) {
  If ($Debug -eq "true") {
  	Write-Host "creating lock file $LockFilePath"
  }
  New-Item "$LockFilePath" -type file
  ForEach ($NCCLogPreviouslyUnreadMessage in $NCCLogPreviouslyUnreadMessages) {
    If ($Debug -eq "true") {
    	Write-Host "processing message $NCCLogPreviouslyUnreadMessage"
    }
  	if ($NCCLogPreviouslyUnreadMessage -match $MessageRegexp) {
      If ($Debug -eq "true") {
      	Write-Host "$NCCLogPreviouslyUnreadMessage matches $MessageRegexp"
      }
  		$Datetime = $matches.datetime
      If ($Debug -eq "true") {
      	Write-Host "Datetime = $Datetime"
      }
  		If ($matches.event -eq $CreateNodenameEvent) {
        If ($Debug -eq "true") {
        	$event = $matches.event
        	Write-Host "$event is equal $CreateNodenameEvent"
        	Write-Host "curling:"
        	Write-Host "$CurlPath -s --max-time 50 -X POST -F 'file=@$NodenamePath' -F 'network_vid=$NetworkNumber' -H 'Authorization: Token token=$WebAuthToken' $WebPathNodename"
        }
  			$Response = &$CurlPath -s --max-time 50 -X POST -F "file=@$NodenamePath" -F "network_vid=$NetworkNumber" -H "Authorization: Token token=$WebAuthToken" $WebPathNodename
        If ($Debug -eq "true") {
        	Write-Host "Response from curl = $Response"
        }
  		}
  		Else {
  			$Response = $OK_RESPONSE
  		}
      If ($Debug -eq "true") {
      	Write-Host "Response = $Response"
      }
  		If ($Response -eq $OK_RESPONSE) {
  			$NCCLogLastLineReadNumber += 1
  			$NCCLogLastLineReadNumber > $NCCLogLastLineReadNumberPath
        If ($Debug -eq "true") {
        	Write-Host "NCCLogLastLineReadNumber++ ($NCCLogLastLineReadNumber) written to $NCCLogLastLineReadNumberPath"
        }
  		}
  		Else {
        If ($Debug -eq "true") {
        	Write-Host "removing lock file $LockFilePath"
        }
        Remove-Item "$LockFilePath"
  			return
  		}
  	}
  	Else {
  		$NCCLogLastLineReadNumber += 1
  		$NCCLogLastLineReadNumber > $NCCLogLastLineReadNumberPath
      If ($Debug -eq "true") {
      	Write-Host "NCCLogLastLineReadNumber++ ($NCCLogLastLineReadNumber) written to $NCCLogLastLineReadNumberPath"
      }
  	}
  }
  If ($Debug -eq "true") {
  	Write-Host "removing lock file $LockFilePath"
  }
  Remove-Item "$LockFilePath"
}
