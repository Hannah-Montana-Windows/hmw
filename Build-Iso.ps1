function Check-Host {
    if ([System.Environment]::OSVersion.Platform -ne 'Win32NT') {
        throw [System.PlatformNotSupportedException]::new("This script is only supported on Windows.")
    }
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw [System.PlatformNotSupportedException]::new("This script requires PowerShell 5.0 or later.")
    }
}

function Check-Hash {
    param (
        [string]$TargetPath,
        [string]$ExpectedHash,
        [string]$FileTitle,
        [string]$SpecificError
    )

    if (-not (Test-Path -Path $TargetPath)) {
        throw [System.IO.FileNotFoundException]::new("$FileTitle was not found, please ensure the file exists.")
    } else {
        $SourceFileMD5 = Get-FileHash -Path $TargetPath -Algorithm MD5
        if ($SourceFileMD5.Hash -ne $ExpectedHash) {
            throw [System.IO.InvalidDataException]::new("$FileTitle was found but the MD5 hash does not match the expected value.`r`nCalculated:  $SourceFileMD5.Hash`r`nExpected:  $ExpectedHash`r`n$SpecificError")
        } else {
            Write-Host "$FileTitle verified successfully."
        }
    } 

}

function Extract-ISO {
    Remove-Item -LiteralPath ".\temp\working\" -Force -Recurse
    New-Item -Path .\temp\working -ItemType Directory | Out-Null

    Dismount-DiskImage -ImagePath "$pwd\isos\source.iso"
    Mount-DiskImage -ImagePath "$pwd\isos\source.iso"

    $ISOMount = Get-PSDrive | Where-Object {$_.Description -eq "GRTMPVOL_EN"}
    $ISODriveLetter = $ISOMount.Root

    Copy-Item -Path "$ISODriveLetter\*" -Destination "$pwd\temp\working" -Recurse -Force

    Dismount-DiskImage -ImagePath "$pwd\isos\source.iso"
}

function Slipstream-Drivers {
    Start-Process "$Env:Programfiles\Git\usr\bin\patch.exe" -Wait -ArgumentList "$pwd\temp\working\i386\TXTSETUP.SIF $pwd\slipstream\drivers\TXTSETUP.SIF.patch"
    New-Item -Path .\temp\working\i386\NLDRV\ -ItemType Directory | Out-Null
    Copy-Item -Path .\slipstream\drivers\001\ -Destination .\temp\working\i386\NLDRV\ -Recurse -Force
    Copy-Item -Path .\slipstream\drivers\002\ -Destination .\temp\working\i386\NLDRV\ -Recurse -Force

    Copy-Item -Path .\smss.exe -Destination .\temp\working\i386\SYSTEM32 -Force
}


function Check-MSBinaries {
    Write-Host "Calculating hashes, this may take some time."

    Check-Hash -TargetPath .\isos\source.iso -ExpectedHash "5BF476E2FC445B8D06B3C2A6091FE3AA" -FileTitle "Source ISO" -SpecificError "Please ensure you are using an unmodified copy of 32-bit en_us VL Windows XP SP3."

    if (!(Test-Path -Path $Env:Programfiles\Git\usr\bin\patch.exe)) {
        throw [System.IO.FileNotFoundException]::new("Git for Windows binaries were not found, please ensure you have Git for Windows installed.")
    }

}

function Download-Tools {
    if (!(Test-Path -Path .\tools\rh\ResourceHacker.exe)) {
        Invoke-WebRequest -Uri "https://www.angusj.com/resourcehacker/resource_hacker.zip" -OutFile .\tools\resource_hacker.zip
        New-Item -Path .\tools\rh -ItemType Directory | Out-Null
        Expand-Archive -Path .\tools\resource_hacker.zip -DestinationPath .\tools\rh\
        Remove-Item -Path .\tools\resource_hacker.zip
    }

    if(!(Test-Path -Path .\tools\7zr.exe)) {
        Invoke-WebRequest -Uri "https://7-zip.org/a/7zr.exe" -OutFile .\tools\7zr.exe
    }
}

function RH-Compile {
    & $pwd\tools\rh\ResourceHacker.exe -open $pwd\assets\rc\smss_message.rc -save assets\res\smss_message.res -action compile -log nul
}

function RH-Script {
    & $pwd\tools\rh\ResourceHacker.exe -script $pwd\script\rh\smss.rh
}

function Compile-ISO {
    & $pwd\tools\CDIMAGE.EXE -lGRTMPVOL_EN -b"$pwd\assets\binaries\boot.img" -m -h -n "$pwd\temp\working\" "$pwd\isos\output.iso" 
}


Check-Host
Check-MSBinaries
Download-Tools
RH-Compile
RH-Script
Extract-ISO
Slipstream-Drivers
Compile-ISO