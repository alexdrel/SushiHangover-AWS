<#
.NOTES
Copyright 2012 Robert Nees
Licensed under the Apache License, Version 2.0 (the "License");
http://sushihangover.blogspot.com

Preset = ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo.
Tune = film, animation, grain, stillimage, psnr, ssim, fastdecode, zerolatency

.SYNOPSIS
iPhone/iPod movie converter
.DESCRIPTION
This script preforms a local iPhone/iPod movie conversions via h264, ffmpeg and 
mp4box that creates iTunes importable movies. Of course the 'easy/faster' way to 
sync these converted movies is to use iTunnel or SSH or drag & drop via iFunBox

.EXAMPLE
iConvert.ps1 -name Birthday.mkv -preset slow -bitrate 128 -start 0 -length 0 -shutdown $false
.EXAMPLE
iconvert.ps1 -name .\My_Movie.avi -preset veryfast -fps 25
.LINK
http://sushihangover.blogspot.com
#>
[CmdletBinding(DefaultParameterSetName="Help")]
Param (
        [parameter(
            parametersetname="Help")]
            [switch]$help,
        [parameter(
            parametersetname="All",
            mandatory=$true,
            position=1)]
            [Alias("name")]
            [string]$convertName,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=2)]
            [Alias("preset")]
            [string]$convertPreset = "ultrafast",
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=3)]
            [Alias("bitrate")]
            [int]$convertBitRate = 128,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=4)]
            [Alias("fps")]
            [string]$convertFPS = '23.976023',
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=5)]
            [Alias("start")]
            [int]$startTime = 0,
        [parameter(
            parametersetname="All",
            mandatory=$false,
            position=6)]
            [Alias("length")]
            [int]$convertTime = 0,
        [parameter(
            parametersetname="All")]
            [switch]$shutdown
)
if ($help.IsPresent) {
    help ($MyInvocation.MyCommand.Name) -examples
    exit
}

$numArgs = $args.length
$x264 = "x264.exe"
$ffmpeg = "ffmpeg.exe"
$nero = "neroaacenc.exe"
$mp4box = "MP4Box.exe"
$ffprobe = "ffprobe.exe"
$tempDir = $env:TEMP + "\"
$wwwRoot = ""
$curFileName = ""
$inputDirectory = "d:\convert-from\"
$outputDirectory = "d:\convert-to\"
$convertFromExt = "*"
$convertToExt = ".mp4"
$convertFilter = "resize:width=480,height=320,fittobox=both,method=spline" # fastbilinear" #

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
    $files = get-childitem ([Management.Automation.WildcardPattern]::Escape($convertName)) *
} elseif (test-path $convertName -pathType leaf) {
    $files += get-childitem ([Management.Automation.WildcardPattern]::Escape($convertName))
} else {
    $files = $null
}

foreach ($file in $files) { 
    # Need to write a metadata routine to pull basic info and extended attributes like FPS...
    $probeCMDLine = ' -prefix -show_streams -i "' + $file.FullName + '"'
    $stdOut = Do-StartProcess.ps1 $ffprobe $probeCMDLine
    $a = $stdOut -like "r_frame_rate*"
    $a = $a | sort
    $convertFPS = Invoke-Expression $a[1].replace('r_frame_rate=','')

    $convertFromExt = $file.Extension

    $baseName = $file.BaseName
    $convertToFullName = $wwwRoot + $outputDirectory + $baseName + $convertToExt

    #            # " --fps " + $convertFPS + 
    $videoCMDLine = '"' + $file.FullName + '"' + " -o " + '"' + $tempDir + $baseName + "-foo.mp4" + '"' + `
        " --fps " + $convertFPS + " --preset " + $convertPreset + `
        " --vf " + '"' + $convertFilter + '"' + " --quiet --level 3.0 --profile baseline " + ` # --bitrate " + ` 
        # $convertBitRate + 
        " --threads auto --tune film --bframes 0 --no-b-adapt --no-cabac --me hex --crf 25 " # --sar 1:1 "

    if ($convertFrames -gt 0) {
        write-host "Partial Video Conversion : Length"
        $videoCMDLine += " --frames " + [string]$convertFrames
    }
    if ($seek2Frame -gt 0) {
        write-host "Partial Video Conversion : Starting Position"
        $videoCMDLine += " --seek " + [string]$seek2Frame
    }

    # Convert video to h.264
    Do-StartProcess.ps1 $x264 $videoCMDLine
    # $conversionVideoJob = start-job -ScriptBlock { Do-StartProcess.ps1 $args[0] $args[1] } -ArgumentList $x264, $videoCMDLine
    # Do-CtrlCWatch.ps1 ($conversionVideoJob)

    $audioP1Options = ' -y -loglevel quiet -i "' + $file.FullName + '" -vn -acodec pcm_s32le -ac 2 -ar 44100 -f wav '
    if ($convertTime -gt 0) {
        $audioP1Options += "-t " + [string]$convertTime # + ' ' +  $audioP1Options
    }
    if ($seek2Time -gt 0) {
        $audioP1Options += "-ss " + [string]$seek2Time # + ' ' +  $audioP1Options        
    }
    $audioP1Options += " - "

    $audioP2Options = ' -if - -q 0.15 -ignorelength -of "' + $tempDir + $baseName + '-foo.m4a"'

$audioP1Options
$audioP2Options
    RawPipe.ps1 $ffmpeg $audioP1Options $nero $audioP2Options
    # $conversionAudioJob = start-job -ScriptBlock { RawPipe.ps1 $args[0] $args[1] $args[2] $args[3]   } -ArgumentList $ffmpeg, $audioP1Options, $nero, $audioP2Options
    # Do-CtrlCWatch.ps1 ($conversionAudioJob)

    # mux the Video and Audio streams together
    $convertToFullName = $wwwRoot + $outputDirectory + $baseName + $segmentNo + $convertToExt
    $muxCMDLine = '-ipod -new -add "' + $tempDir + $baseName + '-foo.mp4' + ':fps=' + $convertFPS + '" -add "' + `
    $tempDir + $baseName + '-foo.m4a' + ':fps=' + $convertFPS + '" "' + $convertToFullName + '"'
    Do-StartProcess.ps1 $mp4box $muxCMDLine
    
    # clean up temp files
    remove-item ([Management.Automation.WildcardPattern]::Escape($tempDir + $baseName + '-foo.mp4'))
    remove-item ([Management.Automation.WildcardPattern]::Escape($tempDir + $baseName + '-foo.m4a'))
}
## Optional System shutdown
if ($shutdown.IsPresent) {
    Do-shutdown.ps1 1
}