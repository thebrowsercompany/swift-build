# Modified from https://github.com/astral-sh/uv/blob/bd9c365b92b4c00b3c444e8108921a1190ecb780/.github/workflows/setup-dev-drive.ps1
# Configures a drive for testing in CI.

# When not using a GitHub Actions "larger runner", the `D:` drive is present and
# has similar or better performance characteristics than a ReFS dev drive.
# Sometimes using a larger runner is still more performant (e.g., when running
# the test suite) and we need to create a dev drive. This script automatically
# configures the appropriate drive.

# Note we use `Get-PSDrive` is not sufficient because the drive letter is assigned.
if (Test-Path "D:\") {
    Write-Output "Using existing drive at D:"
    $Drive = "D:"
}
else {
    # The size (20 GB) is chosen empirically to be large enough for our
    # workflows; larger drives can take longer to set up.
    $Volume = New-VHD -Path C:/bcny_dev_drive.vhdx -SizeBytes 20GB |
    Mount-VHD -Passthru |
    Initialize-Disk -Passthru |
    New-Partition -AssignDriveLetter -UseMaximumSize

    # Check if DevDrive parameter exists
    $HasDevDrive = (Get-Command Format-Volume).Parameters.Keys -contains "DevDrive"

    if ($HasDevDrive) {
        Write-Output "Using DevDrive Switch"
        $Volume | Format-Volume -DevDrive -Confirm:$false -Force

        # Set the drive as trusted
        # See https://learn.microsoft.com/en-us/windows/dev-drive/#how-do-i-designate-a-dev-drive-as-trusted
        fsutil devdrv trust $Drive

        # Disable antivirus filtering on dev drives
        # See https://learn.microsoft.com/en-us/windows/dev-drive/#how-do-i-configure-additional-filters-on-dev-drive
        fsutil devdrv enable /disallowAv

        fsutil devdrv query $Drive
    }
    else {
        Write-Output "Trying to format with ReFS manually since -DevDrive switch doesn't exist"
        # Format as ReFS volume if DevDrive isn't supported
        $Volume | Format-Volume -FileSystem ReFS -Confirm:$false -Force

        # Trust the ReFS volume similar to how we trust DevDrive volumes
        fsutil behavior set disableLastAccess 1
        fsutil behavior set disablecompression 1
    }

    $Drive = "$($Volume.DriveLetter):"

    # Remount so the changes take effect
    Dismount-VHD -Path C:/bcny_dev_drive.vhdx
    Mount-VHD -Path C:/bcny_dev_drive.vhdx

    # Show some debug information
    Write-Output $Volume

    Write-Output "Using Dev Drive at $Volume"
}

$Tmp = "$($Drive)\bcny-tmp"

# Create the directory ahead of time in an attempt to avoid race-conditions
New-Item $Tmp -ItemType Directory

# Make root directory for bcny
New-Item "$($Drive)\bcny" -ItemType Directory -Force

# Move Cargo to the dev drive
New-Item -Path "$($Drive)/.cargo/bin" -ItemType Directory -Force
if (Test-Path "C:\Users\runneradmin\.cargo") {
    Copy-Item -Path "C:\Users\runneradmin\.cargo/\" -Destination "$($Drive)\.cargo\" -Recurse -Force
}

Write-Output `
    "DEV_DRIVE=$($Drive)" `
    "TMP=$($Tmp)" `
    "TEMP=$($Tmp)" `
    "RUSTUP_HOME=$($Drive)\.rustup" `
    "CARGO_HOME=$($Drive)/.cargo" `
    "BCNY_WORKSPACE=$($Drive)\bcny" `
    "PATH=$($Drive)\.cargo\bin;$env:PATH" `
    >> $env:GITHUB_ENV