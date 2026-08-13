const BCU_ENDPOINT="https://cotizaciones.bcu.gub.uy/wscotizaciones/servlet/awsbcucotizaciones";
const SOAP_ACTION="Cotizaaction/AWSBCUCOTIZACIONES.Execute";

const WANTED=[
  {iso:"USD",names:["DLS. USA BILLETE","DLS. USA CABLE","DOLAR USA","DÓLAR USA"]},
  {iso:"EUR",names:["EURO"]},
  {iso:"JPY",names:["YEN"]},
  {iso:"CLP",names:["PESO CHILENO"]},
  {iso:"PYG",names:["GUARANI","GUARANÍ"]},
  {iso:"UI",names:["UNIDAD INDEXADA"]}
];

function isoDate(d){return d.toISOString().slice(0,10)}
function xmlEscape(s){return String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&apos;"}[c]))}
function xmlText(s){return String(s||"").replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g,"$1").replace(/<[^>]+>/g,"").replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&amp;/g,"&").replace(/&quot;/g,'"').replace(/&apos;/g,"'").trim()}
function tag(block,name){
  const re=new RegExp(`<(?:(?:\\w+):)?${name}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/(?:(?:\\w+):)?${name}>`,`i`);
  const m=String(block).match(re);return m?xmlText(m[1]):"";
}
function numberValue(raw){
  if(raw===null||raw===undefined||raw==="")return null;
  const source=String(raw).trim();
  const normalized=source.includes(",")?source.replace(/\./g,"").replace(",","."):source;
  const n=Number(normalized);return Number.isFinite(n)?n:null;
}
function normalizeName(s){return String(s||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toUpperCase().trim()}
function parseSoap(xml){
  const statusCode=tag(xml,"codigo")||tag(xml,"Codigo")||tag(xml,"statuscode");
  const statusMessage=tag(xml,"mensaje")||tag(xml,"Mensaje")||tag(xml,"statusmessage");
  if(statusCode && !["0","00"].includes(statusCode))throw new Error(`BCU ${statusCode}${statusMessage?`: ${statusMessage}`:""}`);

  const blocks=[...String(xml).matchAll(/<(?:(?:\w+):)?datoscotizaciones\.dato(?:\s[^>]*)?>([\s\S]*?)<\/(?:(?:\w+):)?datoscotizaciones\.dato>/gi)].map(m=>m[1]);
  // Some SOAP serializers use a generic <dato> element instead.
  if(!blocks.length){
    for(const m of String(xml).matchAll(/<(?:(?:\w+):)?dato(?:\s[^>]*)?>([\s\S]*?)<\/(?:(?:\w+):)?dato>/gi))blocks.push(m[1]);
  }
  return blocks.map(b=>({
    date:tag(b,"Fecha"),code:tag(b,"Moneda"),name:tag(b,"Nombre"),iso:tag(b,"CodigoISO"),
    buy:numberValue(tag(b,"TCC")),sell:numberValue(tag(b,"TCV")),arb:numberValue(tag(b,"ArbAct"))
  })).filter(r=>r.name&&r.date);
}
function soapEnvelope(from,to){
  return `<?xml version="1.0" encoding="UTF-8"?>\n<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:cot="Cotiza"><soapenv:Header/><soapenv:Body><cot:wsbcucotizaciones.Execute><cot:Entrada><cot:Moneda><cot:item>0</cot:item></cot:Moneda><cot:FechaDesde>${xmlEscape(from)}</cot:FechaDesde><cot:FechaHasta>${xmlEscape(to)}</cot:FechaHasta><cot:Grupo>0</cot:Grupo></cot:Entrada></cot:wsbcucotizaciones.Execute></soapenv:Body></soapenv:Envelope>`;
}
async function queryBcu(){
  const now=new Date(),from=new Date(now);from.setDate(now.getDate()-14);
  const response=await fetch(BCU_ENDPOINT,{
    method:"POST",
    headers:{"Content-Type":"text/xml; charset=utf-8","Accept":"text/xml, application/soap+xml","SOAPAction":SOAP_ACTION,"User-Agent":"Panorama-Cloud/0.4.5.3"},
    body:soapEnvelope(isoDate(from),isoDate(now)),signal:AbortSignal.timeout(15000)
  });
  const text=await response.text();
  if(!response.ok)throw new Error(`BCU respondió HTTP ${response.status}${text?`: ${xmlText(text).slice(0,180)}`:""}`);
  if(/<(?:(?:\w+):)?Fault\b/i.test(text))throw new Error(`BCU SOAP Fault: ${tag(text,"faultstring")||"respuesta SOAP inválida"}`);
  const result=parseSoap(text);
  if(!result.length)throw new Error("El Web Service del BCU no devolvió cotizaciones");
  return result;
}
function pickLatest(all,def){
  const names=def.names.map(normalizeName);
  const candidates=all.filter(r=>{
    const n=normalizeName(r.name),iso=normalizeName(r.iso);
    return names.some(x=>n===x||n.includes(x)) || (def.iso!=="USD"&&iso===def.iso);
  }).map(r=>({value:(r.sell&&r.sell>0?r.sell:r.buy),date:r.date}))
    .filter(x=>Number.isFinite(x.value)&&x.value>0&&/^\d{4}-\d{2}-\d{2}/.test(x.date))
    .sort((a,b)=>b.date.localeCompare(a.date));
  return candidates[0]||null;
}

let memoryCache={expires:0,data:null};
export async function getBcuQuotes({force=false}={}){
  if(!force&&memoryCache.data&&Date.now()<memoryCache.expires)return memoryCache.data;
  const rows=await queryBcu();
  const quotes={};
  for(const def of WANTED){
    const q=pickLatest(rows,def);
    if(q)quotes[def.iso]={code:def.iso,value:q.value,date:q.date.slice(0,10),currency:"UYU"};
  }
  if(!quotes.USD||!quotes.UI)throw new Error("El BCU no devolvió las cotizaciones esenciales USD/UI");
  const dates=Object.values(quotes).map(q=>q.date).filter(Boolean).sort();
  const data={source:"BCU Web Service",date:dates.at(-1)||null,fetchedAt:Date.now(),quotes};
  memoryCache={data,expires:Date.now()+6*60*60*1000};
  return data;
}
