@echo off
REM WSL installation and SSH setup script (using port 22, auto-start after reboot)
REM Requires administrator privileges

set "UBUNTU_VERSION=22.04"  REM Specify the Ubuntu version to install (can be changed to desired version)
set "WSL_USER=myuser"       REM Specify the username to create in WSL (can be changed to desired name)
set "WSL_PASSWORD=mypassword" REM Set the user password (can be changed to desired password)

REM Check if Ubuntu is installed
for /f "tokens=*" %%i in ('wsl -l -q') do (
    echo %%i | findstr /r "^Ubuntu" >nul
    if not errorlevel 1 (
        set "UBUNTU_INSTALLED=1"
        goto :skip_install
    )
)

REM If Ubuntu is not installed, proceed with installation
echo Installing WSL...
wsl --install

echo Waiting for WSL to complete installation...
timeout /t 5 /nobreak >nul

REM Set WSL2 as the default version
wsl --set-default-version 2

echo Installing Ubuntu %UBUNTU_VERSION%...
wsl --install -d "Ubuntu-%UBUNTU_VERSION%"

echo Waiting for Ubuntu installation to complete...
timeout /t 5 /nobreak >nul

REM Create user account and set password
echo Setting up user %WSL_USER%...

wsl -d "Ubuntu-%UBUNTU_VERSION%" -- bash -c " adduser --disabled-password --gecos '' %WSL_USER%; echo '%WSL_USER%:%WSL_PASSWORD%' | chpasswd; usermod -aG sudo %WSL_USER%; "

:skip_install
echo Ubuntu already installed or installation complete.

echo Configuring Windows firewall and port forwarding...

REM Open port 22 in Windows firewall
netsh advfirewall firewall add rule name="WSL SSH" dir=in action=allow protocol=TCP localport=22

REM Set up port forwarding (Windows 22 -> WSL 22)
netsh interface portproxy add v4tov4 listenport=22 listenaddress=0.0.0.0 connectport=22 connectaddress=127.0.0.1

REM Configure SSH server to start automatically on WSL reboot
echo Creating task to start SSH server on reboot...
schtasks /create /tn "StartSSHOnWSL" /tr "wsl -u root service ssh restart" /sc onstart /ru System

REM Maintain port forwarding settings (add to registry for persistence after reboot)
reg add HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules /v "WSLSSHAllow" /t REG_SZ /d "v2.0|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=22|RA4=0|RA4Mask=0|LA4=127.0.0.1|LA4Mask=255.255.255.255|RA6=0|RA6Mask=0|LA6=::1|LA6Mask=ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff|" /f

echo Setup complete. You can now connect using SSH on port 22 with user %WSL_USER%.

REM Execute commands to install and configure SSH in Ubuntu
echo Setting up SSH in Ubuntu...

wsl -u root -- bash -c " apt-get update && apt-get install -y openssh-server; service ssh start; sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config; sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config; service ssh restart; "
