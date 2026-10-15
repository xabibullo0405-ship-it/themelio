import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const random=(length:number)=>Array.from(crypto.getRandomValues(new Uint8Array(length)),n=>alphabet[n%alphabet.length]).join('');
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return reply(405,{error:'POST required'});
 const token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
 if(!token)return reply(401,{error:'Kirish talab qilinadi.'});
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user},error:authError}=await admin.auth.getUser(token);
 if(authError||!user)return reply(401,{error:'Sessiya yaroqsiz. Qayta kiring.'});
 const {data:actor,error:actorError}=await admin.from('members').select('app_role').eq('id',user.id).single();
 if(actorError||actor?.app_role!=='director')return reply(403,{error:'Faqat direktor hisob yarata oladi.'});
 let body;try{body=await req.json()}catch{return reply(400,{error:'Invalid JSON'})}
 if(body.action==='reset-password'){
  const {data:member}=await admin.from('members').select('id,login,position,status,app_role').eq('id',body.id).single();
  if(!member||member.app_role!=='employee')return reply(404,{error:'Xodim topilmadi.'});
  const password=random(18),{error}=await admin.auth.admin.updateUserById(member.id,{password});
  if(error)return reply(400,{error:'Parolni yangilab bo‘lmadi.'});
  return reply(200,{account:{id:member.id,login:member.login,role:member.position,status:member.status},password});
 }
 if(body.action!=='create')return reply(400,{error:'Unknown operation'});
 const position=typeof body.position==='string'?body.position.trim():'';
 if(!position||position.length>80)return reply(400,{error:'Lavozim nomini kiriting (1–80 belgi).'});
 const {count,error:countError}=await admin.from('members').select('id',{count:'exact',head:true});
 if(countError)return reply(503,{error:'Baza tayyor emas. SQL migratsiyasini tekshiring.'});
 if((count||0)>=10)return reply(409,{error:'10 ta hisob chegarasiga yetildi (1 direktor + 9 xodim).'});
 const login='tm-'+random(10).toLowerCase(),password=random(18);
 const {data,error}=await admin.auth.admin.createUser({email:login+'@accounts.themelio.invalid',password,email_confirm:true,app_metadata:{themelio_role:'employee',position,login}});
 if(error||!data.user)return reply(400,{error:'Hisob yaratilmadi. Hisoblar soni va Auth sozlamalarini tekshiring.'});
 return reply(200,{account:{id:data.user.id,login,role:position,status:'pending'},password});
});
