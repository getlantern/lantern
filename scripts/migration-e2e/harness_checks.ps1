# Safe on a hosted runner: load function definitions, never execute VM orchestration.
#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
  "$PSScriptRoot/run.ps1", [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { $parseErrors | Format-List; exit 1 }
foreach ($statement in $ast.EndBlock.Statements) {
  if ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) {
    . ([scriptblock]::Create($statement.Extent.Text))
  }
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('migration-harness-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $original = Join-Path $temp 'original.json'
  $renamed = Join-Path $temp 'renamed.json'
  [IO.File]::WriteAllText($original, '{"ok":true}', [Text.UTF8Encoding]::new($false))
  $expectedHash = (Get-FileHash $original -Algorithm SHA256).Hash.ToLowerInvariant()
  if ((Hash $original) -ne $expectedHash) { throw 'wrong_hash' }
  if ((Read-Json $original).ok -ne $true) { throw 'wrong_json' }
  $held = Open-SharedRead $original
  try {
    # On Windows this fails if an observer omits FILE_SHARE_DELETE.
    Move-Item -LiteralPath $original -Destination $renamed
    if ($held.ReadByte() -ne [int][char]'{') { throw 'rename_lost_stream' }
  } finally { $held.Dispose() }
  if ((Hash $renamed) -ne $expectedHash) { throw 'rename_changed_bytes' }
  try { Require $false 'fixture_rejected'; throw 'missing_failure' }
  catch {
    if ($_.Exception.Data['migration-e2e-code'] -ne 'fixture_rejected') { throw 'lost_fixed_error_code' }
  }
  [IO.File]::WriteAllText($renamed, 'PRIVATE_FIXTURE_CONTENT')
  try { $null = Read-Json $renamed; throw 'accepted_bad_json' }
  catch {
    if ($_.Exception.Data['migration-e2e-code']) { throw 'raw_error_became_diagnostic' }
  }
  'PowerShell parser and read-sharing/error-code checks passed'
} finally {
  # Only the unique directory created by this test is removed.
  Remove-Item -LiteralPath $temp -Recurse -Force
}
