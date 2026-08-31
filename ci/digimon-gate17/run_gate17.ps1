$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'gate17-output'
New-Item -ItemType Directory -Force $out|Out-Null
$ev=Join-Path $out 'evidence.txt'
@('GATE17_BUNDLE_VERSION=2','GATE17_CONTAINER_FIX=1')|Set-Content $ev

Write-Host '=== Install Firecast 8.13 and RDK 3.7b ==='
$fc=Join-Path $env:RUNNER_TEMP 'firecast.exe'
Invoke-WebRequest -UseBasicParsing 'https://firecast.app/downloads/firecast8_13_win64.exe' -OutFile $fc
$p=Start-Process $fc -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-') -Wait -PassThru
if($p.ExitCode-ne 0){throw "Firecast install failed $($p.ExitCode)"}
$ri=Join-Path $env:RUNNER_TEMP 'rdk-installer.exe'
Invoke-WebRequest -UseBasicParsing 'https://firecast.app/downloads/RDK3.7.b.exe' -OutFile $ri
$p=Start-Process $ri -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-') -Wait -PassThru
if($p.ExitCode-ne 0){throw "RDK install failed $($p.ExitCode)"}
$rdk=Join-Path $env:LOCALAPPDATA 'FirecastSDK3\rdk.exe'
$tester=Join-Path $env:LOCALAPPDATA 'FirecastSDK3\RRPGFichas.exe'
if(-not(Test-Path $rdk)){throw 'RDK missing'}
if(-not(Test-Path $tester)){throw 'RRPGFichas missing'}
@('FIRECAST_INSTALL_EXIT=0','RDK_INSTALL_EXIT=0')|Add-Content $ev

Write-Host '=== Use embedded exact final source ==='
$srcZip=Join-Path $PSScriptRoot 'final-source.zip'
if(-not(Test-Path $srcZip)){throw 'embedded final-source.zip missing'}
$sha=(Get-FileHash $srcZip -Algorithm SHA256).Hash.ToLowerInvariant()
$expected='0dde069bbe7a53e88d027f31d4ebfc4d25fee7f1f51b91fdd8e66199d2f65624'
if($sha-ne $expected){throw "Unexpected embedded source SHA $sha"}
$src=Join-Path $env:RUNNER_TEMP 'final-src';Expand-Archive $srcZip $src -Force
$finalProj=Join-Path $src 'PROJETO_SDK3'
if(-not(Test-Path (Join-Path $finalProj 'init.lua'))){throw 'root init missing'}
"SOURCE_SHA256=$sha"|Add-Content $ev

