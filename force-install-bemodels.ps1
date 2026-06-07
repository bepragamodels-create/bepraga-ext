# ============================================================
#  force-install-bemodels.ps1
#  Fuerza la instalacion de BeModels en TODOS los perfiles de
#  Chrome de esta PC (presentes y futuros) via politica de Chrome.
#
#  Correr 1 VEZ POR PC, COMO ADMINISTRADOR (escribe en HKLM).
#  Acceso por shell: powershell -ExecutionPolicy Bypass -File force-install-bemodels.ps1
#
#  Resultado:
#    - BeModels se instala automaticamente en cada perfil al abrir Chrome.
#    - Perfiles nuevos (turnos futuros) la reciben solos.
#    - Auto-update cuando se sube un .crx nuevo al repo publico.
#    - El usuario NO puede desinstalarla (instalada por politica).
#
#  ASCII-only para PowerShell 5.1 sin BOM.
# ============================================================

$ErrorActionPreference = 'Stop'

# --- Config (cambiar solo si cambia el ID o el host) ---
$ExtId     = 'gdngbkofdbkdnndfhdoilccikkoejjjd'
$UpdateUrl = 'https://raw.githubusercontent.com/bepragamodels-create/bepraga-ext/main/bemodels-updates.xml'
$Entry     = "$ExtId;$UpdateUrl"

# --- Chequeo de admin ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "ERROR: hay que correr como Administrador (escribe en HKLM)." -ForegroundColor Red
  Write-Host "Abri PowerShell como admin y reintenta." -ForegroundColor Yellow
  return   # 'return' (no 'exit') para ser compatible con 'irm | iex'
}

# --- Aplicar a Google Chrome y, por las dudas, Chromium ---
$keys = @(
  'HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist'
)

foreach ($Key in $keys) {
  if (-not (Test-Path $Key)) { New-Item -Path $Key -Force | Out-Null }

  $existing = Get-ItemProperty -Path $Key -EA SilentlyContinue
  $already  = $false
  $maxIdx   = 0
  if ($existing) {
    foreach ($p in $existing.PSObject.Properties) {
      if ($p.Name -match '^\d+$') {
        $idx = [int]$p.Name
        if ($idx -gt $maxIdx) { $maxIdx = $idx }
        if ($p.Value -eq $Entry) {
          $already = $true
        } elseif ("$($p.Value)" -like "$ExtId;*") {
          # Mismo ID, URL distinta -> actualizar en su lugar.
          Set-ItemProperty -Path $Key -Name $p.Name -Value $Entry
          $already = $true
          Write-Host "Actualizado indice $($p.Name) en $Key" -ForegroundColor Green
        }
      }
    }
  }

  if (-not $already) {
    $next = ($maxIdx + 1).ToString()
    Set-ItemProperty -Path $Key -Name $next -Value $Entry
    Write-Host "Agregado en indice $next : $Entry" -ForegroundColor Green
  } else {
    Write-Host "Ya estaba configurado en $Key" -ForegroundColor DarkGray
  }
}

Write-Host ""
Write-Host "=== LISTO ===" -ForegroundColor Cyan
Write-Host "1. Cerra y reabri Chrome (todos los perfiles) para que se instale."
Write-Host "2. Verificar en cualquier perfil:"
Write-Host "     chrome://policy      -> buscar ExtensionInstallForcelist (Refresh policies)"
Write-Host "     chrome://extensions  -> BeModels aparece 'Instalada por una politica empresarial'"
Write-Host ""
Write-Host "Si NO aparece tras reiniciar Chrome:"
Write-Host "  - Confirmar que la PC usa Google Chrome (no Chrome for Testing/Chromium)."
Write-Host "  - chrome://policy -> Recargar politicas -> revisar errores del extension-id."
