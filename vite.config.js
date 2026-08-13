import {defineConfig} from "vite";
import {getBcuQuotes} from "./lib/bcu.js";

export default defineConfig({
  plugins:[{
    name:"panorama-local-api",
    configureServer(server){
      server.middlewares.use("/api/cotizaciones",async(req,res)=>{
        if(req.method!=="GET"){res.statusCode=405;res.end(JSON.stringify({error:"Método no permitido"}));return}
        try{
          const data=await getBcuQuotes({force:req.url?.includes("force=1")});
          res.statusCode=200;res.setHeader("Content-Type","application/json; charset=utf-8");
          res.end(JSON.stringify(data));
        }catch(error){
          console.error("[Panorama local] Error consultando BCU:",error);
          res.statusCode=502;res.setHeader("Content-Type","application/json; charset=utf-8");
          res.end(JSON.stringify({error:error?.message||"No fue posible consultar el BCU"}));
        }
      });
    }
  }]
});
