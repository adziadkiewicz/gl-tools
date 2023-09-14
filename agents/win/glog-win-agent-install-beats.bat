@echo off

REM Skrypt instalujący agenta Graylog dla systemów Windows
REM (c) 2022 AD, Salutaris Sp. z o.o.
REM v4.1
REM
REM dodano weryfikacje dzialania jako Administrator
REM aktualizacja do wersji Sidecar (Graylog 3.x)

echo Wymagane uprawnienia administratora. Weryfikacja ...
net session >nul 2>&1
if %errorLevel% == 0 (
	echo OK: Masz uprawnienia administratora. Kontynuuje ...
) else (
	echo ERR: Wymagane uprawnienia administracyjne. Skrypt nie zostal uruchomiony jako administrator! 
	echo.
	goto NOPARAM
)

set argC=0
for %%x in (%*) do Set /A argC+=1
if "%argC%"=="6" goto OK

:NOPARAM
echo.
echo Brak parametrow, blednie podany parametr lub skrypt uruchomiony jako zwykly uzytkownik.
echo.
echo Skrypt instalujacy agenta oraz backend Graylog na platformach Windows
echo Wymagane jest aby skrypt uruchomiany byl w trybie "Uruchom jako Administrator"
echo.
echo Nalezy wykonac skrypt z nastepujacymi parametrami:
echo %0 -token TOKEN -url URL -glsver WERSJA_SIDECAR 
echo.
echo TOKEN - token uzytkownika graylog-sidecar konfiguracyjne w systmie Graylog, po przecinku
echo URL - adres url systemu Graylog w formacie {http^|https}:^/^/{adres_lub_nazwa}:{port}/api
echo WERSJA_SIDECAR - wersja Graylog Sidecar do zainstalowania
echo.
echo Przyklad uzycia:
echo.
echo %0 -token omaah4a95l6f58vnnjlgse3u0spm0gjvhrbr4e4vu561le2d5n8 -url {http^|https}:^/^/192.168.1.122:9000/api
echo.

GOTO KONIEC

:OK
SETLOCAL

SET gls-version=%6
SET needed_ver=%gls-version:-=.%
SET component=c:\Program Files\Graylog\sidecar\graylog-sidecar.exe

IF EXIST "%component%" GOTO check_ver
GOTO install

:check_ver
ECHO Katalog instalacyjny GLOG istnieje... sprawdzam wersje...
ECHO Lokalizacja instalacji: %component%

SET component=%component:\=\\%

FOR /f "usebackq delims=" %%a IN (`"WMIC DATAFILE WHERE name='%component%' get Version /format:Textvaluelist"`) do (
    FOR /f "delims=" %%# IN ("%%a") DO SET "%%#"
)

ECHO Wersja GLOG zainstalowana: %version%
ECHO Wersja GLOG wymagana: %needed_ver%

IF "%version%"=="%needed_ver%" (
	ECHO Instalacja nie wymagana. Koniec pracy skryptu.
	GOTO KONIEC
)


:install
echo Instaluje paczke collector_sidecar_installer ... 
graylog_sidecar_installer_%gls-version%.exe /S -SERVERURL="%4" -APITOKEN="%2"
echo #komenda: graylog_sidecar_installer_%gls-version%.exe /S -SERVERURL="%4" -APITOKEN="%2"

echo ... pauza 3s ...
ping 127.0.0.1 -n 3 > nul

echo Instaluje usluge Graylog Siedecar Collector ... 
echo #komenda: "C:\Program Files\graylog\sidecar\graylog-sidecar.exe" -service install

"C:\Program Files\graylog\sidecar\graylog-sidecar.exe" -service install

echo ... pauza 3s ...
ping 127.0.0.1 -n 3 > nul

set configYML=C:\Program Files\Graylog\sidecar\sidecar.yml

echo Tworze konfiguracje graylog ... 
echo Plik: "%configYML%"
echo.
@echo server_url: "%4" > "%configYML%"
@echo server_api_token: "%2" >> "%configYML%"
@echo node_id: "file:C:\\Program Files\\Graylog\\sidecar\\node-id" >> "%configYML%"
@echo node_name: "" >> "%configYML%"
@echo update_interval: 10 >> "%configYML%"
@echo tls_skip_verify: true >> "%configYML%"
@echo send_status: true >> "%configYML%"

:NEXT

echo ... pauza 3s ...
ping 127.0.0.1 -n 3 > nul

	REM echo Instaluje lokalny certyfikat RootCA ... 
	REM echo #komenda: %systemroot%\System32\certutil.exe -addstore Root root-cc.cer

	REM %systemroot%\System32\certutil.exe -addstore Root root-cc.cer

	REM echo ... pauza 3s ...
	REM ping 127.0.0.1 -n 3 > nul

	REM echo Instaluje lokalne certyfikaty SubCA ... 
	REM echo #komenda: %systemroot%\System32\certutil.exe -addstore CA file.cer

	REM %systemroot%\System32\certutil.exe -addstore CA file.cer

echo Zatrzymuje usluge Graylog Siedecar Collector ... 
echo #komenda: net stop "Graylog Sidecar"

net stop "Graylog Sidecar"

echo ... pauza 3s ...
ping 127.0.0.1 -n 3 > nul

echo Uruchamiam ponownie usluge Graylog Siedecar Collector ... 
echo #komenda: net start "Graylog Sidecar"

net start "Graylog Sidecar"

:KONIEC

