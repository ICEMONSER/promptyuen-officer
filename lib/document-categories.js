export const DOCUMENT_CATEGORIES={identity:'บัตรประชาชน',license:'ใบขับขี่',vehicle:'ใบคู่มือจดทะเบียนรถ',insurance:'กรมธรรม์ประกันภัย',evidence:'หลักฐานเหตุการณ์',other:'เอกสารอื่น ๆ'};
export function documentCategory(file){
 const kind=file.kind || String(file.id||'').split('/')[2];
 if(Object.hasOwn(DOCUMENT_CATEGORIES,kind))return kind;
 const names={'บัตรประชาชน.png':'identity','ใบขับขี่.png':'license','ใบคู่มือจดทะเบียนรถ.png':'vehicle'};
 return names[file.name] || 'other';
}
