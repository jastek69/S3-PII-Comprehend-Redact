@echo off
REM Build Lambda Layer for PDF processing dependencies (Windows)
REM This creates a Lambda layer with PyPDF2 and reportlab

echo Building Lambda Layer for PDF processing...

REM Create temporary directory
set LAYER_DIR=lambda-layer
if exist %LAYER_DIR% rmdir /s /q %LAYER_DIR%
mkdir %LAYER_DIR%\python

REM Install dependencies
echo Installing Python dependencies...
pip install -r lambda\requirements.txt -t %LAYER_DIR%\python\

REM Create zip file
echo Creating layer zip file...
cd %LAYER_DIR%
powershell Compress-Archive -Path python -DestinationPath ..\lambda\pdf-layer.zip -Force
cd ..

REM Cleanup
rmdir /s /q %LAYER_DIR%

echo.
echo ✅ Lambda layer created: lambda\pdf-layer.zip
dir lambda\pdf-layer.zip
echo.
echo Now run: terraform apply
