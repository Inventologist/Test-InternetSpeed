# Test-InternetSpeed
 Test your internet Speed using the SpeedTest.net CLI (with logging)
 
 ## How to Run
 You can download the ps1 file and just run it it, or you can have it auto load and update with "Get-Git" https://github.com/Inventologist/Get-Git
 
 Just insert the following command into your script and the script will download, expand, and auto load:</br>
 ```powershell
 Invoke-Expression ('$GHDLUri="https://github.com/Inventologist/Test-InternetSpeed/archive/master.zip";$GHUser="Inventologist";$GHRepo="Test-InternetSpeed";$ForceRefresh="Yes"' + (new-object net.webclient).DownloadString('https://raw.githubusercontent.com/Inventologist/Get-Git/master/Get-Git.ps1'))
 
