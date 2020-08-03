<#
.SYNOPSIS
  Test Internet Speed using the SpeedTest.net CLI
.DESCRIPTION
  Tests the speed  of your internet connection 
  Has minimum speed parameters
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  Not a funtion as of yet, this is just an MVP
.OUTPUTS
  Log file stored in $PSScriptRoot\$LogFileDirectory
.NOTES
  Version:        1.4
  Author:         Ben Therien
  Credit to:      Kelvin Tegelaar gave the guts to this script.  https://www.cyberdrain.com/monitoring-with-powershell-monitoring-internet-speeds/
  Creation Date:  <Date>
  Link to Repo: https://github.com/Inventologist/Test-InternetSpeed
  Purpose/Change: First Upload / MVP
  
.EXAMPLE
  Copy this script and run it in a directory of its own.
  Change the following variables to the values that suit your connection:
  $MinimumDownloadSpeed
  $MinimumUploadSpeed
  $MaxPacketLoss
  $CycleWaitTime

  Enjoy!!
#>

cls

#####################
# Monitoring values #
#####################
$MaxPacketLoss = 2 #How much % packetloss until an alert. 
$MinimumDownloadSpeed = 100 #What is the minimum expected download speed in Mbit/s
$MinimumUploadSpeed = 5 #What is the minimum expected upload speed in Mbit/s
 
#Download Location
#Latest version can be found at: https://www.speedtest.net/nl/apps/cli
$DownloadURL = "https://bintray.com/ookla/download/download_file?file_path=ookla-speedtest-1.0.0-win64.zip"
$DownloadLocation = "$PSScriptRoot\SpeedtestCLI-DL"

#Time to wait between cycles (seconds)
$CycleWaitTime = 120

#Create LogFile and Associated Paths
$TimeDateStamp = (Get-Date -format "MM-dd-yyyy-HH_mm_ss")
$LogfileName = "SpeedTest-$TimeDateStamp"
$LogFileDirectory = "LogFiles"
$LogFilePath = "$PSScriptRoot\$LogFileDirectory\$LogFileName" + ".csv"
IF (!(Test-Path $PSScriptRoot\$LogFileDirectory)) {New-Item -ItemType Directory -Path $PSScriptRoot\$LogFileDirectory}

#Announce Parameters
Write-Host "#######################"
Write-Host "# Internet Speed Test #"
Write-Host "#######################"
Write-Host ""
Write-Host -no "Minimum Download Speed: ";Write-Host $MinimumDownloadSpeed -f Green
Write-Host -no "Minimum Upload Speed: ";Write-Host $MinimumUploadSpeed -f Green
Write-Host -no "Maximum Packet Loss: ";Write-Host $MaxPacketLoss -f Green
Write-Host ""
Write-Host -no "LogFile Location: ";Write-Host $LogFilePath -f Green

################
# Download EXE #
################

try {
    $TestDownloadLocation = Test-Path $DownloadLocation
    if (!$TestDownloadLocation) {
        New-Item $DownloadLocation -ItemType Directory -force
        Invoke-WebRequest -Uri $DownloadURL -OutFile "$($DownloadLocation)\speedtest.zip"
        Expand-Archive "$($DownloadLocation)\speedtest.zip" -DestinationPath $DownloadLocation -Force
    } 
}

catch {  
    write-host "The download and extraction of SpeedtestCLI failed. Error: $($_.Exception.Message)"
    exit 1
}

##########################
# Perform Test in a Loop #
##########################

