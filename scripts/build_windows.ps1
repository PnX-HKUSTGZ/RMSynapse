param(
    [ValidateSet("msvc", "mingw")]
    [string]$Toolchain = "msvc",

    [string]$Target = "template_release",
    [string]$Arch = "x86_64",

    [switch]$Debug,
    [switch]$SkipUi,
    [switch]$SkipVideo,
    [switch]$Export,
    [switch]$LfsPull,
    [switch]$NoNpmCi,

    [string]$GodotBin = $env:GODOT_BIN,
    [string]$FfmpegRoot = "",
    [string]$FfmpegRuntimeDir = "",

    [ValidateSet("auto", "yes", "no")]
    [string]$CopyFfmpegRuntime = "auto",

    [string[]]$SConsArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Debug) {
    $Target = "template_debug"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path

function Invoke-LfsPull {
    if ($LfsPull) {
        git -C $RootDir lfs pull
    }
}

function Build-Ui {
    if ($SkipUi) {
        return
    }

    Push-Location (Join-Path $RootDir "react-ui")
    try {
        if (-not $NoNpmCi) {
            npm ci
        }
        npm run build
    }
    finally {
        Pop-Location
    }

    $TargetWeb = Join-Path $RootDir "rm_synapse\ui\web"
    Remove-Item -Recurse -Force -LiteralPath $TargetWeb -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $TargetWeb | Out-Null

    $DistDir = Join-Path $RootDir "react-ui\dist"
    Get-ChildItem -Force -LiteralPath $DistDir | ForEach-Object {
        Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination $TargetWeb
    }
}

function Build-Video {
    if ($SkipVideo) {
        return
    }

    $Args = @(
        "platform=windows",
        "target=$Target",
        "arch=$Arch",
        "copy_ffmpeg_runtime=$CopyFfmpegRuntime"
    )

    if ($Toolchain -eq "mingw") {
        $Args += "use_mingw=yes"
    }
    if ($FfmpegRoot) {
        $Args += "ffmpeg_root=$FfmpegRoot"
    }
    if ($FfmpegRuntimeDir) {
        $Args += "ffmpeg_runtime_dir=$FfmpegRuntimeDir"
    }
    if ($SConsArgs.Count -gt 0) {
        $Args += $SConsArgs
    }

    Push-Location (Join-Path $RootDir "plugins\rm_video_decoder")
    try {
        & scons @Args
    }
    finally {
        Pop-Location
    }
}

function Export-Project {
    if (-not $Export) {
        return
    }

    if (-not $GodotBin) {
        $GodotBin = "godot"
    }

    $ExportDir = Join-Path $RootDir "rm_synapse\Export\windows"
    New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null
    $ExportPath = Join-Path $ExportDir "rmsynapse.exe"

    & $GodotBin --headless --path (Join-Path $RootDir "rm_synapse") `
        --export-release "Windows Desktop" $ExportPath
}

Invoke-LfsPull
Build-Ui
Build-Video
Export-Project

Write-Host "Windows build finished."
