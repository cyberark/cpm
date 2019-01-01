describe "ansible_test_kitchen_windows_role ansible role" {
    Context "windows programs" {
        $programsToGet = @(
            'Google Chrome'
        )

        $x = Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

        ForEach ($f in $programsToGet)
        {
            it "$($f) program is installed" {
                ($x | Where-Object { $_.GetValue( "DisplayName" ) -like $f }) | Should Be $true
            }
        }
    }
}