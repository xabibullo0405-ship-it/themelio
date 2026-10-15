# Themelio — qurilish boshqaruvi

PDF maketlari asosida yaratilgan o‘zbek tilidagi React/Vite kabineti. Supabase Auth, direktor/xodim rollari, xodimning o‘z profilini to‘ldirishi, hisobot yuborish va direktor tomonidan tasdiqlash qo‘shilgan.

## Ishga tushirish

Node.js 22.12+ yoki 24:

```sh
npm ci --cache /tmp/themelio-npm-cache
npm run dev -- --port 3000
```

Ishchi papka: `/workspace/themelio`. Production: `npm run build`, natija `dist/`. Vercel sozlamalari `vercel.json`da.

## Supabase’ni o‘rnatish

**[SUPABASE_SETUP.md](SUPABASE_SETUP.md)** qo‘llanmasini bajaring:

1. SQL Editor’da `supabase/migrations/202610150001_initial.sql` migratsiyasini bajaring.
2. `supabase/functions/manage-members/index.ts` Edge Function’ni joylashtiring.
3. Server kaliti bilan `npm run provision` bajarib 1 direktor + 9 xodim hisobini yarating. Parollar faqat Git’dan chiqarilgan `.private/` fayliga yoziladi.
4. Saytda login, profil, hisobot yuborish va tasdiqlashni ikki qurilmada tekshiring.

Public loyiha URL/kaliti kodda sozlangan, `.env.example` orqali almashtirilishi mumkin. Public kalit jadvallar yoki Auth hisoblarini yaratishga ruxsat bermaydi. Server kalitlari hech qachon `VITE_*` ichiga kiritilmaydi.

Eski mahalliy brauzer hisoblari serverga avtomatik ko‘chirilmaydi. Supabase o‘rnatilmaguncha haqiqiy tizim tayyor deb hisoblamang.

## Imkoniyatlar

- Supabase login/parol va sessiya; rol bazadan aniqlanadi.
- Jami 10 hisob chegarasi, direktor boshqaradigan lavozim va login-parol yaratish.
- Xodim profilini o‘zi to‘ldiradi; yakunlangach direktor ro‘yxatida ko‘rinadi.
- Matnli ertalabki/yakuniy hisobotlar, sana filtri, direktor tasdig‘i, CSV eksport.
- Direktor topshiriq biriktiradi, xodim bajarilish foizini yangilaydi.
- Direktorning xodimga xabar yuborishi, xabarlar uchun bazada shaxsiy ruxsatlar.
- Mobil ko‘rinish, qidiruv, arxiv, profil, bildirishnomalar.

PDF/rasm yuklash, obyektlar va sotuvlarni serverda boshqarish hali ulanmagan.

## Testlar

```sh
npm run test:db
npm run test:edge
# Dev server 3000-portda ishlab turgan bo‘lishi kerak:
BROWSER_PATH=/usr/bin/chromium npm run test:ui
npm run build
```

Chromium bo‘lmasa `npx playwright install chromium`, so‘ng `npm test`. `BASE_URL` test serverini o‘zgartiradi. Baza testlari haqiqiy SQLni lokal PostgreSQL/PGlite’da bajaradi; Edge/UI testlari Supabase API’larini mock qiladi. Bu testlar haqiqiy Supabase deploymenti yoki real hisoblar yaratilganini tasdiqlamaydi.
