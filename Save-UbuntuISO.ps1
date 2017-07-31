<#
.SYNOPSIS
    This script helps you download from available Ubuntu ISO files.

.DESCRIPTION
    Run this script to download ISO files for the latest available ubuntu releases for both desktop and server.
    By Default the script downloads server iso for 64 bit architecture.
    If you want to download Desktop iso then pick -OSType parameter with Desktop choice.
    If you want to download 32 bit iso then pick -OSBit parameter with i386 choice.

.PARAMETER OSType
    Select between Desktop or Server edition of the ubuntu. Default value is "Server"

.PARAMETER OSBit
    Select between 64 bit or 32 bit architecture os the ubuntu. Default value is "AMD64"

.EXAMPLE
    <Path>/Save-UbuntuISO.ps1
    The script downloads server iso for 64 bit architecture for the version selected by user in C:\Temp directory. If the C:\Temp is not available script will create it.

.EXAMPLE
    <Path>/Save-UbuntuISO.ps1 -OSbit i368
    The script downloads desktop iso for 64 bit architecture for the version selected by user in C:\Temp directory. If the C:\Temp is not available script will create it.

.EXAMPLE
    <Path>/Save-UbuntuISO.ps1 -OSType Desktop
    The script downloads desktop iso for 64 bit architecture for the version selected by user in C:\Temp directory. If the C:\Temp is not available script will create it.

.EXAMPLE
    <Path>/Save-UbuntuISO.ps1 -OSType Desktop -OSbit i368
    The script downloads desktop iso for 32 bit architecture for the version selected by user in C:\Temp directory. If the C:\Temp is not available script will create it.

.NOTES
    This script is tested on PowerShell 5, Windows 10 Pro version 1703 (creator update).
    I expect it to work on PowerShell 3 and above.
    Currently this script will not work on PowerShell linux as it needs BITS modules.
#>
Param(
[ValidateSet("Server","Desktop")][string]$OSType = "server",
[ValidateSet("amd64","i386")][string]$OSbit = "amd64"
)

$isoStorageLocation = "C:\Temp"
Write-Host "Default is Download amd64 Server Operating System ISO." -ForegroundColor Cyan
Write-Host "Run script if you want Desktop -OSType Desktop Parameter" -ForegroundColor Cyan
Write-Host "Run script if you want 32bit ISP with -OSbit i386 Parameter" -ForegroundColor Cyan
Write-Host "Default Download Location is set to $isoStorageLocation"
if (-not (Test-Path $isoStorageLocation)) 
{
    Write-Host "Creating Folder $isoStorageLocation" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $isoStorageLocation | Out-Null
    Write-Host "Created Folder $isoStorageLocation" -ForegroundColor Green
} 
else 
{
    Write-Host "Folder $isoStorageLocation already exists." -ForegroundColor Green
}

function Get-AvailableUbuntuVersions()
{
    <#
    .SYNOPSIS
    Gets the available ubuntu versions from http://releases.ubuntu.com to build user choice menu.
    
    .DESCRIPTION
    This function reads http://releases.ubuntu.com/ and extracts the available version details.
    It then presents the available version to user and let user select from it.
    Using the choice of user it then calls Get-UbuntuDownloadUrl to build/identfy the download url for the selected version.
        
    .NOTES
    This is main function which gets called after running the script.
    #>
    Write-Verbose "Reading http://releases.ubuntu.com/ to extract available ubuntu versions"
    try{
        $everything_ok = $true
        $temphtml = Invoke-WebRequest -Uri 'http://releases.ubuntu.com/' -ErrorAction Stop -ErrorVariable ReadReleasesError
    }
    catch{
        $everything_ok = $false
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    if ($everything_ok)
    {
        $versionsAvailable = $temphtml.Links.href | ForEach-Object{[regex]::Matches($_,"(\d+\.\d+\.\d)|(\d+\.\d+)")} | Select-Object value
        [int]$a = 0
        $showVersionsAvailable = @()
        foreach ($v in $versionsAvailable)
        {
            $a++
            $showVersionsAvailable += $("Enter [ $a ] For Ubuntu " + $v.Value)
        }
        
        [int]$UserChoice = 0
        while ($UserChoice -lt 1 -or $UserChoice -gt $versionsAvailable.Count+1)
        {
            Write-Host "************************************************"
            Write-Host "The following releases of Ubuntu are available:" -ForegroundColor Yellow
            $showVersionsAvailable
            Write-host "Enter [ $($versionsAvailable.Count+1) ] Quit and Exit" -ForegroundColor Yellow
            Write-Host "************************************************"
            [Int]$UserChoice = Read-Host "Please enter an option 1 to $($versionsAvailable.Count+1)..." 
        }
        if($UserChoice -eq $($versionsAvailable.Count+1) )
        {
            break
        }
        else 
        {
            Get-UbuntuDownloadUrl $UserChoice
        }
    }
}
function Get-UbuntuDownloadUrl() {
    <#
    .SYNOPSIS
    Generate the download URL.
    
    .DESCRIPTION
    Based on the ubuntu version selected by user, this function generates the download url for the iso and MD5SUMS file.
    
    .PARAMETER Choice
    Receive the user choice. Not enabled to take input from pipeline.
    
    .EXAMPLE
    Refer the Get-AvailableUbuntuVersions $UserChoice call to understand user input captured
    
    .NOTES
    This is internal helper function which gets called from inside Get-AvailableUbuntuVersions. You can can't call this indepdently by just supplying user choice. 
    #>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False)]
    [int]$Choice = 0
    )
    #Write-Host $Choice, $versionsAvailable, $showVersionsAvailable
    Write-host $showVersionsAvailable[$($Choice-1)].Replace('Enter','You have selected') -ForegroundColor Green
    [string]$versionToDownload = $($versionsAvailable[$($Choice-1)]).Value
    [string]$download_file = "ubuntu-$versionToDownload-$OSType-$OSbit"+".iso"            # filename of the iso to be downloaded
    [string]$download_location = "http://releases.ubuntu.com/$versionToDownload/"    # location of the file to be downloaded
    [string]$sourceMD5SumsFile = "http://releases.ubuntu.com/$versionToDownload/MD5SUMS" # checksum data filename of the iso to be downloaded 
    [string]$downloadURL = $download_location + $download_file
    [string]$savedfile = Join-Path -Path $isoStorageLocation -ChildPath $download_file
    Write-Host "Starting Download" -ForegroundColor Yellow
    Save-UbuntuISO -SourceUrl $downloadURL -SaveAsPath $savedfile
}

