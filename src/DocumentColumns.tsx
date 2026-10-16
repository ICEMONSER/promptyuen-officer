import {DOCUMENT_CATEGORIES,documentCategory} from '../lib/document-categories.js';
import type {Attachment} from '../lib/shared';
export function DocumentColumns({files,onOpen}:{files:Attachment[];onOpen:(file:Attachment)=>void}){
 return <div className="document-columns">{Object.entries(DOCUMENT_CATEGORIES).filter(([kind])=>['identity','license','vehicle'].includes(kind)||files.some(f=>documentCategory(f)===kind)).map(([kind,label])=><section className="document-category" key={kind}><h4>{label}</h4>{files.filter(f=>documentCategory(f)===kind).map((f,i)=><div key={f.id}>{f.sampleUrl&&<img src={f.sampleUrl} alt={`${label} ตัวอย่างสำหรับการสาธิต`}/>}<button className="file" onClick={()=>onOpen(f)}>เปิดตรวจ {label}{i?` ${i+1}`:''}</button>{f.sampleUrl&&<small>เอกสารตัวอย่างสำหรับการสาธิต</small>}</div>)}{!files.some(f=>documentCategory(f)===kind)&&<p className="muted">ไม่มีเอกสารในหมวดนี้</p>}</section>)}</div>
}
