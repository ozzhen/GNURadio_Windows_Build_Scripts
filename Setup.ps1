#
# Functions.psm1
#
function getPackage
{
	$toGet = $args[0]
	$newname = $args[1]
	$archiveName = [io.path]::GetFileNameWithoutExtension($toGet)
	$archiveExt = [io.path]::GetExtension($toGet)
	$isTar = [io.path]::GetExtension($archiveName)
	Write-Host -NoNewline "$archiveName..."
	if ($isTar -eq ".tar") {
		$archiveExt = $isTar + $archiveExt
		$archiveName = [io.path]::GetFileNameWithoutExtension($archiveName)  
	}
	if ($archiveExt -eq ".git") {
		# the source is a git repo, so make a shallow clone
		# no need to store anything in the packages dir
		if (((Test-Path $root\src-stage1-dependencies\$archiveName) -and ($newname -eq $null)) -or
			(($newname -ne $null) -and (Test-Path $root\src-stage1-dependencies\$newname))) {
			"previously shallowed cloned"
		} else {
			cd $root\src-stage1-dependencies	
			if (Test-Path $root\src-stage1-dependencies\$archiveName) {
				Remove-Item  $root\src-stage1-dependencies\$archiveName -Force -Recurse
			}
			$ErrorActionPreference = "Continue"
			git clone --depth=1 $toGet  2>&1 >> $Log 
			$ErrorActionPreference = "Stop"
			if ($LastErrorCode -eq 1) {
				Write-Host -BackgroundColor Red -ForegroundColor White "git clone FAILED"
			} else {
				"shallow cloned"
			}
			if ($newname -ne $null) {
				if (Test-Path $root\src-stage1-dependencies\$newname) {
					Remove-Item  $root\src-stage1-dependencies\$newname -Force -Recurse
				}
				if (Test-Path $root\src-stage1-dependencies\$archiveName) {
					ren $root\src-stage1-dependencies\$archiveName $root\src-stage1-dependencies\$newname
				}
			}
		}
	} else {
		# source is a compressed package
		# store it in the packages dir so we can reuse it if we
		# clean the whole install
		if (!(Test-Path $root/packages/$archiveName)) {
			mkdir $root/packages/$archiveName
		}
		if (!(Test-Path $root/packages/$archiveName/$archiveName$archiveExt)) {
			cd $root/packages/$archiveName
			# user-agent is for sourceforge downloads
			wget $toGet -OutFile "$archiveName$archiveExt" -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
		} else {
			Write-Host -NoNewLine "already downloaded..."
		}
		# extract the package if the final destination directory doesn't exist
		if (!((Test-Path $root\src-stage1-dependencies\$archiveName) -or ($newname -ne $null -and (Test-Path $root\src-stage1-dependencies\$newName)))) {
			$archive = "$root/packages/$archiveName/$archiveName$archiveExt"
			cd "$root\src-stage1-dependencies"
			if ($archiveExt -eq ".7z" -or ($archiveExt -eq ".zip")) {
				sz x -y $archive 2>&1 >> $Log
			} elseif ($archiveExt -eq ".zip") {
				$destination = "$root/src-stage1-dependencies"
				[io.compression.zipfile]::ExtractToDirectory($archive, $destination) >> $Log
			} elseif ($archiveExt -eq ".tar.gz11" ) {
				tar zxf $archive 2>&1 >> $Log
			} elseif ($archiveExt -eq ".tar.xz" -or $archiveExt -eq ".tgz" -or $archiveExt -eq ".tar.gz") {
				sz x -y $archive >> $Log
				if (!(Test-Path $root\src-stage1-dependencies\$archiveName.tar)) {
					# some python .tar.gz files put the tar in a dist subfolder
					cd dist
					sz x -aoa -ttar -o"$root\src-stage1-dependencies" "$archiveName.tar" >> $Log
					cd ..
					rm -rf dist >> $Log
				} else {
					sz x -aoa -ttar -o"$root\src-stage1-dependencies" "$archiveName.tar" >> $Log
					}
				del "$archiveName.tar"
			} else {
				throw "Unknown file extension on $archiveName$archiveExt"
			}
			if ($newname -ne $null) {
				if (Test-Path $root\src-stage1-dependencies\$newname) {
					Remove-Item  $root\src-stage1-dependencies\$newname -Force -Recurse >> $Log
					}
				if (Test-Path $root\src-stage1-dependencies\$archiveName) {
					ren $root\src-stage1-dependencies\$archiveName $root\src-stage1-dependencies\$newname
					}
			}
			"extracted"
		} else {
			"previously extracted"
		}
	}
}

