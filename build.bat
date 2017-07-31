@ECHO OFF &SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

SET BUILD_DIR=%~dp0
SET SCRIPT_NAME=%~0

:: Overridable build locations
IF "%DEFAULT_ZLIB_DIST%"=="" SET DEFAULT_ZLIB_DIST=%BUILD_DIR%\zlib
IF "%OBJDIR_ROOT%"=="" SET OBJDIR_ROOT=%BUILD_DIR%\target
IF "%CONFIGS_DIR%"=="" SET CONFIGS_DIR=%BUILD_DIR%\configs

:: Options to control the build
IF "%MSVC_VERSION%"=="" (
    SET MSVC_VERSION_INT=14.1
    SET BUILD_PLATFORM_NAME=windows
) ELSE (
    SET MSVC_VERSION_INT=%MSVC_VERSION%
    SET BUILD_PLATFORM_NAME=windows-msvc-%MSVC_VERSION%
)
IF "%MSVC_VERSION_INT%"=="14.1" (
    SET MSBUILD_EXE=C:\Program Files (x86^)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe
    SET TOOLSET=v141
) ELSE IF "%MSVC_VERSION_INT%"=="14.0" (
    SET MSBUILD_EXE=C:\Program Files (x86^)\MSBuild\14.0\Bin\MSBuild.exe
    SET TOOLSET=v140
) ELSE (
    echo Unsupported MSVC version "%MSVC_VERSION_INT%". 1>&2
    echo. 1>&2
    GOTO print_usage
)

:: Options to control the build
IF "%MSVC_BUILD_PARALLEL%"=="" SET MSVC_BUILD_PARALLEL=%NUMBER_OF_PROCESSORS%

:: Include files to copy
SET ZLIB_INCLUDE_FILES=zlib.h

:: Include files which are platform-specific
SET PLATFORM_SPECIFIC_HEADERS=zconf.h

:: Calculate the path to the zlib-dist repository
IF EXIST "%~f1" (
	SET PATH_TO_ZLIB_DIST=%~f1
	SHIFT
) ELSE (
	SET PATH_TO_ZLIB_DIST=%DEFAULT_ZLIB_DIST%
)
IF NOT EXIST "%PATH_TO_ZLIB_DIST%\CMakeLists.txt" (
    echo Invalid ZLib directory: 1>&2
    echo     "%PATH_TO_ZLIB_DIST%" 1>&2
    GOTO print_usage
)

:: Set up the target and the command-line arguments
SET TARGET=%1
SHIFT
:GetArgs
IF "%~1" NEQ "" (
    SET CL_ARGS=%CL_ARGS% %1
    SHIFT
    GOTO GetArgs
)
IF DEFINED CL_ARGS SET CL_ARGS=%CL_ARGS:~1%

:: Call the appropriate function based on target
IF "%TARGET%"=="clean" (
    CALL :do_clean %CL_ARGS% || exit /B 1
) ELSE (
    CALL :do_build %TARGET% %CL_ARGS% || exit /B 1
)
:: Success
exit /B 0


:print_usage
    echo Usage: %SCRIPT_NAME% \path\to\zlib-dist ^<arch^|'clean'^> 1>&2
    echo. 1>&2
    echo "\path\to\zlib-dist" is optional and defaults to: 1>&2
    echo     "%DEFAULT_ZLIB_DIST%" 1>&2
    echo. 1>&2
    CALL :get_archs
    echo Possible architectures are:
    echo     !ARCHS: =, ! 1>&2
    echo. 1>&2
    echo When specifying clean, you may optionally include an arch to clean, 1>&2
    echo i.e. "%SCRIPT_NAME% clean i386" to clean only the i386 architecture. 1>&2
    echo. 1>&2
@exit /B 1

:get_archs
    @ECHO OFF
    SET ARCHS=
    FOR %%F IN ("%CONFIGS_DIR%\setup-windows.*.bat") DO (
        SET ARCH=%%~nF
        SET ARCHS=!ARCHS! !ARCH:setup-windows.=!
    )
    IF DEFINED ARCHS SET ARCHS=%ARCHS:~1%
@exit /B 0

:do_msbuild_zlib
    "%MSBUILD_EXE%" contrib\vstudio\vc14\zlibvc.sln /t:zlibstat:Rebuild ^
                    /p:Configuration=%~1 /p:Platform=%VS_PLATFORM% /m:%MSVC_BUILD_PARALLEL% ^
                    /p:TargetName=%~2 /p:OutDir=%~3\lib\ /p:PlatformToolset=%TOOLSET% || exit /B %ERRORLEVEL%
