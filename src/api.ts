declare global {interface Window {PORTAL_CONFIG?:{supabaseUrl:string;publishableKey:string;publicWebsiteUrl:string}}}
const config=window.PORTAL_CONFIG;
export const configured=!!(config?.supabaseUrl&&config?.publishableKey);
export const publicUrl=config?.publicWebsiteUrl||'https://icemonser.github.io/promptyuen-demo/';
let access='';
export async function request(path:string,body?:unknown,method='POST'){
 if(!configured)throw Error('ยังไม่ได้เชื่อม Supabase กรุณาตั้งค่าใน config.js');
 const res=await fetch(config!.supabaseUrl.replace(/\/$/,'')+path,{method,headers:{apikey:config!.publishableKey,...(access?{Authorization:'Bearer '+access}:{}),'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});
 const data=await res.json().catch(()=>null);if(!res.ok)throw Error(data?.message||data?.error_description||data?.msg||'เชื่อมต่อไม่สำเร็จ กรุณาลองใหม่');return data;
}
export async function login(email:string,password:string){const data=await request('/auth/v1/token?grant_type=password',{email,password});access=data.access_token;try{const units=await rpc('my_units');if(!units.length)throw Error('บัญชีนี้ยังไม่มีสิทธิ์เจ้าหน้าที่');return units;}catch(e){access='';throw e;}}
export function logout(){access=''}
export async function rpc(name:string,args:unknown={}){return request('/rest/v1/rpc/'+name,args)}
export async function download(path:string){const result=await request('/storage/v1/object/sign/case-documents/'+path.split('/').map(encodeURIComponent).join('/'),{expiresIn:60});const a=document.createElement('a');a.href=config!.supabaseUrl+'/storage/v1'+result.signedURL;a.target='_blank';a.rel='noopener noreferrer';a.click();}
