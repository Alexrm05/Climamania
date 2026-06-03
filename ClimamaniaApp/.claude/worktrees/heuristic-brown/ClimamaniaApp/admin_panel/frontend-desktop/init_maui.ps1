# Ejecutar con PowerShell despues de instalar el .NET SDK
# Crea el proyecto .NET MAUI en la carpeta esperada

$projectPath = "c:\Users\alexr\Desktop\CLIMAMANIA\admin_panel\frontend-desktop\AdminPanelClimamania"

dotnet new maui -n AdminPanelClimamania -o $projectPath
