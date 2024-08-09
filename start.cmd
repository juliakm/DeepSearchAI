@echo off

set NODE_OPTIONS=--max_old_space_size=8192

echo Checking Azure login status...
call az account show >nul 2>&1
if "%errorlevel%" neq "0" (
    echo Not logged in. Logging into Azure...
    az login
    if "%errorlevel%" neq "0" (
        echo Azure login failed.
        exit /B %errorlevel%
    )
) else (
    echo Already logged in to Azure.
)

echo.
echo Restoring backend python packages
echo.
call python -m pip install -r requirements.txt
if "%errorlevel%" neq "0" (
    echo Failed to restore backend python packages
    exit /B %errorlevel%
)

echo.
echo Restoring frontend npm packages
echo.
cd frontend
call npm install
if "%errorlevel%" neq "0" (
    echo Failed to restore frontend npm packages
    exit /B %errorlevel%
)

echo.
echo Building and starting frontend
echo.
call npm run build
if "%errorlevel%" neq "0" (
    echo Failed to start frontend
    exit /B %errorlevel%
)

echo.    
echo Starting backend    
echo.    
cd ..  

start http://127.0.0.1:50505
call python -m uvicorn app:app  --port 50505 --reload
REM call python3 -m gunicorn  --workers 1 --threads 16 app:app -- port 50505 --reload
if "%errorlevel%" neq "0" (    
    echo Failed to start backend    
    exit /B %errorlevel%    
) 

