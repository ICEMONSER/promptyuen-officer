import {validateSources,validateMemory,sourceKey,planCase} from './concierge-core.js';
// A portable review packet is an explicit file transfer, never an official submission.
export const PACKET_LIMIT=150000;
const str=(v,n=500)=>{if(typeof v!=='string'||v.length>n)throw Error('รูปแบบหรือขนาดข้อมูลในชุดตรวจไม่ถูกต้อง');return v;};
export function validatePacketBody(p){
 if(!p||p.format!=='promptyuen-review'||p.version!==1)throw Error('ไม่รองรับไฟล์ชุดตรวจนี้');
 const sources=validateSources(p.sources);
 if(sourceKey(sources).length>30000)throw Error('แหล่งข้อมูลมีขนาดใหญ่เกินกำหนด');
 const input={details:str(p.input?.details,4000),eventDate:str(p.input?.eventDate),eventPlace:str(p.input?.eventPlace)};
 for(const [field,value] of Object.entries(input))if(value&&sources.find(s=>s.id==='input:'+field)?.text!==value.trim())throw Error('ข้อมูลสรุปไม่ตรงกับต้นฉบับ');
 const memory=validateMemory(p.memory,sources);
 if(!Array.isArray(p.documents)||p.documents.length>10)throw Error('รายการเอกสารไม่ถูกต้อง');
 const documents=p.documents.map((d,i)=>({id:'document:'+i,kind:str(d.kind,30),verified:d.verified===true}));
 if(documents.some(d=>!['identity','license','vehicle','insurance','house','military','other'].includes(d.kind)))throw Error('ประเภทเอกสารไม่ถูกต้อง');
 const createdAt=str(p.createdAt,40);if(!Number.isFinite(Date.parse(createdAt)))throw Error('วันที่ชุดตรวจไม่ถูกต้อง');
 return {format:'promptyuen-review',version:1,id:str(p.id,100),createdAt,input,reporter:{name:str(p.reporter?.name,200)},station:{name:str(p.station?.name,200)},sources,memory,documents};
}
export function makePacketBody(record,documents=[]){
 const value=k=>String(record.fields?.[k]?.value||'');
 const sources=record.conciergeSources?.length?record.conciergeSources:['details','eventDate','eventPlace'].filter(k=>value(k)).map(k=>({id:'input:'+k,label:{details:'คำบอกเล่าต้นฉบับ',eventDate:'วันเวลาที่ระบุ',eventPlace:'สถานที่ที่ระบุ'}[k],text:value(k),kind:'input',field:k}));
 return validatePacketBody({format:'promptyuen-review',version:1,id:record.id,createdAt:new Date().toISOString(),input:{details:value('details'),eventDate:value('eventDate'),eventPlace:value('eventPlace')},reporter:{name:value('fullName')},station:{name:record.station?.name||''},sources,memory:record.concierge||null,documents:documents.filter(d=>record.documentIds?.includes(d.id)).map(d=>({kind:d.kind,verified:!!d.verified}))});
}
function canonical(v){if(Array.isArray(v))return '['+v.map(canonical).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';return JSON.stringify(v);}
async function digest(body){const hash=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(canonical(body)));return Array.from(new Uint8Array(hash),v=>v.toString(16).padStart(2,'0')).join('');}
export async function encodePacket(body){const safe=validatePacketBody(body);return JSON.stringify({body:safe,sha256:await digest(safe)},null,2);}
export async function decodePacket(raw){
 if(typeof raw!=='string'||new TextEncoder().encode(raw).length>PACKET_LIMIT)throw Error('ใช้ไฟล์ชุดตรวจไม่เกิน 150 กิโลไบต์');
 let p;try{p=JSON.parse(raw);}catch{throw Error('ไฟล์ชุดตรวจไม่ใช่ JSON ที่ถูกต้อง');}
 if(!p||typeof p.sha256!=='string'||p.sha256!==await digest(p.body))throw Error('ข้อมูลในไฟล์เปลี่ยนหลังสร้าง กรุณาส่งออกใหม่');
 return validatePacketBody(p.body);
}
export function packetTasks(packet){return planCase({sources:packet.sources,facts:packet.memory?.facts||[],answers:packet.memory?.answers||{},documents:packet.documents,selected:packet.documents.map(d=>d.id),station:packet.station});}
