@echo off
REM ==================================================================================
REM Windows Batch Script for HLS-UART Vivado Project
REM ==================================================================================
REM Description: Automates the entire Vivado build process on Windows
REM Usage: Double-click this file or run from command prompt
REM ==================================================================================

echo ==================================================================================
echo HLS-UART Vivado Project Build Script
echo ==================================================================================
echo.

REM Check if Vivado is in PATH
where vivado >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Vivado not found in PATH
    echo Please add Vivado bin directory to your PATH or run this from Vivado command prompt
    echo.
    echo Example: C:\Xilinx\Vivado\2019.2\bin
    pause
    exit /b 1
)

REM Get Vivado version
for /f "tokens=*" %%a in ('vivado -version ^| findstr /C:"Vivado"') do set VIVADO_VER=%%a
echo Found: %VIVADO_VER%
echo.

REM Menu
echo Select operation:
echo 1. Create new project
echo 2. Build existing project (synthesis + implementation + bitstream)
echo 3. Clean project
echo 4. Full flow (create + build)
echo 5. Exit
echo.
set /p choice="Enter choice (1-5): "

if "%choice%"=="1" goto create
if "%choice%"=="2" goto build
if "%choice%"=="3" goto clean
if "%choice%"=="4" goto full
if "%choice%"=="5" goto end
echo Invalid choice
pause
exit /b 1

:create
echo.
echo ==================================================================================
echo Creating Vivado Project...
echo ==================================================================================
vivado -mode batch -source create_uart_project.tcl
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Project creation failed
    pause
    exit /b 1
)
echo.
echo Project created successfully!
goto end

:build
echo.
echo ==================================================================================
echo Building Vivado Project...
echo ==================================================================================
echo This may take 10-30 minutes depending on your system...
echo.
vivado -mode batch -source build_project.tcl
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed
    pause
    exit /b 1
)
echo.
echo Build completed successfully!
goto end

:clean
echo.
echo WARNING: This will delete the vivado_project directory
set /p confirm="Are you sure? (Y/N): "
if /i not "%confirm%"=="Y" goto end
echo.
echo Cleaning project...
if exist vivado_project rmdir /s /q vivado_project
if exist .Xil rmdir /s /q .Xil
if exist vivado*.jou del /q vivado*.jou
if exist vivado*.log del /q vivado*.log
echo Project cleaned!
goto end

:full
echo.
echo ==================================================================================
echo Running Full Flow (Create + Build)...
echo ==================================================================================
echo.
call :create
if %ERRORLEVEL% NEQ 0 exit /b 1
echo.
echo Waiting 5 seconds before starting build...
timeout /t 5 /nobreak >nul
echo.
call :build
goto end

:end
echo.
echo ==================================================================================
echo Script completed
echo ==================================================================================
echo.
pause
