import {createClient} from '@supabase/supabase-js';
// Publishable keys identify the project. Authorization is enforced by Auth + RLS.
export const supabaseUrl=(import.meta.env.VITE_SUPABASE_URL||'https://pumkmcpekrbshcvfojim.supabase.co').replace(/\/rest\/v1\/?$/,'').replace(/\/$/,'');
export const supabaseKey=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY||'sb_publishable_6GzWm2xm483VNjxPYDcOmQ_yoB7xc76';
export const supabase=createClient(supabaseUrl,supabaseKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
export const loginEmail=(login)=>login.includes('@')?login.trim().toLowerCase():login.trim().toLowerCase()+'@accounts.themelio.invalid';
export async function manageMember(body){
 const {data,error}=await supabase.functions.invoke('manage-members',{body});
 if(error){let message='Hisob yaratilmadi. Server funksiyasi va ruxsatlarni tekshiring.';try{const detail=await error.context.json();message=detail.error||message;if(typeof detail.error_code==='string'&&/^[a-z0-9_]{1,80}$/.test(detail.error_code))message+=' ['+detail.error_code+']'}catch{}throw new Error(message)}
 if(data?.error)throw new Error(data.error);
 return data;
}
