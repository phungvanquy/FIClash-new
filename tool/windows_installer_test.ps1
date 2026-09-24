$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or -not $IsWindows) {
    throw 'Run this installer test only on a disposable Windows Actions runner.'
}

$installers = @(Get-ChildItem dist -Recurse -Filter '*.exe' -File)
if ($installers.Count -ne 1) { throw "Expected one installer, found $($installers.Count)." }
$scratch = Join-Path $env:RUNNER_TEMP ('tunnio-uninstall-' + [guid]::NewGuid())
$installation = Join-Path $scratch 'Installed App'
$otherProfile = Join-Path $scratch 'Other User'
$redirected = Join-Path $scratch 'Redirected Roaming'
$outside = Join-Path $scratch 'Exported backup'
$profileId = 'S-1-5-21-111111111-222222222-333333333-9999'
$profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$profileId"
$userKey = "Registry::HKEY_USERS\$profileId"
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$approvedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$protocolKeys = @('flclash', 'clashmeta', 'clash') | ForEach-Object { "HKCU:\Software\Classes\$_" }
$bases = @(
    [Environment]::GetFolderPath('ApplicationData'),
    [Environment]::GetFolderPath('LocalApplicationData'),
    (Join-Path $otherProfile 'AppData\Roaming'),
    (Join-Path $otherProfile 'AppData\Local'),
    $redirected
)
$dataDirectories = @($bases | ForEach-Object { Join-Path $_ 'com.follow\clash' })
foreach ($path in @($dataDirectories) + @($protocolKeys) + @($profileKey, $userKey)) {
    if (Test-Path -LiteralPath $path) { throw "Test requires an unused path: $path" }
}
if (Get-ItemProperty -LiteralPath $runKey -Name FlClash -ErrorAction SilentlyContinue) {
    throw 'A real startup registration is present.'
}

function Invoke-Installer([string] $Executable, [string[]] $Arguments) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer exited with $($process.ExitCode)." }
}

try {
    New-Item -ItemType Directory -Path $scratch, $outside -Force | Out-Null
    $export = Join-Path $outside 'keep.yaml'
    Set-Content -LiteralPath $export -Value 'user export'
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installation`"")
    Invoke-Installer $installers[0].FullName $arguments
    $executable = Join-Path $installation 'FlClash.exe'
    if (-not (Test-Path -LiteralPath $executable)) { throw 'The app was not installed.' }
    foreach ($path in $dataDirectories) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $path 'shared_preferences.json') -Value '{}'
        New-Item -ItemType Directory -Path (Join-Path $path 'profiles\generations') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $path 'profiles\generations\saved.yaml') -Value 'saved profile'
    }
    $sibling = Join-Path $bases[0] 'com.follow\OtherApp'
    New-Item -ItemType Directory -Path $sibling -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sibling 'keep.txt') -Value 'other app'
    New-Item -ItemType Junction -Path (Join-Path $dataDirectories[0] 'export-link') -Target $outside | Out-Null
    New-Item -Path $profileKey -Force | Out-Null
    New-ItemProperty -Path $profileKey -Name ProfileImagePath -Value $otherProfile | Out-Null
    $folders = "$userKey\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    New-Item -Path $folders -Force | Out-Null
    New-ItemProperty -Path $folders -Name AppData -Value $redirected | Out-Null
    foreach ($key in $protocolKeys) {
        New-Item -Path "$key\shell\open\command" -Force | Out-Null
        $owner = if ($key.EndsWith('\clash')) { 'C:\OtherApp\Other.exe' } else { $executable }
        Set-Item -Path "$key\shell\open\command" -Value "`"$owner`" `"%1`""
    }
    New-ItemProperty -Path $runKey -Name FlClash -Value $executable | Out-Null
    New-Item -Path $approvedKey -Force | Out-Null
    New-ItemProperty -Path $approvedKey -Name FlClash -PropertyType Binary -Value ([byte[]](2, 0, 0, 0)) | Out-Null

    Invoke-Installer $installers[0].FullName $arguments
    foreach ($path in $dataDirectories) {
        if (-not (Test-Path (Join-Path $path 'profiles\generations\saved.yaml'))) {
            throw "Upgrade deleted saved data: $path"
        }
    }
    $uninstaller = @(Get-ChildItem -LiteralPath $installation -Filter 'unins*.exe')
    if ($uninstaller.Count -ne 1) { throw 'Expected one uninstaller.' }
    Invoke-Installer $uninstaller[0].FullName @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$scratch\uninstall.log`"")
    foreach ($path in $dataDirectories) {
        if (Test-Path -LiteralPath $path) { throw "Uninstall retained app data: $path" }
    }
    if (Test-Path -LiteralPath $executable) { throw 'Uninstall retained the executable.' }
    if (-not (Test-Path -LiteralPath $export)) { throw 'Uninstall followed a junction into an export.' }
    if (-not (Test-Path (Join-Path $sibling 'keep.txt'))) { throw 'Uninstall deleted another app.' }
    foreach ($key in $protocolKeys[0..1]) {
        if (Test-Path -LiteralPath $key) { throw "Uninstall retained protocol: $key" }
    }
    if (-not (Test-Path -LiteralPath $protocolKeys[2])) { throw 'Uninstall deleted another protocol owner.' }
    foreach ($key in @($runKey, $approvedKey)) {
        if (Get-ItemProperty -LiteralPath $key -Name FlClash -ErrorAction SilentlyContinue) {
            throw "Uninstall retained startup registration: $key"
        }
    }
    Write-Output 'Windows install, upgrade preservation, and uninstall cleanup passed.'
}
finally {
    foreach ($key in @($profileKey, $userKey) + @($protocolKeys)) {
        if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    }
}
