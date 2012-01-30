## Copyright 2012 Robert Nees
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
$numArgs = $args.length
$x264 = "x264.exe"
$ffmpeg = "ffmpeg.exe"
$nero = "neroaacenc.exe"
$mp4box = "MP4Box.exe"
$tempDir = $env:TEMP + "\"
$wwwRoot = ""
$curFileName = ""
$inputDirectory = "d:\convert-from\"
$outputDirectory = "d:\convert-to\"
$convertFromExt = "*"
$convertToExt = ".m4v"
$convertPreset = "fast"
$convertFilter = "resize:width=480,height=320,fittobox=both,method=spline" # fastbilinear"
$convertFPS = 30 #23.976023
$convertTime = 0
$convertFrames = $convertTime * $convertFPS
$seek2Time = 21 * 60
$seek2Frame = $seek2Time * $convertFPS

$testConversion = $false

$mp3Only = $false
if ($numArgs -eq 1) {
    switch ($args[0]) {
        mp3 {
            write-host "Converting audio only to MP3"
            $mp3Only = $true;
        }
        default {
            write-host "Normal conversion to mp4 (mpg & acc)..."
            $mp3Only = $false
            $convertFromExt = $args[0]
        } 
    }
}

function startProcess ($cliCmd, $cmdArgs) {
	$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
	$ProcessInfo.FileName = $cliCmd
	$ProcessInfo.Arguments = $cmdArgs
	$ProcessInfo.UseShellExecute = $False
	$newProcess = [System.Diagnostics.Process]::Start($ProcessInfo)
    $newProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle
    $newProcess.WaitForExit()
}
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
}

$files=get-childitem $inputDirectory *.$convertFromExt
foreach ($file in $files) {
    write-host "!  Converting: " + $file

    write-host "From Ext = " $convertFromExt
    switch ($convertFromExt) {
        mkv {
`           $audioConvertExt = '.aac'
            write-host "mkv = " $audioConvertExt
        }
        mp4 {
            $audioConvertExt = '.aac'
            write-host "mp4 = " $audioConvertExt
        }
        avi {
            $audioConvertExt = '.mp3'
            write-host "avi = " $audioConvertExt
        }
        wmv {
            $audioConvertExt = '.wma'
            write-host "wmv = " $audioConvertExt
        }
        default {
            $audioConvertExt = '.mkv'
            write-host "default = " $audioConvertExt
        }    
    }
    write-host '.....' $audioConvertExt

    $baseName = $file.BaseName
    $convertToFullName = $wwwRoot + $outputDirectory + $baseName + $convertToExt
    if ($mp3Only -eq $false) {
        write-host $convertToFullName
        #            # " --fps " + $convertFPS + 
        $videoCMDLine = '"' + $file.FullName + '"' + " -o " + '"' + $tempDir + $baseName + "-foo.mp4" + '"' + `
            " --preset " + $convertPreset + `
            " --vf " + '"' + $convertFilter + '"' + " --quiet --level 3.0 --tune film --profile baseline --bitrate 256 --keyint 250  --trellis 0 --bframes 0 --b-adapt 0 --no-cabac " 

        if ($convertFrames -gt 0) {
            write-host "Partial Video Conversion"
            $videoCMDLine += " --frames " + [string]$convertFrames
        }
        if ($seek2Frame -gt 0) {
            write-host "Partial Video Conversion"
            $videoCMDLine += " --seek " + [string]$seek2Frame
        }

        # Convert video to h.264
        write-host $x264 $videoCMDLine
        startProcess $x264 ($videoCMDLine)
    }

    # Strip audio, output to mp3 or acc format
    $audioCMDLine1 = ' -y -loglevel quiet -i "' + $file.FullName + '" -vn -acodec copy'
    $audioCMDLine2 = ' -y -loglevel info -i "' + $tempDir + $baseName + '-foo' + $audioConvertExt + '"' + ' -ac 2 -ar 48000 -ab 56k -vn -strict experimental -acodec aac "' + $tempDir + $baseName + '-foo.aac"'

    $audioP1Options = ' -y -loglevel quiet -i "' + $file.FullName + '" -vn -acodec pcm_s32le -ac 6 -ar 48000 -f wav - '
    if ($convertTime -gt 0) {
        # write-host "Partial Audio Conversion"
        $audioP1Options = " -t " + $convertTime + ' ' +  $audioP1Options
    }
    if ($seek2Time -gt 0) {
        $audioP1Options = " -ss " + [string]$seek2Time + ' ' +  $audioP1Options        
    }

    $audioP2Options = ' -if - -q 0.15 -ignorelength -of "' + $tempDir + $baseName + '-foo.m4a"'

    & RawPipe.ps1 $ffmpeg $audioP1Options $nero $audioP2Options

    # mux the Video and Audio streams together
    if ($mp3Only -eq $false) {
        $convertToFullName = $wwwRoot + $outputDirectory + $baseName + $convertToExt
        $muxCMDLine = '-new -add "' + $tempDir + $baseName + '-foo.mp4' + '" -add "' + `
            $tempDir + $baseName + '-foo.m4a' + '" "' + $convertToFullName + '"'
        write-host $mp4box $muxCMDLine
        startProcess $mp4box ($muxCMDLine)
    }
    
    # clean up temp files
    # remove-item '"' + $tempDir + $baseName + '-foo.mp4"' 
    # remove-item '"' + $tempDir + $baseName + '-foo.mp3"' 
    # remove-item '"' + $tempDir + $baseName + '-foo.acc"' 
    
    write-host "!  Done"
    if ($testConversion) {
        write-host "You can now locally test the partially converted video: " + $convertToFullName
        break
    }
}
