@echo off
REM WSL 설치 및 SSH 설정 스크립트 (포트 22 사용, 재부팅 후 자동 동작)
REM 관리자 권한으로 실행 필요

set "UBUNTU_VERSION=22.04"  REM 설치할 Ubuntu 버전 지정 (원하는 버전으로 변경 가능)
set "WSL_USER=myuser"       REM WSL 내 생성할 사용자 이름 (원하는 이름으로 변경)
set "WSL_PASSWORD=mypassword" REM 사용자 암호 설정 (원하는 암호로 변경)

REM Ubuntu 설치 여부 확인
for /f "tokens=*" %%i in ('wsl -l -q') do (
    echo %%i | findstr /r "^Ubuntu" >nul
    if not errorlevel 1 (
        set "UBUNTU_INSTALLED=1"
        goto :skip_install
    )
)

REM Ubuntu가 설치되지 않은 경우 설치 진행
echo Installing WSL...
wsl --install

echo Waiting for WSL to complete installation...
timeout /t 5 /nobreak >nul

REM WSL2 사용을 기본값으로 설정
wsl --set-default-version 2

echo Installing Ubuntu %UBUNTU_VERSION%...
wsl --install -d "Ubuntu-%UBUNTU_VERSION%"

echo Waiting for Ubuntu installation to complete...
timeout /t 5 /nobreak >nul

REM 사용자 계정 및 암호 생성
echo Setting up user %WSL_USER%...

wsl -d "Ubuntu-%UBUNTU_VERSION%" -- bash -c " adduser --disabled-password --gecos '' %WSL_USER%; echo '%WSL_USER%:%WSL_PASSWORD%' | chpasswd; usermod -aG sudo %WSL_USER%; "

:skip_install
echo Ubuntu already installed or installation complete.

echo Configuring Windows firewall and port forwarding...

REM Windows 방화벽에서 포트 22를 열어줌
netsh advfirewall firewall add rule name="WSL SSH" dir=in action=allow protocol=TCP localport=22

REM 포트 포워딩 설정 (Windows 22 -> WSL 22)
netsh interface portproxy add v4tov4 listenport=22 listenaddress=0.0.0.0 connectport=22 connectaddress=127.0.0.1

REM WSL 재부팅 시 자동으로 SSH 서버가 동작하도록 설정
echo Creating task to start SSH server on reboot...
schtasks /create /tn "StartSSHOnWSL" /tr "wsl -u root service ssh restart" /sc onstart /ru System

REM 포트포워딩 유지 설정 (재부팅 후에도 적용되도록 레지스트리 추가)
reg add HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules /v "WSLSSHAllow" /t REG_SZ /d "v2.0|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=22|RA4=0|RA4Mask=0|LA4=127.0.0.1|LA4Mask=255.255.255.255|RA6=0|RA6Mask=0|LA6=::1|LA6Mask=ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff|" /f

echo Setup complete. You can now connect using SSH on port 22 with user %WSL_USER%.

REM SSH 설치 및 설정을 위한 명령을 Ubuntu 내에서 실행
echo Setting up SSH in Ubuntu...

wsl -u root -- bash -c " apt-get update && apt-get install -y openssh-server; service ssh start; sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config; sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config; service ssh restart; "


