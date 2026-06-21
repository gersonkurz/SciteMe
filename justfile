# Build automation for SciteMe.
#
# Two workflows -- you either build for THIS machine or cut a full release:
#
#   Develop on this machine
#     just run          Build Debug and launch (fast; runs from bin\, no themes)
#     just run-staged   Stage the Release payload (incl. themes) and launch it
#     just build        Build Debug only
#     just rebuild      Clean, then build Debug
#
#   Cut a release (always both architectures)
#     just release      x64 + ARM64 MSIs and the multi-arch bundle, into setup\
#
#   just clean          Remove bin\, temp\, dist\
#
# Requires a Visual Studio 2026 Developer shell (msbuild on PATH); `release`
# also needs MSIS 3.x. Per-architecture sub-steps are intentionally private --
# building selectively for an architecture you are not on is not a workflow.

set windows-shell := ["cmd.exe", "/c"]

solution := "SciteMe.slnx"

# Native architecture -> MSBuild platform (for the dev workflow).
_arch := env_var_or_default("PROCESSOR_ARCHITECTURE", "AMD64")
platform := if _arch == "ARM64" { "ARM64" } else { "x64" }

# Default: show available recipes.
default:
    @just --list

# Build Debug for this machine.
build: (_msbuild "Debug" platform)

# Clean, then build Debug for this machine.
rebuild: clean build

# Build Debug and launch SciTE (from bin\; no staged themes).
run: build
    @bin\{{platform}}\Debug\SciTE.exe

# Stage the Release payload (incl. theme files) and launch the staged SciTE.
run-staged: (_stage platform "Release")
    @dist\stage\{{platform}}\SciTE.exe

# Cut a full release: x64 + ARM64 MSIs and the multi-arch bundle, into setup\.
release: (_package-arch "x64" "x64") (_package-arch "ARM64" "arm64") _bundle

# Clean generated build output.
clean:
    if exist bin rmdir /s /q bin
    if exist temp rmdir /s /q temp
    if exist dist rmdir /s /q dist

# --- internal machinery (hidden from `just --list`) -------------------------

# Fail early with a clear message when not run from a VS 2026 Developer shell.
# A Developer Command Prompt / Developer PowerShell sets VisualStudioVersion and
# puts msbuild on PATH; without it the build fails cryptically.
[private]
_require-devshell:
    @if not "%VisualStudioVersion%"=="18.0" (echo. & echo ERROR: This needs a Visual Studio 2026 Developer shell. & echo Open "Developer Command Prompt for VS 2026" or "Developer PowerShell for VS 2026", then retry. & echo Expected VisualStudioVersion=18.0 but found "%VisualStudioVersion%". & exit /b 1)

# Run MSBuild for one configuration/platform.
[private]
_msbuild configuration platform target="Build": _require-devshell
    msbuild {{solution}} /t:{{target}} /p:Configuration={{configuration}} /p:Platform={{platform}} /m /nologo /v:minimal

# Build, stage, stage symbols, and package the MSI for one architecture.
[private]
_package-arch platform suffix: (_stage platform "Release") (_stage_symbols platform "Release") (_package "sciteme-" + suffix + ".msis")

# Build the multi-architecture bundle executable.
[private]
_bundle:
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
