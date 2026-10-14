param(
  [string]$DevEcoHome = 'D:\Program Files\DevEco Studio',
  [switch]$Preview
)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
$taskNode = Join-Path $DevEcoHome 'tools\node\node.exe'
$taskHvigor = Join-Path $DevEcoHome 'tools\hvigor\hvigor\bin\hvigor.js'
if (!(Test-Path -LiteralPath $taskNode) -or !(Test-Path -LiteralPath $taskHvigor)) {
  throw '找不到 DevEco 构建工具，请通过 -DevEcoHome 指定安装目录。'
}
$env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
$env:Path = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:Path
$taskBuildTarget = if ($Preview) { 'PreviewBuild' } else { 'assembleHap' }
Push-Location -LiteralPath $taskProjectRoot
try {
  & $taskNode $taskHvigor --mode module -p product=default -p module=entry@default -p buildMode=debug $taskBuildTarget --no-daemon
  $taskExitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
exit $taskExitCode
