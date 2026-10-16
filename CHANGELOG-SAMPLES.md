# Categorized sample documents — 2026-10-17
- Display ID, driving license and vehicle registration in separate attachment columns.
- The primary demonstration case uses the supplied sample images and contact details; other sample cases remain separate.
- Received documents are categorized by the existing stable upload path or recognized document name, without database migration.
- Manual: open sample case DEMO-2026-000018, inspect each image and use its open button; at mobile widths columns stack vertically.
- Validation: TypeScript/Vite build and both test suites pass.
- Limitation: demonstration cases are not incoming citizen submissions. Live cross-site delivery requires the existing backend setup.

## Rangsit automatic station lookup
- Added Khlong Luang and Pratunam Chulalongkorn public station locations and expanded lookup coverage to Thammasat Rangsit.
- Manual: allow browser location at Thammasat Rangsit, open the accident flow, and confirm Khlong Luang is selected without changing station manually.
- Automated: three campus points select Khlong Luang; central Rangsit selects Pratunam; invalid/outside points still fail.
- Sources: https://mapcarta.com/W442793759 and https://th.near-place.com/chulalongkorn-pratunam-metropolitan-police-station-113-thnn-soi-rangsit-pathum-thani-7-thanyaburi-district (checked 2026-10-17). Nearest station does not establish jurisdiction.
