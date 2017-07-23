# Setting up required variables 
$tmp = "C:\Temp"
$sourceDirectory = "C:\LabSources\Linux"
$isoFile = "C:\LabSources\ISOs\ubuntu-16.04.1-server-amd64.iso"
$isoFileRemastered = "C:\LabSources\ISOs\ubuntu-16.04.1-server-amd64-unattended.iso"

$seed_file = "mshende.seed"
$hostname = 'vubuntusrv'
$timezone = 'Asia/Kolkata'

# Ask the user questions about user preferences
$rootPassword = Read-Host " Please enter your preferred root password: " 
$rootPassword2 = Read-Host " Confirm your preferred root password: "
$username = Read-Host " Please enter your preferred username: "
$password = Read-Host " Please enter your preferred password: " 
$password2 = Read-Host " Confirm your preferred password: "

# Check if the passwords match and generate encrypted hash to use in preseed file 
if ($password -eq $password2)
{
    Write-host "Your passwords match, Generating encrypted hash" -ForegroundColor Green -BackgroundColor Black
    # generate the password hash
    $pwhash = bash -c "echo $password | mkpasswd -s -m sha-512"
} 
else 
{
    Write-host "Your passwords do not match; please restart the script and try again" -ForegroundColor Red -BackgroundColor White
    break
}

# Check if the root passwords match and generate encrypted hash to use in ks.cfg file 
if ($rootPassword -eq $rootPassword2)
{
    Write-host "Your root passwords match, Generating encrypted hash" -ForegroundColor Green -BackgroundColor Black
    # generate the password hash
    $rootPwdHash = bash -c "echo $rootPassword | mkpasswd -s -m sha-512"
} 
else 
{
    Write-host "Your root passwords do not match; please restart the script and try again" -ForegroundColor Red -BackgroundColor White
    break
}

# Creating / Verifying Required Folder Structure is available to work
Write-Host "Creating / Verifying Required Folder Structure" -ForegroundColor Yellow
if (-not (Test-Path $tmp)) 
{
    Write-Host "Creating Folder $tmp" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $tmp | Out-Null
    Write-Host "Created Folder $tmp" -ForegroundColor Green
    
    Write-Host "Creating Folder $tmp\iso_org" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path "$tmp\iso_org" | Out-Null
    Write-Host "Created Folder $tmp\iso_org" -ForegroundColor Green
} 
else 
{
    Write-Host "Folder $tmp already exists." -ForegroundColor Green
    if (-not (Test-Path "$tmp\iso_org"))
    {
        Write-Host "Creating Folder $tmp\iso_org" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path "$tmp\iso_org" | Out-Null
        Write-Host "Created Folder $tmp\iso_org" -ForegroundColor Green
    } 
    else 
    {
        Write-Host "Folder $tmp\iso_org already exists." -ForegroundColor Green
    }
}

# Mounting C:\LabSources\ISOs\ubuntu-16.04.1-server-amd64.iso file and copy content locally
Write-Host "Mounting Original ISO" -ForegroundColor Yellow
$ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
if(! $ISODrive){
    Mount-DiskImage -ImagePath $isoFile -StorageType ISO
}
$ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
Write-Host ("$isoFile Drive is " + $ISODrive)

Write-Host "Extracting ISO content to working directory C:\Temp\iso_org" -ForegroundColor Yellow
$ISOSource = ("$ISODrive" + ":\*.*")
xcopy $ISOSource "$tmp\iso_org\" /e

# Copy baseline Kickstart Configuration File To Working Folder
Copy-Item "$sourceDirectory\ks.cfg" -Destination "$tmp\iso_org" -Force

# Copy baseline Seed File (answers for unattended setup) To Working Folder
Copy-Item "$sourceDirectory\$seed_file" "$tmp\iso_org" -Force

# Update the ks.cfg file to reflect encrypted root password hash
(Get-Content "$tmp\iso_org\ks.cfg").replace("rootpw --disabled","rootpw --iscrypted $rootPwdHash" ) | Set-Content "$tmp\iso_org\ks.cfg"

# Update the seed file to reflect the users' choices
(Get-Content "$tmp\iso_org\$seed_file").replace('{{username}}', $username) | Set-Content "$tmp\iso_org\$seed_file"
(Get-Content "$tmp\iso_org\$seed_file").replace('{{pwhash}}', $pwhash) | Set-Content "$tmp\iso_org\$seed_file"
(Get-Content "$tmp\iso_org\$seed_file").replace('{{hostname}}', $hostname) | Set-Content "$tmp\iso_org\$seed_file"
(Get-Content "$tmp\iso_org\$seed_file").replace('{{timezone}}', $timezone) | Set-Content "$tmp\iso_org\$seed_file"

# Update the isolinux.cfg file to reflect boot time choices
(Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('timeout 0', 'timeout 1') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"
(Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('prompt 0', 'prompt 1') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"

# Building installer menu choice to make it default and use ks.cfg and mshende.seed files
$install_lable = @"
default autoinstall
label autoinstall
  menu label ^Automatically install Ubuntu
  kernel /install/vmlinuz
  append file=/cdrom/preseed/ubuntu-server.seed vga=788 initrd=/install/initrd.gz ks=cdrom:/ks.cfg preseed/file=/cdrom/mshende.seed quiet --
"@
(Get-Content "$tmp\iso_org\isolinux\txt.cfg").replace('default install', $install_lable) | Set-Content "$tmp\iso_org\isolinux\txt.cfg"

# Creating new ISO file at C:\LabSources\ISOs\ubuntu-16.04.1-server-amd64-unattended.iso
Write-Host " Creating the remastered iso"
Set-location "$tmp\iso_org"
C:\LabSources\Linux\mkisofs.exe -D -r -V "UBUNTU1604SRV" -duplicates-once -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $isoFileRemastered .

# Create Hyper-v VM
$vmFolder = "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\Linux"
New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
$vmSwitch = Get-VMSwitch | Where-Object {$_.Name -eq 'AdvPSLabExternal'}
New-VM -Name $hostname -NewVHDPath "$vmFolder\$hostname.vhdx" -NewVHDSizeBytes 80gb -MemoryStartupBytes 2GB
Add-VMDvdDrive -VMName $hostname -Path $isoFileRemastered
$vmActiveSwitch = Get-VM -Name $hostname -ErrorAction SilentlyContinue | Get-VMNetworkAdapter -ErrorAction SilentlyContinue
if (! $vmActiveSwitch.SwitchName){
    Write-Host "Adding Switch"
    Get-VM -Name $hostname | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $vmSwitch.Name
}
# Add host entry on my physical machine pointing to VM ip address to connect VM over ssh
Add-Content $env:SystemRoot\system32\drivers\etc\hosts -Value "192.168.1.12    vubuntusrv"
# Below is line to clear the host entry after vm is discarded
# (Get-Content "$env:SystemRoot\system32\drivers\etc\hosts") | Where-Object {$_ -ne "192.168.1.12    vubuntusrv"} | Set-Content "$env:SystemRoot\system32\drivers\etc\hosts"

# Starting Virtual Machine and Connecting through VM console
Start-VM -Name $hostname
vmconnect.exe localhost $hostname

# Connect to server once ready using putty
# C:\LabSources\Linux\putty.exe -ssh user1@192.168.1.12