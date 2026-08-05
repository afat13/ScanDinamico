$Intentos=Get-Content -Path "C:\ProgramData\ScanDinamico\Parametros\Intentos.dat" -Raw
$Intentos=$Intentos -as [int]
$IpImpresora=Get-Content -Path "C:\ProgramData\ScanDinamico\Parametros\IpImpresora.dat"
$IpImpresora2=Get-Content -Path "C:\ProgramData\ScanDinamico\Parametros\IpImpresora2.dat"
$DatosBaseImpresora="C:\ProgramData\ScanDinamico\exported.zip"
$DatosModificadosComprimidos="C:\ProgramData\ScanDinamico\imported.zip"
$DirectorioExtraccionDatosBaseImpresora="C:\ProgramData\ScanDinamico\exported"
$esf_settings="$DirectorioExtraccionDatosBaseImpresora\esf_settings.xml"
$RutaMemoria=("C:\ProgramData\ScanDinamico\Memoria\$($IpImpresora)","C:\ProgramData\ScanDinamico\Memoria\$($IpImpresora2)")
$ArchivoRenombrado="esf_settings-.xml"
$esf_settingsTmp="$DirectorioExtraccionDatosBaseImpresora\$ArchivoRenombrado"
$MisDatos = [ordered]@{}
$Info=Get-ComputerInfo
$patrones=[ordered]@{
    "Perfiles"='(?<=<instance>\n.{6})((<setting name="de_network_guid">)[\s\S]*?)(?=.{4}<\/instance>)'
    "NOMBREUSUARIO"='(?<=<setting name="de_network_displayName">).*?(?=<\/setting>)'
    "HOST"='(?<=\\\\).*?(?=\\)'
    "RUTA"='(?=<setting name="de_network_address">).*?(?=<\/setting>)'
    "UID"='(?<=<setting name="de_network_guid">).*?(?=<\/setting>)'
}
function ObtenerIp {
    param(
        [String]$Impresora
    )
    try {
        (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | ForEach-Object { Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 }).IPAddress | ForEach-Object {if ((ping -S $_ -n 2 -w 2 $Impresora) -like '*TTL*') { throw $_ }}
    }
    catch {
        return $_
    }
}   
function Log {
    param (
        [String]$TipoEvento,
        [string]$Evento
    )
    if (!(Test-Path -Path "C:\ProgramData\ScanDinamico\LogScan.dat")) { Set-Content -Path "C:\ProgramData\ScanDinamico\LogScan.dat" -Value "-------------------------- EVENTOS --------------------------" }
    Add-Content -Path "C:\ProgramData\ScanDinamico\LogScan.dat" -Value "$((Get-Date).ToString('yyyy:MM:dd HH:mm:ss')) | $TipoEvento | $Evento"
}
function LimpiezaDescarga {
    if ((Test-Path -Path $DirectorioExtraccionDatosBaseImpresora)) { Remove-Item -Path $DirectorioExtraccionDatosBaseImpresora -Recurse -Force }
    if ((Test-Path -Path $DatosBaseImpresora)) { Remove-Item -Path $DatosBaseImpresora -Force }
}
function descargayDescompresionInfoImpresora {
    param(
        [String]$Impresora
    )
    $rutaCredencial='C:\Windows\System32\Impresoras\Lexmark'
    $UrlSRV="https://$Impresora/webservices/vcc/bundles"
    try {
        $network_pwd = Import-Clixml -Path "$($rutaCredencial)\Impresoras.xml"
    } catch {
        Log -TipoEvento "ERROR" -Evento "credencial de impresora no se puede desencriptar"
        Exit
    }
    foreach($i in @($network_pwd.Keys)) {  
        $pd=$network_pwd[$i].GetNetworkCredential().Password  
        curl.exe -f -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -L -k -u "Admin:$($pd)" -o $DatosBaseImpresora $UrlSRV   
        if ($LASTEXITCODE -eq 0) {
            Expand-Archive -Path $DatosBaseImpresora -DestinationPath $DirectorioExtraccionDatosBaseImpresora -Force
            Remove-Variable -Name network_pwd -ErrorAction SilentlyContinue
            break
        }
    }   
}
function extraerDatos {
    param(
        $yo="Desconocido",
        $Impresora,
        $Index
    )
    $n=0    
    $BaseDeConocimiento=Get-Content -Path $esf_settings -Raw
    $DatosParciales=([regex]::Matches($BaseDeConocimiento, $patrones["Perfiles"])).Value
    
    if ($yo -eq "Desconocido"){Write-Host "CARGANDO PERFILES DISPONIBLES ..."}
    
    foreach ($i in @($DatosParciales)) {
        if ($yo -eq "Desconocido"){
            $n+=1
            $MisDatos["Perfil$($n)"]=[ordered]@{}
            $MisDatos["Perfil$($n)"]["UID"]=([regex]::Matches($i, $patrones["UID"])).Value
            $MisDatos["Perfil$($n)"]["HOST"]=([regex]::Matches($i, $patrones["HOST"])).Value
            $MisDatos["Perfil$($n)"]["RUTA"]=([regex]::Matches($i, $patrones["RUTA"])).Value
            $MisDatos["Perfil$($n)"]["RUTANUEVA"]=$MisDatos["Perfil$($n)"]["RUTA"].Replace($MisDatos["Perfil$($n)"]["HOST"], (ObtenerIp -Impresora $Impresora))
            $MisDatos["Perfil$($n)"]["NOMBREUSUARIO"]=([regex]::Matches($i, $patrones["NOMBREUSUARIO"])).Value
            Write-Host " "
            Write-Host "digita $($n) si eres $($MisDatos["Perfil$($n)"]["NOMBREUSUARIO"]) y tu ruta es $($MisDatos["Perfil$($n)"]["RUTA"])"
        } elseif ($yo -is [System.String]) {
            if ($i -like "*$($yo.Replace(' ',''))*") {
                $n+=1
                $MisDatos["Perfil$($n)"]=[ordered]@{}
                $MisDatos["Perfil$($n)"]["UID"]=([regex]::Matches($i, $patrones["UID"])).Value
                $MisDatos["Perfil$($n)"]["HOST"]=([regex]::Matches($i, $patrones["HOST"])).Value
                $MisDatos["Perfil$($n)"]["RUTA"]=([regex]::Matches($i, $patrones["RUTA"])).Value
                $MisDatos["Perfil$($n)"]["RUTANUEVA"]=$MisDatos["Perfil$($n)"]["RUTA"].Replace($MisDatos["Perfil$($n)"]["HOST"], (ObtenerIp -Impresora $Impresora))
                $MisDatos["Perfil$($n)"]["NOMBREUSUARIO"]=([regex]::Matches($i, $patrones["NOMBREUSUARIO"])).Value
                if (!(Test-Path -Path "$($RutaMemoria[$Index])\UID.dat")) { Set-Content -Path "$($RutaMemoria[$Index])\UID.dat" -Value $MisDatos["Perfil$($n)"]["UID"] } else { Add-Content -Path "$($RutaMemoria[$Index])\UID.dat" -Value $MisDatos["Perfil$($n)"]["UID"]}
                Log -TipoEvento "INFORMATIVO" -Evento "se ha encotrado el perfil de $($MisDatos["Perfil$($n)"]["NOMBREUSUARIO"])"
            } 
        }elseif ($yo -is [System.Object]) {
            foreach ($b in $yo) {
                if ($i -like "*$($b.Replace(' ',''))*") {
                    $n+=1
                    $MisDatos["Perfil$($n)"]=[ordered]@{}
                    $MisDatos["Perfil$($n)"]["UID"]=([regex]::Matches($i, $patrones["UID"])).Value
                    $MisDatos["Perfil$($n)"]["HOST"]=([regex]::Matches($i, $patrones["HOST"])).Value
                    $MisDatos["Perfil$($n)"]["RUTA"]=([regex]::Matches($i, $patrones["RUTA"])).Value
                    $MisDatos["Perfil$($n)"]["RUTANUEVA"]=$MisDatos["Perfil$($n)"]["RUTA"].Replace($MisDatos["Perfil$($n)"]["HOST"], (ObtenerIp -Impresora $Impresora))
                    $MisDatos["Perfil$($n)"]["NOMBREUSUARIO"]=([regex]::Matches($i, $patrones["NOMBREUSUARIO"])).Value
                    if (!(Test-Path -Path "$($RutaMemoria[$Index])\UID.dat")) { Set-Content -Path "$($RutaMemoria[$Index])\UID.dat" -Value $MisDatos["Perfil$($n)"]["UID"] } else { Add-Content -Path "$($RutaMemoria[$Index])\UID.dat" -Value $MisDatos["Perfil$($n)"]["UID"]}
                    Log -TipoEvento "INFORMATIVO" -Evento "se ha encotrado el perfil $($MisDatos["Perfil$($n)"]["NOMBREUSUARIO"]) de $($yo.Count) perfiles recordados"
                }
            }
        }     
    }
    if ($yo -eq "Desconocido"){
        while ($true) {
            $yoRaw=Read-Host "Quien eres ? [Recuerda elegir una opcion valida.]"
            [Int]$yoInt=$yoRaw
            if (($yoInt -ge 1) -and ($yoInt -le $MisDatos.Count) -and ($yoInt -ne "`n")){
                if (!(Test-Path -Path "$($RutaMemoria[$Index])\UID.dat")) {
                    Set-Content -Path "$($RutaMemoria[$Index])\UID.dat" -Value $MisDatos["Perfil$($yoInt)"]["UID"]
                } else {
                    Add-Content -Path "$($RutaMemoria[$Index])\UID.dat" -Value $MisDatos["Perfil$($yoInt)"]["UID"]
                }
                Write-Host "Se ha guardado el UID $($MisDatos["Perfil$($yoInt)"]["UID"]) correspondiente al usuario $($MisDatos["Perfil$($yoInt)"]["NOMBREUSUARIO"]) con ruta $($MisDatos["Perfil$($yoInt)"]["RUTA"])"
                break
            }   
        }
        $datosPerfilSeleccionado=$MisDatos["Perfil$($yoInt)"]
        $Global:MisDatos = [ordered]@{}
        $MisDatos["Perfil$($yoInt)"]=$datosPerfilSeleccionado
        return $true
    }
    if ($MisDatos.Count -ge 1){
        return $true
    } else {
        return $false
    }
}
function ActualizarNetworkUser {
    $patron='(?<=de_network_username">).*?(?=<\/setting>)'
    $Global:Contenido=([regex]::Replace($Global:Contenido, $patron, ".\Administrador"))
}
function ActualizarArchivoEsf {
    param(
        $Impresora
    )
    $Iguales=0
    Rename-Item -Path $esf_settings -NewName $ArchivoRenombrado
    $Global:Contenido=Get-Content -Path $esf_settingsTmp -Raw
    ActualizarNetworkUser
    try {
        $network_pwd = Import-Clixml -Path 'C:\Windows\System32\Impresoras\Lexmark\Impresora.xml'
    } catch {
        Log -TipoEvento "ERROR" -Evento "credencial de red no se puede desencriptar"
        Exit
    }
    $Contenido=$Global:Contenido.Replace("<setting name=`"de_network_username`">.\Administrador</setting>","<setting name=`"de_network_username`">.\Administrador</setting>`r`n`t`t`t<setting name=`"de_network_password`">$($network_pwd.GetNetworkCredential().Password)</setting>")
    Remove-Variable -Name network_pwd -ErrorAction SilentlyContinue
    foreach ($i in @($MisDatos.Keys)) {
        if ($MisDatos[$i]["RUTA"] -eq $MisDatos[$i]["RUTANUEVA"]) {
            Log -TipoEvento "Informativo" -Evento "perfil de $($MisDatos[$i]["NOMBREUSUARIO"]) aun es valido en la impresora $($Impresora)"
            $Iguales+=1
            continue
        }
        $Contenido=$Contenido.Replace($MisDatos[$i]["RUTA"],$MisDatos[$i]["RUTANUEVA"])
    }
    if ($Iguales -eq $MisDatos.Count) {
        if ($MisDatos.Count -ge 2) {
            Log -TipoEvento "Informativo" -Evento "los perfiles a editar aun son validos. no se realizan modificaciones en la impresora"
        } else {
            Log -TipoEvento "Informativo" -Evento "el perfil a editar aun es valido. no se realizan modificaciones en la impresora"
        }
        return $false
    }
    Set-Content -Path $esf_settings -Value $Contenido
    Remove-Item -Path $esf_settingsTmp
    Log -TipoEvento "Informativo" -Evento "Se ha reconstruido el archivo el archivo Esf"

    return $true
}
function Recomprimir {
    Compress-Archive -Path $DirectorioExtraccionDatosBaseImpresora\* -DestinationPath $DatosModificadosComprimidos -Force
    Log -TipoEvento "Informativo" -Evento "Archivo Esf Comprimido"
}
function SubirSrv {
    param(
        [string]$Impresora
    )
    $rutaCredencial='C:\Windows\System32\Impresoras\Lexmark'
    $UrlSRV="https://$Impresora/webservices/vcc/bundles"
    try {
        $network_pwd = Import-Clixml -Path "$($rutaCredencial)\Impresoras.xml"
    } catch {
        Log -TipoEvento "ERROR" -Evento "credencial de impresora no se puede desencriptar"
        Exit
    }
    foreach($i in @($network_pwd.Keys)) {    
        $pd=$network_pwd[$i].GetNetworkCredential().Password    
        curl.exe -f -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -L --data-binary "@$DatosModificadosComprimidos" -k -u "Admin:$($pd)" -o $DatosBaseImpresora $UrlSRV 
        if ($LASTEXITCODE -eq 0) {
            Log -TipoEvento "Informativo" -Evento "Archivo Subido correctamente."
            if ((Test-Path $DatosModificadosComprimidos)) {Remove-Item -Path $DatosModificadosComprimidos -Force}
            Remove-Variable -Name network_pwd -ErrorAction SilentlyContinue
            return 0
        } 
           
    }          
}
function validarInstalacion {
    if (Get-ScheduledTask -TaskName "AutoScan" -ErrorAction SilentlyContinue) {return $true} else {
        Log -TipoEvento "INFORMATIVO" -Evento "se procede a instalar AutoScan"
        $xml = Get-Content -Path "C:\ProgramData\ScanDinamico\ScanDinamico.xml" -Raw
        try {
            $network_pwd = Import-Clixml -Path 'C:\Windows\System32\Impresoras\Lexmark\Impresora.xml'
        } catch {
            Log -TipoEvento "ERROR" -Evento "credencial de red no se puede desencriptar"
            Exit
        }
        #$patron='(?<=<Arguments>).*(?=</Arguments>)'
        #$nuevosArgumentos = "-NoProfile -ExecutionPolicy Bypass -File `"C:\ProgramData\ScanDinamico\AutoScan.ps1`""
        #$Contenido=[regex]::Replace($xml,$patron,$nuevosArgumentos)
        #Set-Content -Path "C:\ProgramData\ScanDinamico\ScanDinamico.xml" -Value $Contenido
        #Register-ScheduledTask -TaskName "AutoScan" -Xml (Get-Content "C:\ProgramData\ScanDinamico\ScanDinamico.xml" | Out-String) -Force   
        Register-ScheduledTask -TaskName "AutoScan" -Xml $xml -User ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -Password ($network_pwd.GetNetworkCredential().Password)  -Force
        Remove-Variable -Name network_pwd -ErrorAction SilentlyContinue
        return $true 
    } 
}
function Memoria {
    param (
        $Impresora,
        $Index
    )
    if ((Test-Path "$($RutaMemoria[$Index])\UID.dat")) {
        return 0
    } else {
        if (!(Test-Path "$($RutaMemoria[$Index])")) {
            New-Item -Path "$($RutaMemoria[$Index])" -ItemType Directory -Force | Out-Null
        }
        return 1
    }
}
function main {
    param(
        [String]$Impresora,
        $Index
    )  
    (descargayDescompresionInfoImpresora -Impresora $Impresora)
    switch (Memoria -Impresora $Impresora -Index $Index) {
        0 { 
            Rename-Item -Path "$($RutaMemoria[$Index])\UID.dat" -NewName "$($RutaMemoria[$Index])\UID-.dat"
            $yo=Get-Content -Path "$($RutaMemoria[$Index])\UID-.dat"
            if(!(extraerDatos -yo $yo -Impresora $Impresora -Index $Index)) {
                Log -TipoEvento "INFORMATIVO" -Evento "el perfil recordado ya no esta disponible en la impresora."
            }
            if(ActualizarArchivoEsf -Impresora $Impresora) {
                Recomprimir
                & SubirSrv -Impresora $Impresora
            }
            Remove-Item -Path "$($RutaMemoria[$Index])\UID-.dat" -Force  
        }
        1 {
            extraerDatos -Impresora $Impresora -Index $Index
            if(ActualizarArchivoEsf -Impresora $Impresora) {
                Recomprimir
                & SubirSrv -Impresora $Impresora
            }
        }
        Default { 
            Exit   
        }
    }
    return 0
}
& validarInstalacion
if (!($IpImpresora -eq "0.0.0.0")) {
    while ($Intentos -ge 0) {
        
        if (!(ObtenerIp -Impresora $IpImpresora)) {$Intentos=$Intentos-1} else { 
            & main -Impresora $IpImpresora -Index 0
            break
        }

    }
    if ($Intentos -eq 0) {
        Log -TipoEvento "INFORMATIVO" -Evento "no se logro conectar con la impresora $($IpImpresora)."
    }
}
if (!($IpImpresora2 -eq "0.0.0.0")) {
    while ($Intentos -ge 0) {
        if (!(ObtenerIp -Impresora $IpImpresora2)) {$Intentos=$Intentos-1} else { 
            & main -Impresora $IpImpresora2 1
            break
        }
    }
    if ($Intentos -eq 0) {
        Log -TipoEvento "INFORMATIVO" -Evento "no se logro conectar con la impresora $($IpImpresora2)."
    }
}
& LimpiezaDescarga
exit 0