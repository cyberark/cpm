describe "ansible_test_kitchen_windows_role ansible role" {
    Context "CPM Installation Path" {
        $Path = "C:\Program Files (x86)\Cyberark\Central Policy Manager"
        it "CPM Directory Exists" {
            Test-Path -Path $Path | Should be $true
        }
    }
}