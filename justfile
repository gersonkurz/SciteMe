# Build automation for SciteMe.
# Requires: just, a Visual Studio Developer Command Prompt (msbuild on PATH),
# and MSIS 3.x (for packaging only).

set windows-shell := ["cmd.exe", "/c"]

solution := "SciteMe.slnx"

# Map native Windows architecture to MSBuild platform.
_arch := env_var_or_default("PROCESSOR_ARCHITECTURE", "AMD64")
platform := if _arch == "ARM64" { "ARM64" } else { "x64" }
platform_suffix := if _arch == "ARM64" { "arm64" } else { "x64" }

# Default: show available recipes.
default:
    @just --list

# Run MSBuild. Requires msbuild on PATH (use a Developer Command Prompt).
[private]
_msbuild configuration platform target="Build":
    msbuild {{solution}} /t:{{target}} /p:Configuration={{configuration}} /p:Platform={{platform}} /m /nologo /v:minimal

# Build Debug for the native platform.
build: (_msbuild "Debug" platform)

# Build both platform MSIs and the bundle executable.
release: package-all bundle

# Build Debug for x64.
build-x64: (_msbuild "Debug" "x64")

# Build Release for x64.
release-x64: (_msbuild "Release" "x64")

# Build Debug for ARM64.
build-arm64: (_msbuild "Debug" "ARM64")

# Build Release for ARM64.
release-arm64: (_msbuild "Release" "ARM64")

# Build Debug and Release for x64 and ARM64.
build-all: build-x64 release-x64 build-arm64 release-arm64

# Rebuild Debug and Release for x64 and ARM64.
rebuild-all: (_msbuild "Debug" "x64" "Rebuild") (_msbuild "Release" "x64" "Rebuild") (_msbuild "Debug" "ARM64" "Rebuild") (_msbuild "Release" "ARM64" "Rebuild")

# Build Debug for the native platform and launch SciTE.
run: build
    @bin\{{platform}}\Debug\SciTE.exe

# Stage Release payload for the native platform.
stage: (_stage platform "Release")

# Stage the native payload (with theme files) and launch the staged SciTE.
run-staged: stage
    @dist\stage\{{platform}}\SciTE.exe

# Stage Release payload for x64.
stage-x64: (_stage "x64" "Release")

# Stage Release payload for ARM64.
stage-arm64: (_stage "ARM64" "Release")

# Stage Release payloads for x64 and ARM64.
stage-all: stage-x64 stage-arm64

# Stage Release debug databases for the native platform.
stage-symbols: (_stage_symbols platform "Release")

# Stage Release debug databases for x64.
stage-symbols-x64: (_stage_symbols "x64" "Release")

# Stage Release debug databases for ARM64.
stage-symbols-arm64: (_stage_symbols "ARM64" "Release")

# Build MSI package for the native platform.
package: (_stage platform "Release") (_stage_symbols platform "Release") (_package "sciteme-" + platform_suffix + ".msis")

# Build x64 MSI package.
package-x64: stage-x64 stage-symbols-x64 (_package "sciteme-x64.msis")

# Build ARM64 MSI package.
package-arm64: stage-arm64 stage-symbols-arm64 (_package "sciteme-arm64.msis")

# Build x64 and ARM64 MSI packages.
package-all: package-x64 package-arm64

# Build the multi-architecture bundle executable.
bundle:
    msis /BUILD setup\setup-bundle.msis

# Generate staged application payload from upstream package data plus local binaries.
[private]
_stage platform configuration: (_msbuild configuration platform)
    @if exist dist\stage\{{platform}} rmdir /s /q dist\stage\{{platform}}
    @mkdir dist\stage\{{platform}}
    @robocopy wscite563\wscite dist\stage\{{platform}} /E /XF SciTE.exe Scintilla.dll Lexilla.dll *.pdb *.exp *.lib >nul & if errorlevel 8 exit /b 1
    @copy /Y bin\{{platform}}\{{configuration}}\SciTE.exe dist\stage\{{platform}}\SciTE.exe >nul
    @copy /Y bin\{{platform}}\{{configuration}}\Scintilla.dll dist\stage\{{platform}}\Scintilla.dll >nul
    @copy /Y bin\{{platform}}\{{configuration}}\Lexilla.dll dist\stage\{{platform}}\Lexilla.dll >nul
    @copy /Y theme\theme.lua dist\stage\{{platform}}\theme.lua >nul
    @copy /Y theme\theme.properties dist\stage\{{platform}}\theme.properties >nul
    @robocopy theme\palettes dist\stage\{{platform}}\palettes /E >nul & if errorlevel 8 exit /b 1

# Stage optional debug database payload for installer features or release zips.
[private]
_stage_symbols platform configuration: (_msbuild configuration platform)
    @if exist dist\symbols\{{platform}} rmdir /s /q dist\symbols\{{platform}}
    @mkdir dist\symbols\{{platform}}
    @copy /Y bin\{{platform}}\{{configuration}}\*.pdb dist\symbols\{{platform}}\ >nul

# Build one MSIS manifest from setup/.
[private]
_package script:
    @cd setup&& msis /BUILD /STANDALONE {{script}}

# Clean generated build output.
clean:
    if exist bin rmdir /s /q bin
    if exist temp rmdir /s /q temp
    if exist dist rmdir /s /q dist

# Clean, then build Debug for the native platform.
rebuild: clean build
