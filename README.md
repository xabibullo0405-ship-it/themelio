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
- **Xodimlar:** direktor lavozim yaratadi, login-parol oladi; xodim o‘zi profil to‘ldirgach ro‘yxatga qo‘shiladi. Qidiruv, lavozim filtri va profil tafsilotlari mavjud.
- **Topshiriqlar:** mas’ul va muddat belgilash, yangi topshiriq, bajarilish foizini yangilash, holat bo‘yicha filtrlash.
- **Sotuvlar:** boshlang‘ich bo‘sh holat, qidiruv, holat filtri va CSV eksport.
- **Arxiv:** hisobotlarni ko‘rish va eksport qilish.
- **Chat:** suhbat tanlash, xabar yuborish, yuborilgan xabarlarni shu brauzerda saqlash.
- **Sozlamalar:** profil va bildirishnoma afzalliklarini saqlash.
- Mobil menyu, moslashuvchan sahifalar, `Ctrl/Cmd + K` qidiruv, `Escape` oynani yopish.

## Ma’lumotlar haqida

Bu ishlaydigan **frontend prototip**. Yangi tashrifda profil bo‘sh, xodimlar, hisobotlar, topshiriqlar, sotuvlar va chat yozishmalari yo‘q. Statistika haqiqiy mahalliy yozuvlardan hisoblanadi va dastlab nolni ko‘rsatadi. Sana Toshkent vaqtiga mos bugungi kundan boshlanadi. Namuna loyihalar va soxta diagramma olib tashlangan; obyekt biriktirilmagani ko‘rsatiladi. Loyihalar, hisobotlar va sotuvlarni server orqali boshqarish hali ulanmagan.

Xodimlar, topshiriqlar, tasdiqlangan hisobotlar, yuborilgan xabarlar va profil `localStorage` orqali faqat ushbu brauzerda saqlanadi. Chat xabarlarni haqiqiy foydalanuvchilarga jo‘natmaydi. Xodim loginining mahalliy namoyishi mavjud; server autentifikatsiyasi, foydalanuvchi huquqlarini serverda tekshirish, fayl yuklash va ma’lumotlar bazasi hali ulanmagan. Haqiqiy shaxsiy yoki moliyaviy ma’lumotlar bilan ishlash uchun ushbu server qismlari kerak.

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

`BASE_URL` orqali test serveri manzilini almashtirish mumkin. Testlar alohida brauzer kontekstida barcha sahifalarning boshlang‘ich bo‘sh holati, nol statistika, bo‘sh profil, lavozim yaratish, login-parol olish, noto‘g‘ri parolni rad etish, xodim profilini yakunlash va tahrirlash, profil tugamasdan xodimni ro‘yxatga qo‘shmaslik, ikki oyna o‘rtasida yangilanish, topshiriq yaratish, qidiruv, topshiriqni yakunlash, chat va uning saqlanishi, eski namuna yozuvlarini tozalash, foydalanuvchi ma’lumotlarini saqlash hamda mobil menyuni tekshiradi. Testlar haqiqiy foydalanuvchi brauzeridagi ma’lumotlarni o‘zgartirmaydi.

## Vercel orqali joylashtirish

GitHub repozitoriysini Vercel loyihasiga ulang va production branch sifatida `main` ni tanlang. Root Directory repozitoriy ildizi (`.`) bo‘lishi kerak. `vercel.json` quyidagilarni belgilaydi:

- Framework: Vite
- Install Command: `npm ci`
- Build Command: `npm run build`
- Output Directory: `dist`

Frontend mahalliy rejimda ishlashi uchun muhit o‘zgaruvchilari yoki maxfiy kalitlar talab qilinmaydi. Git integratsiyasida avtomatik deploy yoqilgan bo‘lsa, `main` ga push yangi deployment yaratadi.

## Lavozim → login → xodim profili

1. Direktor **Xodimlar → Lavozim yaratish** oynasida faqat lavozim nomini kiritadi. Mavjud variantni tanlash yoki yangi lavozim yozish mumkin.
2. Tasodifiy login-parol yaratiladi. Parol faqat natija oynasida ko‘rsatiladi, nusxalash mumkin. Oyna yopilgach, parolning ochiq nusxasi saqlanmaydi. Kutilayotgan lavozim uchun yangi parol olish mumkin; oldingi parol bekor bo‘ladi.
3. Lavozim **Profil to‘ldirilishi kutilmoqda** ro‘yxatida turadi. Xodimlar soniga qo‘shilmaydi, topshiriq uchun mas’ul sifatida tanlanmaydi.
4. **Xodim kirishi** tugmasi yoki saytning `#xodim` manzili orqali xodim login-parol kiritadi.
5. Xodim ism-familiya, telefon, elektron pochta va manzilini o‘zi kiritadi. Tug‘ilgan sana ixtiyoriy. Lavozimni o‘zgartira olmaydi.
6. **Profilni yakunlash** bosilgach, direktor ro‘yxatida to‘liq xodim paydo bo‘ladi. Xodim o‘z profilini tahrirlashi va biriktirilgan topshiriqlarini ko‘rishi mumkin.

**Bu mahalliy prototip, haqiqiy autentifikatsiya tizimi emas.** Loginlar faqat yaratilgan brauzerda (shu sayt manzilida) ishlaydi. Bir brauzerdagi oynalar `storage` hodisasi orqali yangilanadi; boshqa qurilmalar o‘rtasida sinxronlash yo‘q. Parollar PBKDF2-SHA256 yordamida alohida salt bilan xeshlanadi, lekin brauzer xotirasi serverdagi kirish nazoratini almashtirmaydi. Direktor kabinetiga sinov uchun kirish ochiq. Haqiqiy ishlatish uchun direktor va xodim autentifikatsiyasini, rollar bo‘yicha server ruxsatlarini, sessiyalarni va umumiy bazani ulash kerak. Prototipda haqiqiy parollarni qayta ishlatmang.