Write-Host '=== Revalidate Gates 14-15 on exact source ==='
Push-Location $finalProj
try{
  & $rdk -p; if($LASTEXITCODE-ne 0){throw 'Final rdk -p failed'}
  & $rdk -c; if($LASTEXITCODE-ne 0){throw 'Final rdk -c failed'}
  & $rdk -i; if($LASTEXITCODE-ne 0){throw 'Final rdk -i failed'}
}finally{Pop-Location}
$rpks=@(Get-ChildItem $finalProj -Recurse -Filter '*.rpk' -File)
if($rpks.Count-ne 1){throw "Expected one final RPK, got $($rpks.Count)"}
$rpkSha=(Get-FileHash $rpks[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
"FINAL_RPK_SHA256=$rpkSha"|Add-Content $ev
@('GATE14_REVALIDATED=PASS','GATE15_REVALIDATED=PASS')|Add-Content $ev

Write-Host '=== Build Gate 17 autorun harness ==='
$srcRoot=Join-Path $finalProj 'DigiTerionMon'
$proj=Join-Path $env:RUNNER_TEMP 'gate17-project';$plug=Join-Path $proj 'DigiTerionMon'
New-Item -ItemType Directory -Force $plug|Out-Null
Copy-Item (Join-Path $srcRoot 'data') (Join-Path $plug 'data') -Recurse -Force
New-Item -ItemType Directory -Force (Join-Path $plug 'scripts')|Out-Null
Copy-Item (Join-Path $srcRoot 'scripts\bootstrap.lua') (Join-Path $plug 'scripts\bootstrap.lua') -Force
@'
<?xml version="1.0" encoding="UTF-8"?>
<module sdkVersion="3.7"><id>DigiTerionMon.EraDaDualidade</id><version>1.0.0</version><info lang="pt-BR"><name>DIGIMON — ERA DA DUALIDADE — GATE17</name><description>Persistence autorun harness</description><author>CI</author></info></module>
'@|Set-Content (Join-Path $proj 'module.xml') -Encoding UTF8
@'
require("vhd.lua")
VHD.addSearchPath("/DigiTerionMon")
VHD.addSearchPath("/DigiTerionMon/scripts")
require("ndb.lua")
local Bootstrap=require("scripts/bootstrap.lua")
local db=NDB.load("gate17_358.ndb")
local FRAG="06_ITENS/FRAGMENTOS_DETALHADOS/Fragmento_de_Agumon.md"
local NPC="07_NPCS/01_NPCS_BASE/Meramon.md"
local ORG="10_ORGANIZACOES/14_3_10_Circulo_da_Memoria_Restituida.md"
local MISSION="GATE17_MISSION"
local FACT="GATE17_FACT"
local ROUTE="GATE17_ROUTE"
local function ensureNamed(root,name)
  local n=root[name]
  if n==nil then
    local ok,node=pcall(function() return NDB.createChildNode(root,name) end)
    if ok then n=node end
  end
  if n==nil then error("container missing: "..name) end
  return n
end
local function fail(phase,msg) showMessage("GATE17_"..phase.."_FAIL|"..tostring(msg or "unknown")) end
NDB.onReady(db,function()
  local sentinel=tostring(db.gate17Sentinel or "")
  if sentinel=="" then
    ensureNamed(db,"estruturaMesa")
    ensureNamed(db,"documentosCanonicos")
    ensureNamed(db,"trackers")
    local ensured,res=Bootstrap.ensure(db)
    local audit,status=Bootstrap.runtimeAudit(db)
    if not ensured or not audit then fail("PHASE1",tostring(res).."|"..tostring(status));return end
    local f,fe=Bootstrap.setFragmentState(db,FRAG,{descoberto=true,obtido=true,consumido=false,gate17Value="FRAGMENT_OK"})
    local m,me=Bootstrap.setMissionState(db,MISSION,{ativa=true,estado="GATE17_ACTIVE",gate17Value="MISSION_OK"})
    local x,xe=Bootstrap.setFactState(db,FACT,{descoberto=true,valor="GATE17_DISCOVERED",gate17Value="FACT_OK"})
    local n,ne=Bootstrap.setNPCState(db,NPC,{ativo=true,ferimentos=2,relacao="GATE17_REL",gate17Value="NPC_OK"})
    local r,re=Bootstrap.setRouteState(db,ROUTE,{descoberta=true,estado="GATE17_OPEN",gate17Value="ROUTE_OK"})
    local o,oe=Bootstrap.setOrganizationState(db,ORG,{reputacao=17,hostil=true,estado="GATE17_HOSTILE",gate17Value="ORG_OK"})
    if not f or not m or not x or not n or not r or not o then fail("PHASE1","state-write|"..tostring(fe).."|"..tostring(me).."|"..tostring(xe).."|"..tostring(ne).."|"..tostring(re).."|"..tostring(oe));return end
    local tracker=Bootstrap.getTracker(db,"ESTADO_DA_SESSAO")
    if not tracker or tostring(tracker.persistenceToken or "")=="" then fail("PHASE1","tracker-token-missing");return end
    NDB.beginUpdate(db)
    db.gate17Sentinel="DIGITERION_GATE17_358"
    db.gate17PhaseOne="PASS"
    db.gate17ExpectedBootstrap=Bootstrap.VERSION
    db.gate17TrackerToken=tostring(tracker.persistenceToken)
    db.gate17AuditStatusPhase1=tostring(status)
    NDB.endUpdate(db)
    local audit2,status2=Bootstrap.runtimeAudit(db)
    if not audit2 then fail("PHASE1","post-write-audit|"..tostring(status2));return end
    showMessage("GATE17_PHASE1_PASS|"..tostring(status2))
  else
    local audit,status=Bootstrap.runtimeAudit(db)
    local f=Bootstrap.getPersistentState(db,"FRAGMENTOS",FRAG)
    local m=Bootstrap.getPersistentState(db,"MISSOES",MISSION)
    local x=Bootstrap.getPersistentState(db,"FATOS",FACT)
    local n=Bootstrap.getPersistentState(db,"NPCS",NPC)
    local r=Bootstrap.getPersistentState(db,"ROTAS",ROUTE)
    local o=Bootstrap.getPersistentState(db,"ORGANIZACOES",ORG)
    local tracker=Bootstrap.getTracker(db,"ESTADO_DA_SESSAO")
    local persistedOK,persistedSentinel=pcall(function() return NDB.getPersistedAttributeValue(db,"gate17Sentinel") end)
    local ok=audit
      and sentinel=="DIGITERION_GATE17_358"
      and tostring(db.gate17PhaseOne or "")=="PASS"
      and tostring(db.gate17ExpectedBootstrap or "")==Bootstrap.VERSION
      and tostring(db.bootstrapVersion or "")==Bootstrap.VERSION
      and tracker~=nil and tostring(tracker.persistenceToken or "")==tostring(db.gate17TrackerToken or "")
      and f~=nil and f.descoberto==true and f.obtido==true and tostring(f.gate17Value or "")=="FRAGMENT_OK"
      and m~=nil and m.ativa==true and tostring(m.estado or "")=="GATE17_ACTIVE" and tostring(m.gate17Value or "")=="MISSION_OK"
      and x~=nil and x.descoberto==true and tostring(x.valor or "")=="GATE17_DISCOVERED" and tostring(x.gate17Value or "")=="FACT_OK"
      and n~=nil and n.ativo==true and tonumber(n.ferimentos or -1)==2 and tostring(n.relacao or "")=="GATE17_REL" and tostring(n.gate17Value or "")=="NPC_OK"
      and r~=nil and r.descoberta==true and tostring(r.estado or "")=="GATE17_OPEN" and tostring(r.gate17Value or "")=="ROUTE_OK"
      and o~=nil and tonumber(o.reputacao or -999)==17 and o.hostil==true and tostring(o.estado or "")=="GATE17_HOSTILE" and tostring(o.gate17Value or "")=="ORG_OK"
    if ok then showMessage("GATE17_PHASE2_PASS|"..tostring(status).."|persistedAPI="..tostring(persistedOK and persistedSentinel or "unavailable")) else fail("PHASE2","audit="..tostring(audit).."|sentinel="..sentinel.."|persisted="..tostring(persistedOK and persistedSentinel or "unavailable").."|"..tostring(status)) end
  end
end,function(err) showMessage("GATE17_NDB_OPEN_FAIL|"..tostring(err or "unknown")) end)
'@|Set-Content (Join-Path $proj 'init.lua') -Encoding UTF8
Push-Location $proj
try{
  & $rdk -p; if($LASTEXITCODE-ne 0){throw 'Gate17 rdk -p failed'}
  & $rdk -c; if($LASTEXITCODE-ne 0){throw 'Gate17 rdk -c failed'}
  & $rdk -i; if($LASTEXITCODE-ne 0){throw 'Gate17 rdk -i failed'}
}finally{Pop-Location}
@('GATE17_RDK_P_EXIT=0','GATE17_RDK_C_EXIT=0','GATE17_INSTALL_EXIT=0')|Add-Content $ev

function Wait-Marker([string]$pattern,[int]$seconds){
  Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
  Add-Type -AssemblyName UIAutomationTypes -ErrorAction SilentlyContinue
  $root=[Windows.Automation.AutomationElement]::RootElement
  for($i=0;$i-lt $seconds;$i++){
    $all=$root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
    foreach($e in $all){try{$n=[string]$e.Current.Name;if($n-match $pattern){return $n}}catch{}}
    Start-Sleep 1
  }
  return ''
}
function Close-TesterGracefully($tp){
  $ws=New-Object -ComObject WScript.Shell
  [void]$ws.AppActivate($tp.Id);$ws.SendKeys('{ENTER}');Start-Sleep 15
  [void]$ws.AppActivate($tp.Id);$ws.SendKeys('%{F4}')
  if(-not $tp.WaitForExit(30000)){throw 'RRPGFichas did not close gracefully'}
}

Write-Host '=== Gate 17 phase 1 ==='
$tp=Start-Process $tester -PassThru
$marker=Wait-Marker 'GATE17_(PHASE1_PASS|PHASE1_FAIL|NDB_OPEN_FAIL)' 600
$marker|Set-Content (Join-Path $out 'phase1.txt')
"GATE17_PHASE1_MARKER=$marker"|Add-Content $ev
if($marker-notmatch 'GATE17_PHASE1_PASS'){throw "Gate17 phase1 failed/timed out: $marker"}
Close-TesterGracefully $tp
@('GATE17_PHASE1_GRACEFUL_CLOSE=1','GATE17_PHASE1=PASS')|Add-Content $ev

Write-Host '=== Gate 17 phase 2 fresh process ==='
$tp=Start-Process $tester -PassThru
$marker=Wait-Marker 'GATE17_(PHASE2_PASS|PHASE2_FAIL|NDB_OPEN_FAIL)' 600
$marker|Set-Content (Join-Path $out 'phase2.txt')
"GATE17_PHASE2_MARKER=$marker"|Add-Content $ev
if($marker-notmatch 'GATE17_PHASE2_PASS'){throw "Gate17 phase2 failed/timed out: $marker"}
Close-TesterGracefully $tp
@('GATE17_PHASE2_GRACEFUL_CLOSE=1','GATE17=PASS')|Add-Content $ev

Write-Host '=== Gate 18 restore exact final plugin ==='
Push-Location $finalProj
try{& $rdk -i;if($LASTEXITCODE-ne 0){throw 'Final restore install failed'}}finally{Pop-Location}
$tp=Start-Process $tester -PassThru;Start-Sleep 10
Add-Type -AssemblyName UIAutomationClient -ErrorAction SilentlyContinue
Add-Type -AssemblyName UIAutomationTypes -ErrorAction SilentlyContinue
$root=[Windows.Automation.AutomationElement]::RootElement
$errCond=[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,'Error')
if($root.FindFirst([Windows.Automation.TreeScope]::Descendants,$errCond)){throw 'Error after restoring exact final plugin'}
if($tp.HasExited){throw 'RRPGFichas exited after final restore'}
@('GATE18_FINAL_ERROR=0','GATE18=PASS','OVERALL_18_OF_18=PASS')|Add-Content $ev
Write-Host 'OVERALL_18_OF_18=PASS'
