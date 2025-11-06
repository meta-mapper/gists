param (
   [Parameter(Mandatory = $true)]$LinksPath,
   [Parameter()][string]$DestinationDirectory = '.\',
   [switch]$Delete = $false,
   [switch]$Print = $false
)

$sh = New-Object -COM WScript.Shell

if((Test-Path $LinksPath) -and (Get-Item $LinksPath).Attributes -match 'Directory') {
   $LinkFiles = (Get-ChildItem -LiteralPath $LinksPath -Filter '*.lnk');

   if($LinkFiles.Length -gt 0) {
       foreach($shortcut in $LinkFiles) {
           $targetPath = $sh.CreateShortcut($shortcut.FullName).TargetPath;

           if(Test-Path -LiteralPath $targetPath) {
               if($Print -eq $true) {
                   Write-Host "Copying: $targetPath" -ForegroundColor Yellow;
               }
               $copied = Copy-Item -LiteralPath $targetPath -Destination $DestinationDirectory -PassThru -errorAction SilentlyContinue;
               if($copied) {
                   if($Delete -eq $true) {
                       Remove-Item -LiteralPath $shortcut.FullName;
                   }
               }
               else {
                   Write-Host 'Copy Error: ' $targetPath -ForegroundColor Red;
               }
           }
       }
   }
}