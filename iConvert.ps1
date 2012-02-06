## Copyright 2012 Robert Nees
## Licensed under the Apache License, Version 2.0 (the "License");
## http://sushihangover.blogspot.com
##
Param (
        [parameter(
            parametersetname="All",
            mandatory=$true,
            position=1)]
            [string]$convertName,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=2)]
            [string]$convertPreset = "fast",
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=3)]
            [int]$convertBitRate = 192,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=4)]
            [int]$startTime = 0,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=5)]
            [int]$convertTime = 0
)
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
$convertToExt = ".mp4"
$convertFilter = "resize:width=480,height=320,fittobox=both,method=fastbilinear" #spline" # 
$convertFPS = 23.976023
#$convertTime = 0 # 60 * 3 # 60 * 10 * 4
$convertFrames = $convertTime * $convertFPS
$segmentNo = 0
if ($segmentNo -gt 0) {
    $seek2Time = ($convertTime * $segmentNo ) - (($segmentNo - 1) * $convertFPS)
} else {
    $seek2Time = $startTime
}
$seek2Frame = ($seek2Time * $convertFPS) 

# test if directory or individual file
$files = @()
if (test-path $convertName -pathType container) {
    $files = get-childitem $convertName *
} elseif (test-path $convertName -pathType leaf) {
    $files += get-childitem $convertName
} else {
    $files = $null
}

foreach ($file in $files) {
    write-host "!  Converting: " + $file
    $convertFromExt = $file.Extension

    $baseName = $file.BaseName
    $convertToFullName = $wwwRoot + $outputDirectory + $baseName + $convertToExt

    write-host $convertToFullName
    #            # " --fps " + $convertFPS + 
    $videoCMDLine = '"' + $file.FullName + '"' + " -o " + '"' + $tempDir + $baseName + "-foo.mp4" + '"' + `
        " --fps " + $convertFPS + " --preset " + $convertPreset + `
        " --vf " + '"' + $convertFilter + '"' + " --quiet --level 3.0 --profile baseline --tune film --bitrate " + $convertBitRate + " --bframes 0 --no-b-adapt --no-cabac --me umh -m 7 -A all --crf 23 --sar 1:1 "
        #--crf 26 --ref 1 --threads 2 --keyint 250 --min-keyint 25 --qpmin 22 --qpmax 51 --qpstep 4 "

    if ($convertFrames -gt 0) {
        write-host "Partial Video Conversion : Length"
        $videoCMDLine += " --frames " + [string]$convertFrames
    }
    if ($seek2Frame -gt 0) {
        write-host "Partial Video Conversion : Starting Position"
        $videoCMDLine += " --seek " + [string]$seek2Frame
    }

    # Convert video to h.264
    . Do-StartProcess.ps1
    startProcess $x264 $videoCMDLine

    $audioP1Options = ' -y -loglevel quiet -i "' + $file.FullName + '" -vn -acodec pcm_s32le -ac 6 -ar 48000 -f wav '
    if ($convertTime -gt 0) {
        $audioP1Options += "-t " + [string]$convertTime # + ' ' +  $audioP1Options
    }
    if ($seek2Time -gt 0) {
        $audioP1Options += "-ss " + [string]$seek2Time # + ' ' +  $audioP1Options        
    }
    $audioP1Options += " - "

    $audioP2Options = ' -if - -q 0.15 -ignorelength -of "' + $tempDir + $baseName + '-foo.m4a"'

    & RawPipe.ps1 $ffmpeg $audioP1Options $nero $audioP2Options

    # mux the Video and Audio streams together
    $convertToFullName = $wwwRoot + $outputDirectory + $baseName + $segmentNo + $convertToExt
    $muxCMDLine = '-new -add "' + $tempDir + $baseName + '-foo.mp4' + ':fps=' + $convertFPS + '" -add "' + `
    $tempDir + $baseName + '-foo.m4a' + ':fps=' + $convertFPS + '" "' + $convertToFullName + '"'
    startProcess $mp4box ($muxCMDLine)
    
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