function Save-UbuntuISO(){
    <#
    .SYNOPSIS
    Download the ISO file.
    
    .DESCRIPTION
    This function gets called from inside Get-UbuntuDownloadUrl with download link and target location to save file locally. It uses BITS module to initiate, monitor and close the download of ISO file.
    
    .PARAMETER SourceUrl
    This URL for the iso depending on the version selected by user.
    
    .PARAMETER SaveAsPath
    Local file path where the downloaded ISO file will be saved.
    
    .EXAMPLE
    Refer the Save-UbuntuISO -SourceUrl $downloadURL -SaveAsPath $savedfile call from Get-UbuntuDownloadUrl function.
    
    .NOTES
    This is internal helper function which gets called from inside Get-UbuntuDownloadUrl. If deployed you can call this indepdently by just supplying URL and Local Path. However in this script its not meant to be called independently. It gets the input parameters based on version and architecture type selected by user.
    #>
[CmdletBinding()]
    param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False)]
    [string]$SourceUrl,
    [string]$SaveAsPath
    )
    Start-BitsTransfer -Source $SourceUrl -Destination $SaveAsPath -Asynchronous -Priority Normal -RetryTimeout 60 -RetryInterval 120 -DisplayName "UbuntuISOTransfer"
    $bits = Get-BitsTransfer -Name "UbuntuISOTransfer"
    $pct = 0
    while ($bits.JobState -ne "Transferred" -and $pct -ne 100){
        if ($bits.jobstate -eq "Error" -or $bits.JobState -eq "TransientError" )
        {
            Resume-BitsTransfer -BitsJob $bits
        }

    $pct = [System.Math]::Round($(($bits.BytesTransferred / $bits.BytesTotal)*100),2)
    Write-Host "Progress $pct % completed"
    Start-Sleep -Seconds 120
    }
    Complete-BitsTransfer -BitsJob $bits | Out-Null
    if ($pct -ge 100){
        Write-Host "Download Completed Successfully" -ForegroundColor DarkGreen
        Write-Host "Verifying MD5 checksum of downloaded file" -ForegroundColor Yellow
        Test-Checkum $sourceMD5SumsFile $download_file $SaveAsPath
    }
}

function Test-Checkum(){
    <#
    .SYNOPSIS
    Check the MD5Sum of the downloaded file
    
    .DESCRIPTION
    Its standard recommended practice to check the MD5Sum of files downloaded form internet. Specially the large files. This function takes three parameters Source MD5Sums file location, Source File Name and Locally Saved File Path. It checks the MD5Sums available for Source File with the MD5Sum of downloaded file.
    
    .PARAMETER sourceMD5SumsFileURL
    The URL location where the MD5Sums file is availavble for ubuntu version selected by user.
    
    .PARAMETER sourcefile
    Use this file name at source for retrieving the MD5Sum inside MD5Sums file.
    
    .PARAMETER targetFile
    Use this path to retrive the MD5Sum of the downloaded file.
    
    .EXAMPLE
    Refer Test-Checkum $sourceMD5SumsFile $download_file $SaveAsPath call in Save-UbuntuISO function.
    
    .NOTES
    This is internal helper function which gets called from inside Save-UbuntuISO. If deployed you can call this indepdently by just supplying MD5SumsURL, Source File Name and Local Downloaded File Path. However in this script its not meant to be called independently. It gets the input parameters from Save-UbuntuISO for the file which is getting downloaded. 
    #>
    [CmdletBinding()]
    param(
    [string]$sourceMD5SumsFileURL,
    [string]$sourcefile,
    [string]$targetFile
    )
    $sourceAvailableMD5Sums = (Invoke-WebRequest -Uri $sourceMD5SumsFileURL).RawContent.ToString() -split "[`r`n]" | Where-Object{$_ -match 'ubuntu'}
    $sourceFileMD5 = $sourceAvailableMD5Sums | Where-Object{$_ -match $sourcefile}
    $downloadedFileMD5 = Get-FileHash -LiteralPath $targetFile -Algorithm MD5
    If ($sourceFileMD5 -eq $null)
    {
        Write-host "Looks like no checksum available from source or something went wrong" -ForegroundColor DarkRed -BackgroundColor White
    }
    else 
    {
        if ($sourceFileMD5.Split()[0] -eq $downloadedFileMD5.Hash)
        {
            Write-host "File Checksum Matching. Enjoy Installing Ubuntu!!!" -ForegroundColor DarkGreen
        }
        else 
        {
            Write-host "File Checksum Not Matching, be carefull using the downloaded file" -ForegroundColor DarkRed -BackgroundColor White
        }
    }
}

Get-AvailableUbuntuVersions