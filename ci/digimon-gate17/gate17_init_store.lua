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

local function ensureChild(root,name)
  local n=root[name]
  if n==nil then n=NDB.createChildNode(root,name) end
  return n
end
local function fail(phase,msg)
  showMessage("GATE17_"..phase.."_FAIL|"..tostring(msg or "unknown"))
end

NDB.onReady(db,function()
  ensureChild(db,"estruturaMesa")
  ensureChild(db,"documentosCanonicos")
  ensureChild(db,"trackers")
  local sentinel=tostring(db.gate17Sentinel or "")
  if sentinel=="" then
    local ensured,res=Bootstrap.ensure(db)
    local audit,status=Bootstrap.runtimeAudit(db)
    if not ensured or not audit then fail("PHASE1",tostring(res).."|"..tostring(status)); return end

    local f,fe=Bootstrap.setFragmentState(db,FRAG,{descoberto=true,obtido=true,portador="GATE17",localAtual="GATE17_LOCAL",observacoes="GATE17_FRAGMENT_OK"})
    local m,me=Bootstrap.setMissionState(db,MISSION,{nome="Gate 17",objetivo="Persistir entre processos",estado="GATE17_ACTIVE",capitulo="G17",cena="P1",recompensa="PROVA",observacoes="GATE17_MISSION_OK"})
    local x,xe=Bootstrap.setFactState(db,FACT,{fato="GATE17_FACT_TEXT",fonte="GATE17",descobertoEm="P1",publico=true,observacoes="GATE17_FACT_OK"})
    local n,ne=Bootstrap.setNPCState(db,NPC,{ativo=true,["local"]="GATE17_LOCAL",estado="GATE17_NPC_STATE",relacao="GATE17_REL",ultimaCena="P1",observacoes="GATE17_NPC_OK"})
    local r,re=Bootstrap.setRouteState(db,ROUTE,{origem="GATE17_A",destino="GATE17_B",estado="aberta",requisitos="nenhum",descoberto=true,observacoes="GATE17_ROUTE_OK"})
    local o,oe=Bootstrap.setOrganizationState(db,ORG,{descoberta=true,reputacao=17,hostilidade=4,contatos="GATE17_CONTACT",objetivos="GATE17_OBJECTIVE",recursos="GATE17_RESOURCE",missoesLiberadas="GATE17_MISSION",fatosConhecidos="GATE17_FACT"})
    if not f or not m or not x or not n or not r or not o then
      fail("PHASE1","state-write|"..tostring(fe).."|"..tostring(me).."|"..tostring(xe).."|"..tostring(ne).."|"..tostring(re).."|"..tostring(oe)); return
    end

    local tracker=Bootstrap.getTracker(db,"ESTADO_DA_SESSAO")
    if not tracker or tostring(tracker.persistenceToken or "")=="" then fail("PHASE1","tracker-token-missing"); return end
    NDB.beginUpdate(db)
    db.gate17Sentinel="DIGITERION_GATE17_358"
    db.gate17PhaseOne="PASS"
    db.gate17ExpectedBootstrap=Bootstrap.VERSION
    db.gate17TrackerToken=tostring(tracker.persistenceToken)
    db.gate17AuditStatusPhase1=tostring(status)
    NDB.endUpdate(db)
    local audit2,status2=Bootstrap.runtimeAudit(db)
    if not audit2 then fail("PHASE1","post-write-audit|"..tostring(status2)); return end
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
    local ok = audit
      and sentinel=="DIGITERION_GATE17_358"
      and tostring(db.gate17PhaseOne or "")=="PASS"
      and tostring(db.gate17ExpectedBootstrap or "")==Bootstrap.VERSION
      and tostring(db.bootstrapVersion or "")==Bootstrap.VERSION
      and tracker~=nil and tostring(tracker.persistenceToken or "")==tostring(db.gate17TrackerToken or "")
      and f~=nil and f.descoberto==true and f.obtido==true and tostring(f.portador or "")=="GATE17" and tostring(f.observacoes or "")=="GATE17_FRAGMENT_OK"
      and m~=nil and tostring(m.estado or "")=="GATE17_ACTIVE" and tostring(m.objetivo or "")=="Persistir entre processos" and tostring(m.observacoes or "")=="GATE17_MISSION_OK"
      and x~=nil and tostring(x.fato or "")=="GATE17_FACT_TEXT" and x.publico==true and tostring(x.observacoes or "")=="GATE17_FACT_OK"
      and n~=nil and n.ativo==true and tostring(n["local"] or "")=="GATE17_LOCAL" and tostring(n.estado or "")=="GATE17_NPC_STATE" and tostring(n.relacao or "")=="GATE17_REL"
      and r~=nil and r.descoberto==true and tostring(r.estado or "")=="aberta" and tostring(r.origem or "")=="GATE17_A" and tostring(r.destino or "")=="GATE17_B"
      and o~=nil and o.descoberta==true and tonumber(o.reputacao or -999)==17 and tonumber(o.hostilidade or -999)==4 and tostring(o.contatos or "")=="GATE17_CONTACT"
    if ok then
      showMessage("GATE17_PHASE2_PASS|"..tostring(status).."|persistedAPI="..tostring(persistedOK and persistedSentinel or "unavailable"))
    else
      fail("PHASE2","audit="..tostring(audit).."|sentinel="..sentinel.."|persisted="..tostring(persistedOK and persistedSentinel or "unavailable").."|"..tostring(status))
    end
  end
end,function(err)
  showMessage("GATE17_NDB_OPEN_FAIL|"..tostring(err or "unknown"))
end)
