import React,{createContext,useContext,useEffect,useState,useCallback,useRef} from 'react';
import {Building2,KeyRound,LogOut,RefreshCw,ArrowRight} from 'lucide-react';
import {supabase,loginEmail} from './lib/supabase';
const Context=createContext(null);
export const useCloud=()=>useContext(Context);
export const todayCloud=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Tashkent',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const initials=name=>name.trim().split(/\s+/).filter(Boolean).slice(0,2).map(n=>n[0]).join('').toUpperCase();
const time=value=>new Date(value).toLocaleTimeString('uz-UZ',{timeZone:'Asia/Tashkent',hour:'2-digit',minute:'2-digit'});
function CloudLogin(){
 const [busy,setBusy]=useState(false),[error,setError]=useState('');
 return <div className="access-screen"><div className="access-brand"><Building2 size={28}/>THEMELIO</div><section className="panel access-card"><span className="modal-symbol"><KeyRound size={25}/></span><span className="eyebrow">DIREKTOR VA XODIMLAR UCHUN</span><h1>Kabinetga kirish</h1><p className="muted">O‘zingizga berilgan login va parol bilan kiring.</p><form onSubmit={async e=>{e.preventDefault();const f=new FormData(e.currentTarget);setBusy(true);setError('');try{const {error}=await supabase.auth.signInWithPassword({email:loginEmail(f.get('login')),password:f.get('password')});if(error)setError(error.status===400?'Login yoki parol noto‘g‘ri.':'Kirish amalga oshmadi. Supabase ulanishini tekshiring.')}catch{setError('Serverga ulanib bo‘lmadi. Internet ulanishini tekshiring.')}finally{setBusy(false)}}}><label>Login<input name="login" autoComplete="username" required autoFocus/></label><label>Parol<input name="password" type="password" autoComplete="current-password" required/></label>{error&&<p className="form-error" role="alert">{error}</p>}<button className="btn primary full" disabled={busy}>{busy?'Tekshirilmoqda...':'Kabinetga kirish'}<ArrowRight size={16}/></button></form><p className="login-hint">Hisobingiz yo‘qmi? Kirish ma’lumotlarini direktoringizdan oling.</p></section></div>;
}
export function CloudProvider({children,employee}){
 const [session,setSession]=useState(undefined),[snapshot,setSnapshot]=useState(null),[error,setError]=useState(''),[loading,setLoading]=useState(false);
 const version=useRef(0);
 useEffect(()=>{let active=true;supabase.auth.getSession().then(({data,error})=>{if(active){if(error)setError('Sessiyani tekshirib bo‘lmadi.');setSession(data.session)}});const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{if(active){version.current++;setSnapshot(null);setSession(next)}});return()=>{active=false;subscription.unsubscribe()}},[]);
 const refresh=useCallback(async()=>{
  if(!session)return;const request=++version.current;setLoading(true);
  try{
   const results=await Promise.all(['members','reports','tasks','messages'].map(table=>supabase.from(table).select('*').order('created_at',{ascending:table==='messages'})));
   for(const result of results)if(result.error)throw result.error;
   if(request!==version.current)return;
   const [members,reports,tasks,messages]=results.map(r=>r.data);
   const me=members.find(m=>m.id===session.user.id);if(!me)throw new Error('Hisobning bazadagi profili topilmadi. Administratorga murojaat qiling.');
   setSnapshot({members,reports,tasks,messages,me});setError('');
  }catch(e){if(request===version.current)setError(e.code==='42P01'||e.code==='PGRST205'?'Supabase jadvallari hali o‘rnatilmagan. SQL migratsiyasini bajaring.':e.message||'Ma’lumotlarni yuklab bo‘lmadi.')}
  finally{if(request===version.current)setLoading(false)}
 },[session]);
 useEffect(()=>{
  if(!session)return;refresh();
  const channel=supabase.channel('themelio-'+session.user.id).on('postgres_changes',{event:'*',schema:'public'},()=>refresh()).subscribe();
  const timer=setInterval(refresh,30000),onFocus=()=>refresh();window.addEventListener('focus',onFocus);
  return()=>{version.current++;clearInterval(timer);window.removeEventListener('focus',onFocus);supabase.removeChannel(channel)};
 },[session,refresh]);
 const signOut=async()=>{version.current++;setSnapshot(null);await supabase.auth.signOut();setSession(null)};
 const rpc=async(name,args)=>{const {data,error}=await supabase.rpc(name,args);if(error)throw new Error(error.message);await refresh();return data};
 if(session===undefined)return <div className="access-screen"><p>Sessiya tekshirilmoqda...</p></div>;
 if(!session)return <CloudLogin/>;
 if(!snapshot)return <div className="access-screen"><section className="panel access-card"><h2>{error?'Ulanishni yakunlash kerak':'Ma’lumotlar yuklanmoqda...'}</h2>{error&&<><p className="form-error" role="alert">{error}</p><button className="btn" onClick={refresh} disabled={loading}><RefreshCw size={15}/>Qayta tekshirish</button><button className="btn" onClick={signOut}><LogOut size={15}/>Chiqish</button></>}</section></div>;
 const memberToPerson=m=>({id:m.id,accountId:m.id,name:m.name,role:m.position,initials:initials(m.name),phone:m.phone,email:m.contact_email,address:m.address,birthDate:m.birth_date,color:'blue',online:false,report:snapshot.reports.some(r=>r.author_id===m.id&&r.report_date===todayCloud()),tasks:snapshot.tasks.filter(t=>t.assignee_id===m.id&&t.status!=='done').length});
 const people=snapshot.members.filter(m=>m.app_role==='employee'&&m.status==='active').map(memberToPerson);
 const reports=snapshot.reports.map(r=>({id:r.id,person:r.author_id,title:r.title,text:r.body,type:r.report_type,date:r.report_date,time:time(r.created_at),status:r.status,project:'A'}));
 const tasks=snapshot.tasks.map(t=>({id:t.id,title:t.title,description:t.description,person:t.assignee_id,due:t.due_date,priority:t.priority,progress:t.progress,status:t.progress===100?'done':t.due_date<todayCloud()?'late':t.status}));
 const messages=snapshot.messages.map(m=>({id:m.id,conversation:m.sender_id===session.user.id?m.recipient_id:m.sender_id,text:m.body,time:time(m.created_at),incoming:m.sender_id!==session.user.id}));
 const accounts=snapshot.members.filter(m=>m.app_role==='employee').map(m=>({id:m.id,login:m.login,role:m.position,status:m.status}));
 const profile={name:snapshot.me.name,email:snapshot.me.contact_email,notify:true};
 const saveProfile=async(details)=>rpc('complete_profile',{p_name:details.name,p_phone:details.phone||'',p_email:details.email,p_address:details.address||'',p_birth_date:details.birthDate||null});
 const setTasks=async(fn)=>{const next=typeof fn==='function'?fn(tasks):fn;for(const t of next){const old=tasks.find(o=>o.id===t.id);if(!old)await rpc('create_task',{p_title:t.title,p_description:t.description,p_assignee:t.person,p_due:t.due,p_priority:t.priority});else if(old.progress!==t.progress)await rpc('update_task_progress',{p_id:t.id,p_progress:t.progress})}};
 const setReports=async(fn)=>{const next=fn(reports);for(const r of next){const old=reports.find(o=>o.id===r.id);if(old&&old.status!==r.status)await rpc('review_report',{p_id:r.id})}};
 const setMessages=async(fn)=>{const next=fn(messages);for(const m of next)if(!messages.some(old=>old.id===m.id))await rpc('send_message',{p_recipient:m.conversation,p_body:m.text})};
 const value={people,reports,tasks,messages,accounts,profile,me:snapshot.me,members:snapshot.members,refresh,rpc,signOut,setTasks,setReports,setMessages,setProfile:saveProfile,saveProfile,error,setError,loading};
 return <Context.Provider value={value}>{error&&<div className="cloud-error" role="alert">{error}<button onClick={()=>setError('')}>×</button></div>}{snapshot.me.app_role==='director'?children:employee}</Context.Provider>;
}
