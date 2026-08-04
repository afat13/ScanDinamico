# ScanDinamico
ScanDinamico es un Script que mantiene la ruta smb de escaneo en la impresora actualizada cuando esta esta por IP y el DHCP de la red esta activo. actualmente esta diseñado para impresoras lexmark mx622 
---
# POR AHORA AUTOSCAN NO ES TOLERANTE A LA CONDICION DE CARRERA.
---
## SE IRAN SOLUCIONANDO EN FUTURAS VERSIONES. 
---
# FUNCIONAMIENTO
## preparación de entorno.
debe tener una carpeta que contenga AutoScan.ps1, Instalador.ps1, opcional esta el XML de la tarea programada, esto para que el sistema autoejecute AutoScan.ps1
---
## comportamiento
cuando se instala por primera vez AutoScan desde Instalador.ps1 se crearan unas carpetas especificas donde se guardaran los datos de reintentos, direcciones de impresoras y las credenciales requeridas para autenticarse, es importante que LA INSTALACION sea desde eL ADMINISTRADOR INTEGRADO.
una vez creados esos directorios Instalador.ps1 encriptara las credenciales proporcionadas por usted dentro del codigo. las credenciales seran encriptadas mediantes *DPAPI* asi que solo seran desencriptables por el usuario que las cargo.
seguido se ejecutara AutoScan.ps1 el cual se registrara asi mismo como tarea programada. para su auto ejecución, sinembargo es opcional, si no provee el XML no se registrara como tareas.
seguido se determina automaticamete cuan direccion ipv4 suya tiene conección con la impresora cuya direccion fue solicitada durante la instalación.
cuando se determine la direccion se procedera a intentar a utenticarse en la impresora y descargar el archivo de configuración, haciendo uso de expresiones regulares se le mostrara a usted en pantalla los perfiles disponibles en la impresora y un numero para que pueda referenciarlo mas adelante cuando se le pregunte quien es usted en la impresora.

una vez usted defina quien es en la impresora se guardara en UID del perfil para posteriores ejecuciones, seguido de esto se actualizara la propiedadad de ruta de red con su direccion Ipv4 vigente al momento. se reconstruira el archivo de configuración de la impresora con los cambios y se subira a la impresora.

si configuro o no la persistencia en la siguiente ejecucion ya sea manula o automatica se actualizara unicamente el perfil con el UID obtenido de la primera instalación.

