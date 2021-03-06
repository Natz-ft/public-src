# 遇到错误退出
$ErrorActionPreference = "Stop"

# 设置允许 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName System.IO.Compression.FileSystem

$desktop   = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$build_dir = $env:temp + "\SharpHound3-master"
$zip_path  = $env:temp + "\SharpHound3-master.zip"
$out_dir   = $desktop + "\release"

Write-Host "[-] Creating release folder"
New-Item -ItemType Directory -Force -Path $out_dir | Out-Null

Write-Host "[-] Downloading from github"
$web = New-Object Net.Webclient;
$web.DownloadFile("https://github.com/BloodHoundAD/SharpHound3/archive/master.zip", $zip_path);

# 解压缩
Write-Host "[-] Expanding zip"
if (Test-Path -Path $build_dir)
{
    cmd /c "del /Q /F /S $build_dir > nul" 
    cmd /c rmdir "$build_dir" /q /s
}

[System.IO.Compression.ZipFile]::ExtractToDirectory($zip_path, "$build_dir\..")
Remove-Item –Path $zip_path

# 开始编译
Write-Host "[-] Start compilation"
cd $build_dir

# 恢复 nuget 包
Write-Host "[-] Restoring nuget packages"
cmd /c c:\windows\nuget.exe restore SharpHound3.sln

cmd /c 'call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat" && msbuild /p:Configuration=Release /p:Platform="Any CPU" /p:TargetFrameworkVersion=v4.7.2'

Write-Host "[-] Copying files to $out_dir"
cd "$build_dir\SharpHound3\bin\Release"

ForEach ($item in "SharpHound.exe", "SharpHound.ps1") {
    Copy-Item $item -Destination "$out_dir" -Force
}

Write-Host "[-] Cleaning up"
if (Test-Path -Path $build_dir)
{
    cmd /c "del /Q /F /S $build_dir > nul"
    cmd /c rmdir "$build_dir" /q /s
}

