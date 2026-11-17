param([string]$Layout = "res://assets/maps/house-02.layout.json", [switch]$Investigate, [switch]$Painted, [string]$Screen = "", [Nullable[int]]$CaseSeed = $null, [ValidateRange(0,20)][int]$KillerPreviewCount = 0)
$ErrorActionPreference = "Stop"
if ($Painted -and -not $PSBoundParameters.ContainsKey('Layout')) {
    $Layout = if ($Investigate) { "res://assets/maps/house-02.investigation.layout.json" } else { "res://assets/maps/house-02.painted.layout.json" }
}
$blockoutRoot = Split-Path -Parent $PSScriptRoot
$blockoutConfigPath = Join-Path $PSScriptRoot "dos-game-mcp/local.json"
if (-not (Test-Path -LiteralPath $blockoutConfigPath)) {
    throw "Configure Godot using tools/dos-game-mcp/setup_local.py --godot first."
}
$blockoutConfig = Get-Content -LiteralPath $blockoutConfigPath -Raw | ConvertFrom-Json
$blockoutEngine = $blockoutConfig.godot_gui
if (-not $blockoutEngine -or -not (Test-Path -LiteralPath $blockoutEngine)) {
    throw "The configured graphical Godot executable is missing."
}
if ($blockoutConfig.godot_gui_sha256 -and (Get-FileHash -LiteralPath $blockoutEngine -Algorithm SHA256).Hash.ToLowerInvariant() -ne $blockoutConfig.godot_gui_sha256) {
    throw "The configured Godot executable hash changed; update the local configuration."
}
if ($Layout.Contains('"')) { throw "Layout path cannot contain quotes." }
if ($Screen -and $Screen -notmatch '^[a-z0-9_]+$') { throw "Screen must be a room ID from the layout." }
$blockoutScene = if ($Investigate) { 'res://src/blockout/house_investigation.tscn' } else { 'res://src/blockout/house_blockout.tscn' }
$blockoutArgs = @('--path', ('"{0}"' -f $blockoutRoot), $blockoutScene, '--', ('"--layout={0}"' -f $Layout))
if ($Screen) { $blockoutArgs += "--blockout-screen=$Screen" }
if ($Investigate) {
	if ($KillerPreviewCount -gt 0 -and $null -eq $CaseSeed) { $blockoutArgs += "--killer-preview-count=$KillerPreviewCount" }
    if ($null -ne $CaseSeed) {
        if ($CaseSeed -lt 0 -or $CaseSeed -gt 999999999) { throw "Case number must be between 0 and 999999999." }
        $blockoutArgs += "--case-seed=$CaseSeed"
    } else { $blockoutArgs += '--random-case' }
}
Start-Process -FilePath $blockoutEngine -WorkingDirectory $blockoutRoot -WindowStyle Normal -PassThru -ArgumentList @(
    $blockoutArgs
)
