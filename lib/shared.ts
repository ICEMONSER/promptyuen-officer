export const statuses = ['กำลังตรวจสอบข้อมูล','ตรวจสอบข้อมูลแล้ว','กำลังดำเนินการ','ดำเนินการเสร็จสิ้น','ขอข้อมูลเพิ่มเติม'] as const;
export const codes = ['verifying','verified','in_progress','completed','additional_info'] as const;
export const statusLabel = (code:string) => statuses[codes.indexOf(code as typeof codes[number])] || code;
export type Case = {id:string;unit:string;name:string;phone:string;email:string;details:string;status:string;message:string;required:string;created:string;updated:string;revision:number;sample?:boolean};
export type History = {id:string;case_id:string;status:string;message:string;actor:string;created:string};
export type Attachment = {id:string;case_id:string;name:string;size:number;mime:string;created:string};
export const date = (value:string) => new Intl.DateTimeFormat('th-TH',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Bangkok'}).format(new Date(value));