# Patches are overlaid on top of the main source for gnuradio-specific adjustments
function getPatch
{
	$toGet = $args[0]
	$whereToPlace = $args[1]
	$archiveName = [io.path]::GetFileNameWithoutExtension($toGet)
	$archiveExt = [io.path]::GetExtension($toGet)
	$isTar = [io.path]::GetExtension($archiveName)
	
	Write-Host -NoNewline "patch $archiveName..."

	if ($isTar -eq ".tar") {
		$archiveExt = $isTar + $archiveExt
		$archiveName = [io.path]::GetFileNameWithoutExtension($archiveName)  
	}
	$url = "http://www.gcndevelopment.com/gnuradio/downloads/sources/" + $toGet 
	if (!(Test-Path $root/packages/patches)) {
		mkdir $root/packages/patches
	}
	cd $root/packages/patches
	if (!(Test-Path $root/packages/patches/$toGet)) {
		Write-Host -NoNewline "retrieving..."
		wget $url -OutFile $toGet >> $Log 
		Write-Host -NoNewline "retrieved..."
	} else {
		Write-Host -NoNewline "previously retrieved..."
	}
	
	$archive = "$root/packages/patches/$toGet"
	$destination = "$root/src-stage1-dependencies/$whereToPlace"
	if ($archiveExt -eq ".7z" -or $archiveExt -eq ".zip") {
		New-Item -path $destination -type directory -force >> $Log
		cd $destination 
		sz x -y $archive 2>&1 >> $Log
	} elseif ($archiveExt -eq ".tar.gz") {
		New-Item -path $destination -type directory -force >> $Log
		cd $destination 
		tar zxf $archive 2>&1 >> $Log
	} elseif ($archiveExt -eq ".tar.xz") {
		New-Item -path $destination -type directory -force >> $Log
		cd $destination 
		sz x -y $archive 2>&1 >> $Log
		sz x -aoa -ttar "$archiveName.tar" 2>&1 >> $Log
		del "$archiveName.tar"
	} else {
		throw "Unknown file extension on $archiveName$archiveExt"
	}

	"extracted"
}

function Exec
{
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=1)]
        [scriptblock]$Command,
        [Parameter(Position=1, Mandatory=0)]
        [string]$ErrorMessage = "Execution of command failed.`n$Command"
    )
    & $Command
    if ($LastExitCode -ne 0) {
        throw "Exec: $ErrorMessage"
    }
}

function SetLog ($name)
{
	$Global:Log = "$root\logs\$name.txt"
	"" > $Log 
}

$Config = Import-LocalizedData -BaseDirectory $mypath -FileName ConfigInfo.psd1 

# setup paths
$Global:root = $env:grwinbuildroot 
if (!$Global:root) {$Global:root = "C:/gr-build"}

# ensure on a 64-bit machine
if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {throw "It appears you are using 32-bit windows.  This build requires 64-bit windows"}
$myprog = "${Env:ProgramFiles(x86)}"

# Check for binary dependencies
if (-not (test-path "$root\bin\7za.exe")) {throw "7-zip (7za.exe) needed in bin folder"} 

# check for git/tar
if (-not (test-path "$env:ProgramFiles\Git\usr\bin\tar.exe")) {throw "Git For Windows must be installed"} 
set-alias tar "$env:ProgramFiles\Git\usr\bin\tar.exe"  

# CMake (to build gnuradio)
if (-not (test-path "${env:ProgramFiles(x86)}\Cmake\bin\cmake.exe")) {throw "CMake must be installed"} 
	
# ActivePerl (to build OpenSSL)
if (-not (test-path "$env:ProgramFiles\perl64\bin\perl.exe")) {throw "ActiveState Perl must be installed"} 
	
# MSVC 2015
if (-not (test-path "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\VC")) {throw "Visual Studio 2015 must be installed"} 

# WIX
# TODO check for WIX
	
# set VS 2015 environment
if (!(Test-Path variable:global:oldpath))
{
	pushd "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\VC"
	cmd /c "vcvarsall.bat amd64&set" |
	foreach {
		if ($_ -match "=") {
		$v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
		}
	}
	popd
	write-host "Visual Studio 2015 Command Prompt variables set." -ForegroundColor Yellow
	# set Intel Fortran environment (if exists)
	if (Test-Path env:IFORT_COMPILER16) {
		& $env:IFORT_COMPILER16\mkl\bin\mklvars.bat intel64
		$hasIFORT = $true
	} else {
		$hasIFORT = $false
	}
	# Now set a persistent variable holding the original path. vcvarsall will continue to add to the path until it explodes
	Set-Variable -Name oldpath -Value "$env:Path" -Description “original %Path%” -Option readonly -Scope "Global"
}
if (!(Test-Path variable:global:oldlib)) {Set-Variable -Name oldlib -Value "$env:Lib" -Description “original %LIB%” -Option readonly -Scope "Global"}
if (!(Test-Path variable:global:oldcl)) {Set-Variable -Name oldcl -Value "$env:CL" -Description “original %CL%” -Option readonly -Scope "Global"}
if (!(Test-Path variable:global:oldlink)) {Set-Variable -Name oldlink -Value "$env:LINK" -Description “original %CL%” -Option readonly -Scope "Global"}

# import .NET modules
Add-Type -assembly "system.io.compression.filesystem"

# set initial state
set-alias sz "$root\bin\7za.exe"  
cd $root



