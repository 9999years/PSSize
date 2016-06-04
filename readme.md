# PowerShell Size

A size-summing PowerShell cmdlet to get the cumulative size of files or directories.
Clone the repository and `Import-Module` the directory.

Examples:
```
PS>Get-Size * -Verbose
VERBOSE: Searching path `*`
VERBOSE: 4 files found:
VERBOSE:
C:\Users\xyz\Documents\Powershell Modules\size\.gitignore
C:\Users\xyz\Documents\Powershell Modules\size\readme.md
C:\Users\xyz\Documents\Powershell Modules\size\size.psd1
C:\Users\xyz\Documents\Powershell Modules\size\size.psm1
VERBOSE: Total bytes: 24087
VERBOSE:
Avg  : 5.88 kb
Sum  : 23.52 kb
Max  : 16.95 kb
Min  : 11
23.52 kb
PS>Get-Size * -Raw
24087
PS>Get-Size
23.52 kb
PS>Get-Size -Force
108.01 kb
PS>Get-Size -Force -Decimals 5
108.57910 kb
PS>Get-Size ..\posh-git\,..\var-dump\
89.82 kb
```