@exit /B 0

:do_build_zlib
    @ECHO OFF
    SET TARGET=%~1
    SET OUTPUT_ROOT=%~2
    SET BUILD_ROOT=%OUTPUT_ROOT%\build\zlib

    IF "%PLATFORM_DEFINITION%"=="" (
        echo PLATFORM_DEFINITION is not set for %TARGET% & exit /B 1
    )

    IF NOT EXIST "%BUILD_ROOT%" (
        echo Creating build directory for %TARGET%...
        mkdir "%BUILD_ROOT%" || exit /B %ERRORLEVEL%
        xcopy /S "%PATH_TO_ZLIB_DIST%" "%BUILD_ROOT%" || exit /B %ERRORLEVEL%        
    )

    PUSHD "%BUILD_ROOT%" || exit /B %ERRORLEVEL%
    echo Building architecture "%~1"...
    CALL :do_msbuild_zlib ReleaseWithoutAsm zlib "%OUTPUT_ROOT%" || (
        POPD & exit /B 1
    )
    
    echo Building debug architecture "%~1"...
    CALL :do_msbuild_zlib Debug zlib-dbg "%OUTPUT_ROOT%" || (
        POPD & exit /B 1
    )
    
    echo Copying include files...
    IF EXIST "%OUTPUT_ROOT%\include" rmdir /Q /S "%OUTPUT_ROOT%\include"
    mkdir "%OUTPUT_ROOT%\include"
    :: Copy the zlib include files
    copy /Y "%PATH_TO_ZLIB_DIST%\"*.h "%OUTPUT_ROOT%\include" || (
        POPD & exit /B 1
    )

    :: Update platform-specific headers
    FOR %%h in (%PLATFORM_SPECIFIC_HEADERS%) DO (
        echo Updating header '%%h' for %TARGET%..."
        echo #if %PLATFORM_DEFINITION% >"%OUTPUT_ROOT%\include\%%h.tmp"
        type "%OUTPUT_ROOT%\include\%%h" >>"%OUTPUT_ROOT%\include\%%h.tmp"
        echo #endif  >>"%OUTPUT_ROOT%\include\%%h.tmp"
        move /y "%OUTPUT_ROOT%\include\%%h.tmp" "%OUTPUT_ROOT%\include\%%h" || (
            POPD & exit /B 1
        )
    )

    POPD & echo Done!    
@exit /B 0

:do_build
    @ECHO OFF
    SET CONFIG_SETUP=%CONFIGS_DIR%\setup-windows.%~1.bat
    
    :: Clean here - in case we pass a "clean" command
    IF "%~2"=="clean" (
        CALL :do_clean %~1
        exit /B %ERRORLEVEL%
    )

    IF EXIST "%CONFIG_SETUP%" (
        :: Load configuration files
        IF EXIST "%CONFIGS_DIR%\setup-windows.bat" (
            CALL "%CONFIGS_DIR%\setup-windows.bat" || exit /B 1
        )
        
        :: Generate the project and build
        CALL "%CONFIG_SETUP%" || exit /B 1
        CALL :do_build_zlib %~1 "%OBJDIR_ROOT%\objdir-%BUILD_PLATFORM_NAME%.%~1" || exit /B %ERRORLEVEL%
                
    ) ELSE (
        echo Missing/invalid target "%~1" 1>&2
        GOTO print_usage
    )
@exit /B 0

:do_clean
    @ECHO OFF
    IF "%~1"=="" (
        echo Cleaning up all builds in "%OBJDIR_ROOT%"...
        FOR /D %%D IN ("%OBJDIR_ROOT%\objdir-*") DO rmdir /Q /S "%%D" 2>NUL
    ) ELSE (
        echo Cleaning up %~1 builds in "%OBJDIR_ROOT%"...
        rmdir /Q /S "%OBJDIR_ROOT%\objdir-%~1" 2>NUL
        rmdir /Q /S "%OBJDIR_ROOT%\objdir-%BUILD_PLATFORM_NAME%.%~1" 2>NUL
        IF "%~1"=="headers" SET CLEAN_HEADERS=yes
    )

    :: Remove some leftovers
    rmdir /Q "%OBJDIR_ROOT%" 2>NUL
@exit /B 0
