param(
    [Parameter(Mandatory=$true)] # Hace que el argumento sea obligatorio
    $Intentos=20,
    [string]$IpImpresora="0.0.0.0",
    [String]$IpImpresora2="0.0.0.0"
    
)
if (!($([Security.Principal.WindowsIdentity]::GetCurrent().Name -like "*$(Get-LocalUser | Where-Object { $_.SID.Value -match '-500$' })*"))) {Read-Host -Prompt "Ejecute nuevamente como Admin Integrado. [Presione Enter para salir] ";Exit}
New-Item -Path "C:\ProgramData\ScanDinamico\Parametros" -ItemType Directory -Force | Out-Null
Set-Content -Path "C:\ProgramData\ScanDinamico\Parametros\Intentos.dat" -Value $Intentos -Force | Out-Null
Set-Content -Path "C:\ProgramData\ScanDinamico\Parametros\IpImpresora.dat" -Value $IpImpresora -Force | Out-Null
Set-Content -Path "C:\ProgramData\ScanDinamico\Parametros\IpImpresora2.dat" -Value $IpImpresora2 -Force | Out-Null
Copy-Item -Path "$PSScriptRoot\AutoScan.ps1" -Destination "C:\ProgramData\ScanDinamico\AutoScan.ps1" -Force
Copy-Item -Path "$PSScriptRoot\ScanDinamico.xml" -Destination "C:\ProgramData\ScanDinamico\ScanDinamico.xml" -Force
$rutaCredencial='C:\Windows\System32\Impresoras\Lexmark'
New-Item -Path $rutaCredencial -ItemType Directory -Force | Out-Null
$credencial = (New-Object System.Management.Automation.PSCredential('Admin',(ConvertTo-SecureString "$([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('contraseñaderedenbase64')))" -AsPlainText -Force)))
$credencial | Export-Clixml -LiteralPath "$($rutaCredencial)\Impresora.xml"
Remove-Variable -Name credencial -ErrorAction SilentlyContinue
$credenciales = [ordered]@{
    pwd1 = (New-Object System.Management.Automation.PSCredential('Admin',(ConvertTo-SecureString 'Claveimpresora1' -AsPlainText -Force)))
    pwd2 = (New-Object System.Management.Automation.PSCredential('Admin',(ConvertTo-SecureString 'Claveimpresora2' -AsPlainText -Force)))
    pwd3 = (New-Object System.Management.Automation.PSCredential('Admin',(ConvertTo-SecureString 'Claveimpresora3' -AsPlainText -Force)))
}
$credenciales | Export-Clixml -LiteralPath "$($rutaCredencial)\Impresoras.xml"
Remove-Variable -Name credenciales -ErrorAction SilentlyContinue
$identidad = [Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls.exe 'C:\Windows\System32\Impresoras\Lexmark' /inheritance:r /grant:r "${identidad}:(OI)(CI)(F)" 'SYSTEM:(OI)(CI)(F)'
powershell.exe -ExecutionPolicy Bypass -File "C:\ProgramData\ScanDinamico\AutoScan.ps1"
Exit 0