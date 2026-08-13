import {getBcuQuotes} from "../lib/bcu.js";

export default async function handler(req,res){
  if(req.method!=="GET"){
    res.setHeader("Allow","GET");
    return res.status(405).json({error:"Método no permitido"});
  }
  try{
    const force=String(req.query?.force||"")==="1";
    const data=await getBcuQuotes({force});
    res.setHeader("Cache-Control","public, s-maxage=21600, stale-while-revalidate=86400");
    return res.status(200).json(data);
  }catch(error){
    console.error("[Panorama] Error consultando BCU:",error);
    return res.status(502).json({error:error?.message||"No fue posible consultar las cotizaciones del BCU"});
  }
}
