# Themelio — direktor kabineti

Qurilish kompaniyasi direktorining o‘zbek tilidagi boshqaruv kabineti. Dizayn taqdim etilgan Themelio.pdf maketlari asosida tayyorlangan.

## Ishga tushirish

Node.js 20.19+ yoki 22.12+ kerak (Node.js 24 bilan tekshirilgan).

```sh
npm ci --cache /tmp/themelio-npm-cache
npm run dev -- --port 3000
```

Ishchi papka: `/workspace/themelio`. Production fayllar: `npm run build`, natija `dist/`. `npm run preview` bilan tayyor buildni ko‘rish mumkin.

## Imkoniyatlar

- **Hisobotlar:** kunlik hisobotlar, ertalabki/yakuniy filtrlar, xodim bo‘yicha qidiruv, tasdiqlash, CSV eksport, hafta/oy diagrammasi.
- **Xodimlar:** lavozim filtri, qidiruv, profil, xodim qo‘shish va xabar yozish.
- **Topshiriqlar:** mas’ul va muddat belgilash, yangi topshiriq, bajarilish foizini yangilash, holat bo‘yicha filtrlash.
- **Sotuvlar:** namuna kvartiralar, to‘lov tafsilotlari, qidiruv, holat filtri va CSV eksport.
- **Arxiv:** hisobotlarni ko‘rish va eksport qilish.
- **Chat:** suhbat tanlash, xabar yuborish, yuborilgan xabarlarni shu brauzerda saqlash.
- **Sozlamalar:** profil va bildirishnoma afzalliklarini saqlash.
- Mobil menyu, moslashuvchan sahifalar, `Ctrl/Cmd + K` qidiruv, `Escape` oynani yopish.

## Ma’lumotlar haqida

Bu ishlaydigan **frontend prototip**. Namunaviy ma’lumotlar PDFdagi 14.10.2026 sanasiga moslangan. Boshqa sana tanlansa kunlik hisobotlar bo‘sh bo‘ladi. Diagramma, umumiy statistika va loyihalar namuna hisoblanadi; ular haqiqiy tahlil tizimiga ulanmagan.

Xodimlar, topshiriqlar, tasdiqlangan hisobotlar, yuborilgan xabarlar va profil `localStorage` orqali faqat ushbu brauzerda saqlanadi. Chat xabarlarni haqiqiy foydalanuvchilarga jo‘natmaydi. Login, server API, foydalanuvchi huquqlari, fayl yuklash va ma’lumotlar bazasi hali ulanmagan. Haqiqiy shaxsiy yoki moliyaviy ma’lumotlar bilan ishlash uchun ushbu server qismlari kerak. Namunaviy kontaktlar va qurilish manzillari ham haqiqiy yozuvlar emas.

Shriftlar loyiha bilan birga saqlanadi; tashqi Google Fonts ulanishi kerak emas. Namuna holatini tiklash uchun brauzerning sayt ma’lumotlarini tozalang.

## Tekshiruvlar

```sh
npm run build
# Alohida terminalda avval npm run dev -- --port 3000 ni ishga tushiring.
npx playwright install chromium
npm test
```

Agar tizimda Chromium mavjud bo‘lsa, yuklab olish o‘rniga:

```sh
BROWSER_PATH=/usr/bin/chromium npm test
```

`BASE_URL` orqali test serveri manzilini almashtirish mumkin. Testlar alohida brauzer kontekstida qidiruv, hisobotni tasdiqlash, xodim/topshiriq yaratish, topshiriqni yakunlash, chat va uning saqlanishi, sotuv filtri, CSV eksport hamda mobil menyuni tekshiradi. Testlar haqiqiy foydalanuvchi brauzeridagi ma’lumotlarni o‘zgartirmaydi.

## Vercel orqali joylashtirish

GitHub repozitoriysini Vercel loyihasiga ulang va production branch sifatida `main` ni tanlang. Root Directory repozitoriy ildizi (`.`) bo‘lishi kerak. `vercel.json` quyidagilarni belgilaydi:

- Framework: Vite
- Install Command: `npm ci`
- Build Command: `npm run build`
- Output Directory: `dist`

Frontend namuna rejimida ishlashi uchun muhit o‘zgaruvchilari yoki maxfiy kalitlar talab qilinmaydi. Git integratsiyasida avtomatik deploy yoqilgan bo‘lsa, `main` ga push yangi deployment yaratadi.
