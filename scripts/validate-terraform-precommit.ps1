$ErrorActionPreference = 'Stop'

function Require-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed (exit code $LASTEXITCODE): $Command $($Arguments -join ' ')"
  }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$infraDir = Join-Path $repoRoot 'infrastructure'
$tempRoot = Join-Path $repoRoot '.tmp'
$tfDataDir = Join-Path $tempRoot ("tf-data-precommit-{0}" -f $PID)

Require-Command -Name 'terraform'
Require-Command -Name 'tflint'

$bashCommand = Get-Command bash -ErrorAction SilentlyContinue
$bashIsUsable = $false
if ($bashCommand) {
  try {
    bash -c 'exit 0' *> $null
    if ($LASTEXITCODE -eq 0) {
      $bashIsUsable = $true
    }
  }
  catch {
    $bashIsUsable = $false
  }
}

if ($bashIsUsable) {
  Write-Host '[terraform-check] Checking shell script syntax...'
  Invoke-Checked -Command 'bash' -Arguments @('-n', (Join-Path $repoRoot 'scripts/deploy-local.sh'))
  Invoke-Checked -Command 'bash' -Arguments @('-n', (Join-Path $repoRoot '.github/scripts/localstack-post-apply-smoke.sh'))
} else {
  Write-Host '[terraform-check] bash is not available or not functional on this machine; skipping bash -n syntax checks locally.'
}

Push-Location $infraDir
try {
  New-Item -ItemType Directory -Path $tfDataDir -Force | Out-Null
  $env:TF_DATA_DIR = $tfDataDir

  Write-Host '[terraform-check] terraform fmt -check -recursive'
  Invoke-Checked -Command 'terraform' -Arguments @('fmt', '-check', '-recursive')

  Write-Host '[terraform-check] terraform init -backend=false -reconfigure -input=false'
  Invoke-Checked -Command 'terraform' -Arguments @('init', '-backend=false', '-reconfigure', '-input=false')

  Write-Host '[terraform-check] tflint --init'
  Invoke-Checked -Command 'tflint' -Arguments @('--init')

  Write-Host '[terraform-check] tflint --recursive'
  Invoke-Checked -Command 'tflint' -Arguments @('--recursive')

  Write-Host '[terraform-check] terraform validate'
  $env:TF_VAR_aws_region = 'us-east-1'
  $env:TF_VAR_environment = 'dev'
  $env:TF_VAR_amplify_github_token = 'placeholder'
  Invoke-Checked -Command 'terraform' -Arguments @('validate')

  Write-Host '[terraform-check] terraform test'
  Invoke-Checked -Command 'terraform' -Arguments @('test')

  Write-Host '[terraform-check] All Terraform pre-commit checks passed.'
}
finally {
  Remove-Item Env:TF_VAR_aws_region -ErrorAction SilentlyContinue
  Remove-Item Env:TF_VAR_environment -ErrorAction SilentlyContinue
  Remove-Item Env:TF_VAR_amplify_github_token -ErrorAction SilentlyContinue
  Remove-Item Env:TF_DATA_DIR -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force $tfDataDir -ErrorAction SilentlyContinue
  Pop-Location
}
