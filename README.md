## ZLib (Windows) Building ##

This project provides some prebuilt ZLib configuration scripts for easy building on Windows platforms.  It contains as a submodule, the [toonetown/zlib][zlib-release] project.

You can check this directory out in any location on your computer, but the default location that the `build.bat` script looks for is as a parent directory to where you check out the [toonetown/zlib][zlib-release] git project.  By default, this project contains a submodule of the subproject in the correct locations.

[zlib-release]: https://github.com/toonetown/zlib

### Requirements ###

The following are supported to build the ZLib project:

To build on Windows:

 * Windows 10
 
 * Visual Studio 2017 (or 2015)
     * Make sure and install `Programming Languages | Visual C++ | Common Tools for Visual C++ 2017` as well
     * If you have both 2017 and 2015 installed, you can select to build for 2015 by setting `SET MSVC_VERSION=14.0` (the default is to use 14.1) prior to running the `build.bat` file.

     
### Build Steps ###

You can build the libraries using the `build.bat` script:

    ./build.bat [/path/to/zlib-dist] <plat.arch|plat|'clean'>

Run `./build.bat` itself to see details on its options.

You can modify the execution of the scripts by setting various environment variables.  See the script sources for lists of these variables.

There is a `build.sh` which will package and copy the output variables - but no other platforms besides Windows are supported for building.
