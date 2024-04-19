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
    New-Item -Path .\temp\working -ItemType Directory

    Dismount-DiskImage -ImagePath "$pwd\isos\source.iso"
    Mount-DiskImage -ImagePath "$pwd\isos\source.iso"

    $ISOMount = Get-PSDrive | Where-Object {$_.Description -eq "WXPVOL_EN"}
    $ISODriveLetter = $ISOMount.Root

    Copy-Item -Path "$ISODriveLetter\*" -Destination "$pwd\temp\working" -Recurse -Force

    Dismount-DiskImage -ImagePath "$pwd\isos\source.iso"
}

function Slipstream-ServicePacks {
}

function Check-MSBinaries {
    Write-Host "Calculating hashes, this may take some time."

    Check-Hash -TargetPath .\isos\source.iso -ExpectedHash "5DB1A137BA7BC8B561A1DD120F5C7D8D" -FileTitle "Source ISO" -SpecificError "Please ensure you are using an unmodified copy of 32-bit en_us VL Windows XP RTM."
    Check-Hash -TargetPath .\slipstream\servicepacks\sp3.exe -ExpectedHash "BB25707C919DD835A9D9706B5725AF58" -FileTitle "Service Pack 3" -SpecificError "Please ensure you are using an unmodified copy of the Windows XP Service Pack 3 EXE."
}

function Compile-ISO {
    & $pwd\assets\binaries\CDIMAGE.EXE -lHMW -b"$pwd\assets\binaries\boot.img" -m -h -n "$pwd\temp\working\" "$pwd\isos\output.iso" 
}

Check-Host
Check-MSBinaries
Extract-ISO
Slipstream-ServicePacks
Compile-ISO