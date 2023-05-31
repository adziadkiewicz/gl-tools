@echo off

REM Skrypt instalujący agenta Graylog dla systemów Windows
REM (c) 2017 AD, Salutaris Sp. z o.o.
REM v 4.1
REM
REM Dopasowane do wersji 3.0 skryptu oraz Graylog 3.x

cd /D "%~dp0"

glog-win-agent-install-beats.bat -token 1uniuhap4q27gt8b28cg0c2taaqkig9nfa7vrin9kd1euno1p83k -url https:^/^/192.168.200.90:9000/api -glsver 1.4.0-1 