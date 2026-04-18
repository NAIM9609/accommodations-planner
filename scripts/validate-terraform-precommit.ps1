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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir '..')
$infraDir = Join-Path $repoRoot 'infrastructure'

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
  bash -n (Join-Path $repoRoot 'scripts/deploy-local.sh')
  bash -n (Join-Path $repoRoot '.github/scripts/terraform-import-existing.sh')
  bash -n (Join-Path $repoRoot '.github/scripts/localstack-post-apply-smoke.sh')
} else {
  Write-Host '[terraform-check] bash is not available or not functional on this machine; skipping bash -n syntax checks locally.'
}

Push-Location $infraDir
try {
  Write-Host '[terraform-check] terraform fmt -check -recursive'
  terraform fmt -check -recursive

  Write-Host '[terraform-check] terraform init -backend=false -input=false'
  terraform init -backend=false -input=false

  Write-Host '[terraform-check] tflint --init'
  tflint --init

  Write-Host '[terraform-check] tflint --recursive'
  tflint --recursive

  Write-Host '[terraform-check] terraform validate'
  $env:TF_VAR_aws_region = 'us-east-1'
  $env:TF_VAR_environment = 'dev'
  $env:TF_VAR_amplify_github_token = 'placeholder'
  terraform validate

  Write-Host '[terraform-check] terraform test'
  terraform test

  Write-Host '[terraform-check] All Terraform pre-commit checks passed.'
}
finally {
  Remove-Item Env:TF_VAR_aws_region -ErrorAction SilentlyContinue
  Remove-Item Env:TF_VAR_environment -ErrorAction SilentlyContinue
  Remove-Item Env:TF_VAR_amplify_github_token -ErrorAction SilentlyContinue
  Pop-Location
}
