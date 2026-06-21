# Build automation for SciteMe.
# Requires: just and a Visual Studio 18 installation with MSBuild.

set windows-shell := ["cmd.exe", "/v:on", "/c"]

solution := "SciteMe.slnx"

# Map native Windows architecture to MSBuild platform.
_arch := env_var_or_default("PROCESSOR_ARCHITECTURE", "AMD64")
platform := if _arch == "ARM64" { "ARM64" } else { "x64" }
platform_suffix := if _arch == "ARM64" { "arm64" } else { "x64" }

# Default: show available recipes.
default:
    @just --list

# Run MSBuild with an explicit solution and a Visual Studio-discovered MSBuild path.
_msbuild configuration platform target="Build":
    @set "MSBUILD="& if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (for /f "usebackq delims=" %M in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\Current\Bin\amd64\MSBuild.exe`) do set "MSBUILD=%M")& if not defined MSBUILD set "MSBUILD=msbuild"& "!MSBUILD!" {{solution}} /t:{{target}} /p:Configuration={{configuration}} /p:Platform={{platform}} /m /nologo /v:minimal

# Build Debug for the native platform.
build:
    @just _msbuild Debug {{platform}}

# Build both platform MSIs and the bundle executable.
release:
    @just package-all
    @just bundle

# Build Debug for x64.
build-x64:
    @just _msbuild Debug x64

# Build Release for x64.
release-x64:
    @just _msbuild Release x64

# Build Debug for ARM64.
build-arm64:
    @just _msbuild Debug ARM64

# Build Release for ARM64.
release-arm64:
    @just _msbuild Release ARM64

# Build Debug and Release for x64 and ARM64.
build-all:
    @just build-x64
    @just release-x64
    @just build-arm64
    @just release-arm64

# Rebuild Debug and Release for x64 and ARM64.
rebuild-all:
    @just _msbuild Debug x64 Rebuild
    @just _msbuild Release x64 Rebuild
    @just _msbuild Debug ARM64 Rebuild
    @just _msbuild Release ARM64 Rebuild

# Build Debug for the native platform and launch SciTE.
run:
    @just build
    @bin\{{platform}}\Debug\SciTE.exe

# Stage Release payload for the native platform.
stage:
    @just _stage {{platform}} Release

# Stage Release payload for x64.
stage-x64:
    @just _stage x64 Release

# Stage Release payload for ARM64.
stage-arm64:
    @just _stage ARM64 Release

# Stage Release payloads for x64 and ARM64.
stage-all:
    @just stage-x64
    @just stage-arm64

# Stage Release debug databases for the native platform.
stage-symbols:
    @just _stage_symbols {{platform}} Release

# Stage Release debug databases for x64.
stage-symbols-x64:
    @just _stage_symbols x64 Release

# Stage Release debug databases for ARM64.
stage-symbols-arm64:
    @just _stage_symbols ARM64 Release

# Build MSI package for the native platform.
package:
    @just package-{{platform_suffix}}

# Build x64 MSI package.
package-x64:
    @just stage-x64
    @just stage-symbols-x64
    @just _package sciteme-x64.msis

# Build ARM64 MSI package.
package-arm64:
    @just stage-arm64
    @just stage-symbols-arm64
    @just _package sciteme-arm64.msis

# Build x64 and ARM64 MSI packages.
package-all:
    @just package-x64
    @just package-arm64

# Build the multi-architecture bundle executable.
bundle:
    @msis /BUILD setup\setup-bundle.msis

# Generate staged application payload from upstream package data plus local binaries.
_stage platform configuration:
    @just _msbuild {{configuration}} {{platform}}
    @if exist dist\stage\{{platform}} rmdir /s /q dist\stage\{{platform}}
    @mkdir dist\stage\{{platform}}
    @robocopy wscite563\wscite dist\stage\{{platform}} /E /XF SciTE.exe Scintilla.dll Lexilla.dll *.pdb *.exp *.lib >nul & if !ERRORLEVEL! GEQ 8 exit /b !ERRORLEVEL!
    @copy /Y bin\{{platform}}\{{configuration}}\SciTE.exe dist\stage\{{platform}}\SciTE.exe >nul
    @copy /Y bin\{{platform}}\{{configuration}}\Scintilla.dll dist\stage\{{platform}}\Scintilla.dll >nul
    @copy /Y bin\{{platform}}\{{configuration}}\Lexilla.dll dist\stage\{{platform}}\Lexilla.dll >nul

# Stage optional debug database payload for installer features or release zips.
_stage_symbols platform configuration:
    @just _msbuild {{configuration}} {{platform}}
    @if exist dist\symbols\{{platform}} rmdir /s /q dist\symbols\{{platform}}
    @mkdir dist\symbols\{{platform}}
    @copy /Y bin\{{platform}}\{{configuration}}\*.pdb dist\symbols\{{platform}}\ >nul

# Build one MSIS manifest from setup/.
_package script:
    @cd setup&& msis /BUILD /STANDALONE {{script}}

# Clean generated build output.
clean:
    if exist bin rmdir /s /q bin
    if exist temp rmdir /s /q temp
    if exist dist rmdir /s /q dist

# Clean, then build Debug for the native platform.
rebuild:
    @just clean
    @just build
