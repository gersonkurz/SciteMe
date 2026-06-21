# Build automation for SciteMe.
# Requires: just, Visual Studio 18 dev environment, msbuild on PATH.

set windows-shell := ["cmd.exe", "/v:on", "/c"]

solution := "SciteMe.slnx"

# Map native Windows architecture to MSBuild platform.
_arch := env_var_or_default("PROCESSOR_ARCHITECTURE", "AMD64")
platform := if _arch == "ARM64" { "ARM64" } else { "x64" }

# Default: show available recipes.
default:
    @just --list

# Run MSBuild with a normalized Path environment for C++ tool tasks.
_msbuild configuration platform target="Build":
    @set "KEEP=%PATH%"&& set PATH=&& set "Path=!KEEP!"&& msbuild {{solution}} /t:{{target}} /p:Configuration={{configuration}} /p:Platform={{platform}} /m /nologo /v:minimal

# Build Debug for the native platform.
build:
    @just _msbuild Debug {{platform}}

# Build Release for the native platform.
release:
    @just _msbuild Release {{platform}}

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

# Clean generated build output.
clean:
    if exist bin rmdir /s /q bin
    if exist temp rmdir /s /q temp

# Clean, then build Debug for the native platform.
rebuild:
    @just clean
    @just build
