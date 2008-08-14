@echo off
REM   The contents of this file are subject to the Mozilla Public License
REM   Version 1.1 (the "License"); you may not use this file except in
REM   compliance with the License. You may obtain a copy of the License at
REM   http://www.mozilla.org/MPL/
REM
REM   Software distributed under the License is distributed on an "AS IS"
REM   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
REM   License for the specific language governing rights and limitations
REM   under the License.
REM
REM   The Original Code is RabbitMQ.
REM
REM   The Initial Developers of the Original Code are LShift Ltd.,
REM   Cohesive Financial Technologies LLC., and Rabbit Technologies Ltd.
REM
REM   Portions created by LShift Ltd., Cohesive Financial Technologies
REM   LLC., and Rabbit Technologies Ltd. are Copyright (C) 2007-2008
REM   LShift Ltd., Cohesive Financial Technologies LLC., and Rabbit
REM   Technologies Ltd.;
REM
REM   All Rights Reserved.
REM
REM   Contributor(s): ______________________________________.
REM

if "%RABBITMQ_BASE%"=="" (
    set RABBITMQ_BASE=%APPDATA%\RabbitMQ
)

if "%NODENAME%"=="" (
    set NODENAME=rabbit
)

if "%NODE_IP_ADDRESS%"=="" (
    set NODE_IP_ADDRESS=0.0.0.0
)

if "%NODE_PORT%"=="" (
    set NODE_PORT=5672
)

if "%ERLANG_HOME%"=="" (
    set ERLANG_HOME=%~dp0%..\..\..
)

if not exist "%ERLANG_HOME%\bin\erl.exe" (
    echo.
    echo ******************************
    echo ERLANG_HOME not set correctly. 
    echo ******************************
    echo.
    echo Please either set ERLANG_HOME to point to your Erlang installation or place the
    echo RabbitMQ server distribution in the Erlang lib folder.
    echo.
    exit /B
)

set RABBITMQ_BASE_UNIX=%RABBITMQ_BASE:\=/%

set MNESIA_BASE=%RABBITMQ_BASE_UNIX%/db
set LOG_BASE=%RABBITMQ_BASE_UNIX%/log


rem We save the previous logs in their respective backup
rem Log management (rotation, filtering based of size...) is left as an exercice for the user.

set BACKUP_EXTENSION=.bak

set LOGS="%RABBITMQ_BASE%\log\%NODENAME%.log"
set SASL_LOGS="%RABBITMQ_BASE%\log\%NODENAME%-sasl.log"

set LOGS_BACKUP="%RABBITMQ_BASE%\log\%NODENAME%.log%BACKUP_EXTENSION%"
set SASL_LOGS_BAKCUP="%RABBITMQ_BASE%\log\%NODENAME%-sasl.log%BACKUP_EXTENSION%"

if exist %LOGS% (
	type %LOGS% >> %LOGS_BACKUP%
)
if exist %SASL_LOGS% (
	type %SASL_LOGS% >> %SASL_LOGS_BAKCUP%
)

rem End of log management


set CLUSTER_CONFIG_FILE=%RABBITMQ_BASE%\rabbitmq_cluster.config
set CLUSTER_CONFIG=
if not exist "%CLUSTER_CONFIG_FILE%" GOTO L1
set CLUSTER_CONFIG=-rabbit cluster_config \""%CLUSTER_CONFIG_FILE:\=/%"\"
:L1

set MNESIA_DIR=%MNESIA_BASE%/%NODENAME%-mnesia

"%ERLANG_HOME%\bin\erl.exe" ^
-pa "%~dp0..\ebin" ^
-noinput ^
-boot start_sasl ^
-sname %NODENAME% ^
-s rabbit ^
+W w ^
+A30 ^
-kernel inet_default_listen_options "[{sndbuf, 16384}, {recbuf, 4096}]" ^
-rabbit tcp_listeners "[{\"%NODE_IP_ADDRESS%\", %NODE_PORT%}]" ^
-kernel error_logger {file,\""%LOG_BASE%/%NODENAME%.log"\"} ^
-sasl errlog_type error ^
-sasl sasl_error_logger {file,\""%LOG_BASE%/%NODENAME%-sasl.log"\"} ^
-os_mon start_cpu_sup true ^
-os_mon start_disksup false ^
-os_mon start_memsup false ^
-os_mon start_os_sup false ^
-mnesia dir \""%MNESIA_DIR%"\" ^
%CLUSTER_CONFIG% ^
%RABBIT_ARGS% ^
%*

