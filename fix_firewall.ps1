# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting admin privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $MyInvocation.MyCommand.Path)
    exit
}

Write-Host "Adding Firewall Rules for Finzo..." -ForegroundColor Green

# Remove existing rules just in case
netsh advfirewall firewall delete rule name="Finzo Backend 5001"
netsh advfirewall firewall delete rule name="Finzo RAG 5002"

# Add new rules
netsh advfirewall firewall add rule name="Finzo Backend 5001" dir=in action=allow protocol=TCP localport=5001
if ($?) { Write-Host "✅ Port 5001 (Node.js) opened successfully." -ForegroundColor Green }
else { Write-Host "❌ Failed to open port 5001." -ForegroundColor Red }

netsh advfirewall firewall add rule name="Finzo RAG 5002" dir=in action=allow protocol=TCP localport=5002
if ($?) { Write-Host "✅ Port 5002 (Python RAG) opened successfully." -ForegroundColor Green }
else { Write-Host "❌ Failed to open port 5002." -ForegroundColor Red }

Write-Host "`nfirewall configuration complete. Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
