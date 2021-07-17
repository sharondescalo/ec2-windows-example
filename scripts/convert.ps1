function ConvertIISLogFrom-CSV{

    [cmdletbinding()]
    param(
        [parameter(ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
        [Alias("FullName")]
        [string]$File
    )
    process{
        Get-Content $file |  Where-Object{$_ -notmatch "^#[DSV]"} | ForEach-Object{$_ -replace '^#Fields: '} | ConvertFrom-Csv -Delimiter " "
    }
}

Get-ChildItem $path -Filter "ex*" | 
    Sort-Object creationdate -Descending | 
    Select -Last 1  |
    ConvertIISLogFrom-CSV | 
    Where-Object {$_."cs-username" -eq "username" -and $_."x-fullpath" -like "*error*"} |
    Select-Object date,time,"c-ip"," cs-uri-query","x-session","sc-status" |
    Format-Table -AutoSize
