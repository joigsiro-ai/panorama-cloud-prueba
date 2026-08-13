const BCU_ENDPOINT="https://www.bcu.gub.uy/_layouts/BCU.Cotizaciones/handler/CotizacionesHandler.ashx?op=getcotizaciones";

const GROUP1=[
  {iso:"USD",code:"2222",text:"DOLAR USA"},
  {iso:"EUR",code:"1111",text:"EURO"},
  {iso:"JPY",code:"3600",text:"YEN"},
  {iso:"CLP",code:"1300",text:"PESO CHILENO"},
  {iso:"PYG",code:"4800",text:"GUARANI"}
];
const UI={iso:"UI",code:"9800",text:"UNIDAD INDEXADA"};

function handlerDate(d){return `${String(d.getDate()).padStart(2,"0")}/${String(d.getMonth()+1).padStart(2,"0")}/${d.getFullYear()}`}
function rows(payload){
  const list=payload?.cotizacionesoutlist?.Cotizaciones??payload?.Cotizaciones??payload?.cotizaciones??[];
  return Array.isArray(list)?list:(list?[list]:[]);
}
function rowCode(r){return String(r?.Moneda??r?.Codigo??r?.CodigoMoneda??r?.CodMoneda??"").padStart(0,"0")}
function rowName(r){return String(r?.Nombre??r?.Descripcion??r?.MonedaNombre??"")}
function numberValue(raw){
  if(raw===null||raw===undefined||raw==="")return null;
  if(typeof raw==="number")return Number.isFinite(raw)?raw:null;
  const source=String(raw).trim();
  const normalized=source.includes(",")?source.replace(/\./g,"").replace(",","."):source;
  const n=Number(normalized);return Number.isFinite(n)?n:null;
}
function value(r){
  for(const key of ["TCV","TCC","Venta","Compra","Cotizacion","Valor"]){
    const n=numberValue(r?.[key]);if(n!==null&&n>0)return n;
  }
  return null;
}
function dateValue(r){
  const raw=String(r?.Fecha??r?.FechaCotizacion??r?.FechaContable??"");
  let m=raw.match(/(\d{4})-(\d{2})-(\d{2})/);if(m)return `${m[1]}-${m[2]}-${m[3]}`;
  m=raw.match(/(\d{2})\/(\d{2})\/(\d{4})/);if(m)return `${m[3]}-${m[2]}-${m[1]}`;
  return null;
}
async function queryGroup(defs,group){
  const now=new Date(),from=new Date(now);from.setDate(now.getDate()-14);
  const body={KeyValuePairs:{Monedas:defs.map(x=>({Val:x.code,Text:x.text})),FechaDesde:handlerDate(from),FechaHasta:handlerDate(now),Grupo:String(group)}};
  const response=await fetch(BCU_ENDPOINT,{
    method:"POST",
    headers:{"Content-Type":"application/json","Accept":"application/json","User-Agent":"Panorama-Cloud/0.4.5"},
    body:JSON.stringify(body),
    signal:AbortSignal.timeout(15000)
  });
  if(!response.ok)throw new Error(`BCU respondió HTTP ${response.status}`);
  const text=await response.text();
  let payload;try{payload=JSON.parse(text)}catch{throw new Error("BCU devolvió una respuesta no JSON")}
  return rows(payload);
}
function pickLatest(all,def){
  const candidates=all.filter(r=>{
    const code=rowCode(r).replace(/^0+/,"");
    const defCode=String(def.code).replace(/^0+/,"");
    const name=rowName(r).toUpperCase();
    return code===defCode || name.includes(def.text);
  }).map(r=>({value:value(r),date:dateValue(r)}))
    .filter(x=>Number.isFinite(x.value)&&x.value>0&&x.date)
    .sort((a,b)=>b.date.localeCompare(a.date));
  return candidates[0]||null;
}

let memoryCache={expires:0,data:null};
export async function getBcuQuotes({force=false}={}){
  if(!force&&memoryCache.data&&Date.now()<memoryCache.expires)return memoryCache.data;
  const [moneyRows,uiRows]=await Promise.all([queryGroup(GROUP1,"1"),queryGroup([UI],"2")]);
  const quotes={};
  for(const def of GROUP1){
    const q=pickLatest(moneyRows,def);
    if(q)quotes[def.iso]={code:def.iso,value:q.value,date:q.date,currency:"UYU"};
  }
  const uq=pickLatest(uiRows,UI);if(uq)quotes.UI={code:"UI",value:uq.value,date:uq.date,currency:"UYU"};
  if(!quotes.USD||!quotes.UI)throw new Error("El BCU no devolvió las cotizaciones esenciales USD/UI");
  const dates=Object.values(quotes).map(q=>q.date).filter(Boolean).sort();
  const data={source:"BCU",date:dates[0]||null,fetchedAt:Date.now(),quotes};
  memoryCache={data,expires:Date.now()+6*60*60*1000};
  return data;
}