While ($true) {

    #Grab Previous Results if they exist
    $PreviousResults = if (test-path "$($DownloadLocation)\LastResults.txt") { get-content "$($DownloadLocation)\LastResults.txt" | ConvertFrom-Json }
    
    Write-Host ""
    Write-Host "Performing Test" -f Green
    
    #Run the Speedtest
    $SpeedtestResults = & "$($DownloadLocation)\speedtest.exe" --format=json --accept-license --accept-gdpr
    
    #Save current results to LastResults 
    $SpeedtestResults | Out-File "$($DownloadLocation)\LastResults.txt" -Force
    
    ########################
    # Convert Test Results #
    ########################
    
    Write-Host "Converting Test Results" -f Yellow   

    #Grab JSON Results
    $SpeedtestResults = $SpeedtestResults | ConvertFrom-Json
 
    #Create SpeedTest Object
    [PSCustomObject]$SpeedtestObj = @{
        downloadspeed = [math]::Round($SpeedtestResults.download.bandwidth / 1000000 * 8, 2)
        uploadspeed   = [math]::Round($SpeedtestResults.upload.bandwidth / 1000000 * 8, 2)
        packetloss    = [math]::Round($SpeedtestResults.packetLoss)
        isp           = $SpeedtestResults.isp
        ExternalIP    = $SpeedtestResults.interface.externalIp
        InternalIP    = $SpeedtestResults.interface.internalIp
        UsedServer    = $SpeedtestResults.server.host
        ResultsURL    = $SpeedtestResults.result.url
        Jitter        = [math]::Round($SpeedtestResults.ping.jitter)
        Latency       = [math]::Round($SpeedtestResults.ping.latency)
    }

    ###################
    # Analyze Results #
    ###################

    $SpeedtestHealth = @()

    #Comparing against previous result. Alerting is download or upload differs more than 20%.
    if ($PreviousResults) {
        if ($PreviousResults.download.bandwidth / $SpeedtestResults.download.bandwidth * 100 -le 80) { $SpeedtestHealth += "Download speed difference is more than 20%" }
        if ($PreviousResults.upload.bandwidth / $SpeedtestResults.upload.bandwidth * 100 -le 80) { $SpeedtestHealth += "Upload speed difference is more than 20%" }
    }
    
    ##################################
    # Monitoring Values Comparisions #
    ##################################

    #Comparing against preset variables.
    if ($SpeedtestObj.downloadspeed -lt $MinimumDownloadSpeed) { $SpeedtestHealth += "Download speed is lower than $MinimumDownloadSpeed Mbit/s" }
    if ($SpeedtestObj.uploadspeed -lt $MinimumUploadSpeed) { $SpeedtestHealth += "Upload speed is lower than $MinimumUploadSpeed Mbit/s" }
    if ($SpeedtestObj.packetloss -gt $MaxPacketLoss) { $SpeedtestHealth += "Packetloss is higher than $MaxPacketLoss%" }
    
    #If nothing is inside of the $SpeedtestHealth, set it to "Healthy"
    if (!$SpeedtestHealth) {$SpeedtestHealth = "Healthy"}

    #Display the Test Results
    Write-Host -no "Test Results: " -f Yellow
    If ($SpeedtestHealth -eq "Healthy") {
        Write-Host "Healthy" -f Green
    } ELSE {
        Write-Host "Issues to report..." -f Red
        $SpeedtestHealth | Format-Table
        IF ($SpeedtestHealth -Contains "Download Speed is lower than $($MinimumDownloadSpeed) Mbit/s") {
            Write-Host -no "Download Speed: " -f Yellow
            Write-Host "$($SpeedtestObj.downloadspeed) Mbit/s"
        }
        IF ($SpeedtestHealth -Contains "Upload Speed is lower than $($MinimumUploadSpeed) Mbit/s") {
            Write-Host -no "Download Speed: " -f Yellow
            Write-Host "$($SpeedtestObj.uploadspeed) Mbit/s"
        }
    }

    #LogFile Output
    Write-Host "Outputting to LogFile" -f Gray
    $TimeDateStamp = (Get-Date -format "MM-dd-yyyy-HH_mm_ss")
    
    $LogFileEntry = [PSCustomObject]@{
        'TimeDateStamp' = $TimeDateStamp
        'ExternalIP' = $SpeedtestObj.ExternalIP
        'InternalIP' = $SpeedtestObj.InternalIP
        'ISP' = $SpeedtestObj.isp
        'Latency' = $SpeedtestObj.Latency
        'Packet Loss' = $SpeedtestObj.packetloss
        'Download Speed' = $SpeedtestObj.downloadspeed
        'Upload Speed' = $SpeedtestObj.uploadspeed
        'ResultsURL' = $SpeedtestObj.ResultsURL
        'UsedServer' = $SpeedtestObj.UsedServer
        'Jitter' = $SpeedtestObj.Jitter
        'SpeedTestHealth' = $SpeedtestHealth
    }

    #LogFile Output
    IF (!(Test-Path $LogFilePath)) {
        $LogFileEntry | Export-Csv -Path  $LogFilePath -Encoding ascii -NoTypeInformation
    } ELSE {
        $LogFileEntry | Export-Csv -Path  $LogFilePath -Encoding ascii -NoTypeInformation -Append
    }

    #Wait for Next Cycle
    Write-Host ""
    Write-Host "Waiting $($CycleWaitTime) seconds..." -f Red
    Start-Sleep $CycleWaitTime
}