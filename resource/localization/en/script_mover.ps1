$items = Get-ChildItem -Path "${Get-Location}" -Filter "* *.txt"

# es = es-ES
# pt = pt-PT
# sv = sv-SE
# zh = zh-CN

for ($i = 0; $i -lt $items.Count; $i++) {
  $file = (Get-Item $items[$i]).Basename.Split(" ")
  $base = $file[0]
  $lang = $file[1]
  if ($lang -eq "es") { $lang = "es-ES" }
  if ($lang -eq "pt") { $lang = "pt-PT" }
  if ($lang -eq "sv") { $lang = "sv-SE" }
  if ($lang -eq "zh") { $lang = "zh-CN" }
  Write-Host $lang
  New-Item -ItemType Directory -Force -Path "../$lang"
  Move-Item -Path "$file.txt" -Destination "../$lang/$base.properties"
}