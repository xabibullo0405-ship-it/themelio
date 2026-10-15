const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const base=process.env.BASE_URL||'http://localhost:3000';
const url='https://pumkmcpekrbshcvfojim.supabase.co';
const now=new Date().toISOString();
const date=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Tashkent',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const director='00000000-0000-4000-8000-000000000001',employee='00000000-0000-4000-8000-000000000002';
const member=(id,app_role,login,position)=>({id,app_role,login,position,name:'',phone:'',contact_email:'',address:'',birth_date:null,status:'pending',created_at:now});
const state={members:[member(director,'director','direktor','Direktor'),member(employee,'employee','xodim01','Muhandis')],reports:[],tasks:[],messages:[]};
const jwt=id=>[Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({sub:id,role:'authenticated',aud:'authenticated',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url'),'fixture-signature'].join('.');
const authId=req=>{try{return JSON.parse(Buffer.from(req.headers()['authorization'].split('.')[1],'base64url')).sub}catch{return null}};
(async()=>{
const browser=await chromium.launch({headless:true,executablePath:process.env.BROWSER_PATH||undefined,args:['--no-sandbox']});
try{
 const errors=[];
 const setup=async()=>{
 const context=await browser.newContext({viewport:{width:1440,height:1050}});
 await context.routeWebSocket('**',ws=>ws.close());
 await context.route(url+'/**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname;
  const data=req.method()==='POST'?JSON.parse(req.postData()||'{}'):{};
  const send=(body,status=200)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});
  if(path==='/auth/v1/token'){
   const user=state.members.find(m=>data.email===m.login+'@accounts.themelio.invalid');
   if(!user||data.password!=='fixture-password')return send({error:'invalid_credentials',error_description:'Invalid credentials'},400);
   return send({access_token:jwt(user.id),refresh_token:'fixture-refresh',token_type:'bearer',expires_in:3600,expires_at:Math.floor(Date.now()/1000)+3600,user:{id:user.id,email:data.email,aud:'authenticated',role:'authenticated',app_metadata:{},user_metadata:{}}});
  }
  if(path==='/auth/v1/logout')return send({});
  const id=authId(req),me=state.members.find(m=>m.id===id);
  if(!me)return send({message:'Unauthorized'},401);
  if(path.startsWith('/rest/v1/rpc/')){
   const fn=path.split('/').pop();
   if(fn==='complete_profile'){Object.assign(me,{name:data.p_name,phone:data.p_phone,contact_email:data.p_email,address:data.p_address,status:'active'});return send(null)}
   if(fn==='submit_report'){const id=crypto.randomUUID();state.reports.unshift({id,author_id:me.id,title:data.p_title,body:data.p_body,report_type:data.p_type,report_date:data.p_date,status:'review',created_at:now});return send(id)}
   if(fn==='review_report'){assert.equal(me.app_role,'director');state.reports.find(r=>r.id===data.p_id).status='accepted';return send(null)}
   if(fn==='create_task'){assert.equal(me.app_role,'director');const id=crypto.randomUUID();state.tasks.push({id,title:data.p_title,description:data.p_description,assignee_id:data.p_assignee,due_date:data.p_due,priority:data.p_priority,progress:0,status:'progress',created_at:now});return send(id)}
   if(fn==='update_task_progress'){const t=state.tasks.find(t=>t.id===data.p_id);t.progress=data.p_progress;t.status=data.p_progress===100?'done':'progress';return send(null)}
   return send({message:'Unknown RPC'},404);
  }
  if(path==='/functions/v1/manage-members'){
   if(me.app_role!=='director')return send({error:'Director required'},403);
   const account=member(crypto.randomUUID(),'employee','tm-fixture','Hisobchi');state.members.push(account);
   return send({account:{id:account.id,login:account.login,role:account.position,status:'pending'},password:'fixture-password'});
  }
  const table=path.split('/').pop();
  let rows=state[table];if(!rows)return send({},404);
  if(me.app_role!=='director')rows=rows.filter(r=>table==='members'?r.id===id||r.app_role==='director':table==='reports'?r.author_id===id:table==='tasks'?r.assignee_id===id:r.sender_id===id||r.recipient_id===id);
  return send(rows);
 });
 const page=await context.newPage();page.setDefaultTimeout(12000);page.on('pageerror',e=>errors.push(e.message));return {context,page};
 };
 const {page:d}=await setup();await d.goto(base);
 await d.getByRole('heading',{name:'Kabinetga kirish',exact:true}).waitFor();
 assert.equal(await d.getByRole('button',{name:'Lavozim yaratish',exact:true}).count(),0,'Anonymous users must not enter director cabinet');
 const login=async(page,name,password='fixture-password')=>{await page.getByRole('textbox',{name:'Login',exact:true}).fill(name);await page.getByLabel('Parol',{exact:true}).fill(password);await page.getByRole('button',{name:'Kabinetga kirish',exact:true}).click()};
 await login(d,'direktor','incorrect');await d.getByRole('alert').waitFor();await login(d,'direktor');
 await d.getByRole('heading',{name:'Hisobotlar.',exact:true}).waitFor();
 await d.getByRole('button',{name:'Xodimlar',exact:true}).click();assert.equal(await d.locator('.pending-row').count(),1);assert.equal(await d.locator('.person-card').count(),0);
 await d.getByRole('button',{name:'Lavozim yaratish',exact:true}).click();await d.getByRole('combobox',{name:'Lavozim nomi'}).fill('Hisobchi');await d.getByRole('button',{name:'Login-parol yaratish',exact:true}).click();await d.getByRole('heading',{name:'Lavozim yaratildi',exact:true}).waitFor();await d.getByRole('button',{name:'Saqlab oldim'}).click();assert.equal(await d.locator('.pending-row').count(),2);
 const {page:e}=await setup();await e.goto(base);await login(e,'xodim01');await e.getByRole('heading',{name:'Shaxsiy ma’lumotlar',exact:true}).waitFor();
 assert.equal(await e.getByRole('button',{name:'Lavozim yaratish',exact:true}).count(),0);
 await e.getByRole('textbox',{name:'Ism va familiya',exact:true}).fill('Sinov Xodimi');await e.getByRole('textbox',{name:'Telefon raqami'}).fill('+998901234567');await e.getByRole('textbox',{name:'Elektron pochta',exact:true}).fill('test@example.com');await e.getByRole('textbox',{name:'Yashash manzili'}).fill('Sinov manzili');await e.getByRole('button',{name:'Profilni yakunlash'}).click();await e.getByRole('heading',{name:'Jamoaga qo‘shildingiz!'}).waitFor();
 await e.getByRole('textbox',{name:'Hisobot nomi'}).fill('Bugungi qurilish hisoboti');await e.getByRole('textbox',{name:'Bajarilgan ishlar'}).fill('Qavatdagi ishlar yakunlandi.');await e.getByRole('button',{name:'Hisobotni yuborish'}).click();await e.getByText('Hisobot direktorga yuborildi.',{exact:true}).waitFor();
 await d.reload();await d.getByRole('heading',{name:'Hisobotlar.',exact:true}).waitFor();await d.locator('.report-row').first().getByRole('button',{name:'Ko‘rish',exact:true}).click();await d.getByRole('button',{name:'Hisobotni tasdiqlash'}).click();await d.getByRole('status').filter({hasText:'Hisobot tasdiqlandi'}).waitFor();
 await e.reload();await e.getByText('Qabul qilindi',{exact:true}).waitFor();
 await d.getByRole('button',{name:'Topshiriqlar',exact:true}).click();await d.getByRole('button',{name:'Topshiriq yaratish',exact:true}).first().click();await d.getByRole('textbox',{name:'Topshiriq nomi'}).fill('Tekshirish');await d.getByRole('textbox',{name:'Tavsif'}).fill('Qurilish nazorati');await d.getByRole('button',{name:'Topshiriqni yaratish',exact:true}).click();await d.getByRole('status').filter({hasText:'Yangi topshiriq yaratildi'}).waitFor();assert.equal(state.tasks[0].assignee_id,employee,'UUID assignees must be preserved');
 await e.reload();await e.getByRole('heading',{name:'Tekshirish',exact:true}).waitFor();await e.getByRole('spinbutton',{name:'Bajarilish foizi'}).fill('100');await e.getByRole('button',{name:'Yangilash',exact:true}).click();await e.getByText('Topshiriq yangilandi.',{exact:true}).waitFor();
 await e.setViewportSize({width:390,height:844});await e.screenshot({path:'/tmp/themelio-cloud-employee.png',fullPage:true});assert.equal(await e.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
 await e.getByRole('button',{name:'Chiqish',exact:true}).click();await e.getByRole('heading',{name:'Kabinetga kirish',exact:true}).waitFor();await e.reload();await e.getByRole('heading',{name:'Kabinetga kirish',exact:true}).waitFor();
 assert.deepEqual(errors,[]);
 console.log('Cloud UI contract tests passed with mocked Supabase HTTP: login rejection, no anonymous/director bypass, role routing, invitations, self-onboarding, reports across independent browsers, director review, UUID task assignment, employee progress, mobile layout, logout. Live Supabase is NOT exercised.');
}finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
