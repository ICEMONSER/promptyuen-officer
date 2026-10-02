# พร้อมยื่น — ระบบเจ้าหน้าที่

เว็บภาษาไทยสำหรับเลือกหน่วยงาน รับคำขอ ตรวจเอกสาร อัปเดตสถานะ 5 ขั้น และขอข้อมูลเพิ่มเติม พร้อมประวัติผู้แก้ไข

**สถานะ:** ต้องสร้าง Supabase Free และใส่ค่าใน `public/config.js` ก่อนเชื่อมข้อมูลออนไลน์ โหมดตัวอย่างใช้ข้อมูลสมมติและไม่บันทึกจริง

- Frontend: React + Vite บน GitHub Pages
- Backend: Supabase Free — PostgreSQL, Auth, private Storage
- เว็บประชาชน: https://github.com/ICEMONSER/promptyuen-demo
- รายชื่อเจ้าหน้าที่ตั้งในฐานข้อมูล ไม่เผยแพร่ใน repository
- ไม่ใช่ระบบรับแจ้งความที่ตำรวจรับรองและไม่ใช่ช่องทางฉุกเฉิน

## พัฒนา
Node 22.13 ขึ้นไป: `npm ci`, `npm run dev`, `npm run build`.

## เปิดใช้งาน
ดู `SETUP.th.md` สำหรับสร้าง Supabase Free, รัน schema, สร้างบัญชีเจ้าหน้าที่ และตั้งเว็บทั้งสองให้ใช้ Project URL และ Publishable key เดียวกัน ห้ามใส่ secret/service_role key ใน frontend

บังคับสิทธิ์ใน PostgreSQL RLS/RPC ผู้ยื่นต้องมี Case ID และรหัสสุ่มติดตาม ไฟล์อยู่ใน private bucket โควตาฟรีไม่ใช่การใช้งานไม่จำกัด ไม่เปิดบริการเสียเงินอัตโนมัติ
