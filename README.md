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

Bu ishlaydigan **frontend prototip**. Yangi tashrifda profil bo‘sh, xodimlar, hisobotlar, topshiriqlar, sotuvlar va chat yozishmalari yo‘q. Statistika haqiqiy mahalliy yozuvlardan hisoblanadi va dastlab nolni ko‘rsatadi. Sana Toshkent vaqtiga mos bugungi kundan boshlanadi. Namuna loyihalar va soxta diagramma olib tashlangan; obyekt biriktirilmagani ko‘rsatiladi. Loyihalar, hisobotlar va sotuvlarni server orqali boshqarish hali ulanmagan.

Xodimlar, topshiriqlar, tasdiqlangan hisobotlar, yuborilgan xabarlar va profil `localStorage` orqali faqat ushbu brauzerda saqlanadi. Chat xabarlarni haqiqiy foydalanuvchilarga jo‘natmaydi. Login, server API, foydalanuvchi huquqlari, fayl yuklash va ma’lumotlar bazasi hali ulanmagan. Haqiqiy shaxsiy yoki moliyaviy ma’lumotlar bilan ishlash uchun ushbu server qismlari kerak.

Shriftlar loyiha bilan birga saqlanadi; tashqi Google Fonts ulanishi kerak emas. Eski versiyadan yangilanganda dastlabki namuna yozuvlari bir marta avtomatik olib tashlanadi. Foydalanuvchi qo‘shgan xodimlar, topshiriqlar va shaxsiy profil saqlanadi. Olib tashlangan namuna xodimlar bilan bog‘liq yozishmalar tozalanadi.

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

`BASE_URL` orqali test serveri manzilini almashtirish mumkin. Testlar alohida brauzer kontekstida barcha sahifalarning boshlang‘ich bo‘sh holati, nol statistika, bo‘sh profil, xodim/topshiriq yaratish, qidiruv, topshiriqni yakunlash, chat va uning saqlanishi, eski namuna yozuvlarini tozalash, foydalanuvchi ma’lumotlarini saqlash hamda mobil menyuni tekshiradi. Testlar haqiqiy foydalanuvchi brauzeridagi ma’lumotlarni o‘zgartirmaydi.

## Vercel orqali joylashtirish

GitHub repozitoriysini Vercel loyihasiga ulang va production branch sifatida `main` ni tanlang. Root Directory repozitoriy ildizi (`.`) bo‘lishi kerak. `vercel.json` quyidagilarni belgilaydi:

- Framework: Vite
- Install Command: `npm ci`
- Build Command: `npm run build`
- Output Directory: `dist`

Frontend mahalliy rejimda ishlashi uchun muhit o‘zgaruvchilari yoki maxfiy kalitlar talab qilinmaydi. Git integratsiyasida avtomatik deploy yoqilgan bo‘lsa, `main` ga push yangi deployment yaratadi.
