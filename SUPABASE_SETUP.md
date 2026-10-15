# Supabase’ni ishga tushirish

Loyiha: `pumkmcpekrbshcvfojim`.
Frontend uchun to‘g‘ri URL: `https://pumkmcpekrbshcvfojim.supabase.co` — `/rest/v1/` qo‘shimchasisiz.

## Hozir nima tayyor?

- Sayt Supabase Auth orqali login/parol bilan kiradi. Direktor yoki xodim kabineti bazadagi rol bo‘yicha ochiladi.
- Eski mahalliy hisoblar haqiqiy hisobga avtomatik aylantirilmaydi. Login sahifasini chetlab direktor kabinetiga kirish olib tashlangan.
- SQL migratsiyasi: `members`, `reports`, `tasks`, `messages`, profilni yakunlash funksiyalari va RLS ruxsatlari.
- Bitta kompaniya uchun jami 10 hisob: 1 direktor + 9 xodim. Parallel hisob yaratish so‘rovlarida ham SQL darajasida limit tekshiriladi.
- Xodim faqat o‘z hisobotlari va topshiriqlarini ko‘radi. Direktor barcha hisobotlarni ko‘radi va tasdiqlaydi.
- Realtime yangilanishlar yoqiladi; sahifa fokusga qaytganda va har 30 soniyada zaxira yangilanish ham bor.
- Lavozim yaratish/parol yangilash uchun serverdagi `manage-members` Edge Function tayyor.
- Dastlabki 10 hisobni Auth Admin API bilan yaratuvchi `npm run provision` skripti tayyor.

**Fayllarning repozitoriyda mavjudligi ularning Supabase’da o‘rnatilganini anglatmaydi. Quyidagi amallar haqiqiy loyiha administratori kirishini talab qiladi. Public/publishable kalit bunga yetmaydi.**

## Qisman o‘rnatilgan bazani tiklash

Agar `function "is_director" already exists` yoki oldingi bajarishda `public.members does not exist` xatosi chiqqan bo‘lsa, SQL Editor’da **yangi so‘rov** oching va `scripts/repair-schema.sql` faylini to‘liq bajaring. Unda asosiy jadvallar ham, kamera rasmlari uchun Storage sozlamalari ham bor. Mavjud hisob va hisobot yozuvlari o‘chirilmaydi; faqat Themelio’ning nomlangan funksiyalari, triggeri va siyosatlari qayta o‘rnatiladi. Ushbu sxemada faylni qayta bajarish mumkin.

Natijada `status = Baza tayyor`, `accounts` va `director_accounts` chiqadi. `director_accounts = 0` bo‘lsa, direktor hisobi hali yo‘q: parolni yangilash skripti hisob yaratmaydi. Hisob yaratish bosqichini bajaring. Bu tiklash usuli ma’lum Themelio sxemasi uchun; bir xil nomli, boshqa tuzilishdagi jadvallar bo‘lsa, ularni o‘chirmang va xatoni tekshiring.

## 1. Jadvallarni yarating

Supabase Dashboard → loyihangiz → **SQL Editor → New query**.

`supabase/migrations/202610150001_initial.sql` faylining to‘liq matnini ko‘chirib, **Run** bosing. Keyin alohida so‘rovda `supabase/migrations/202610150002_report_photos.sql` faylini bajaring. Agar birinchi migratsiya oldin bajarilgan bo‘lsa, uni qaytarmang — faqat ikkinchisini bajaring. Bu bir martalik, tranzaksiyali migratsiya. Shu nomdagi jadvallar oldin bo‘lsa, ustiga qayta ishga tushirmang; holatni avval tekshiring.

Migratsiya Auth foydalanuvchisi yaratilganda `members` yozuvini avtomatik yaratadigan trigger o‘rnatadi. `app_role` va `position` faqat administrator bergan `app_metadata`dan olinadi. Oddiy signup yoki profil formasi direktor rolini bera olmaydi.

Authentication sozlamalarida Email/Password kirishini yoqing, ochiq **Allow new users to sign up** ni o‘chiring. Hisoblarni direktor/server admin yaratadi; xodimlar o‘zlari ochiq ro‘yxatdan o‘tmaydi. Trigger ham ruxsatsiz signupni rad etadi.

## 2. Server funksiyasini joylashtiring

Supabase Dashboard → **Edge Functions → Deploy a new function → Via Editor**:

- Nomi: `manage-members`
- Kodi: `supabase/functions/manage-members/index.ts` faylining to‘liq matni.
- Deploy qiling.
- Agar `Verify JWT with legacy secret` sozlamasi bo‘lsa, o‘chiring. **Funksiya har bir so‘rovda JWTni `auth.getUser` orqali o‘zi tekshiradi**, keyin bazadagi direktor rolini tekshiradi. Bu sozlama loginni tekshirmaslik degani emas.
- `SUPABASE_URL` va `SUPABASE_SERVICE_ROLE_KEY` Supabase Edge muhitida avtomatik taqdim etiladi. Ularni frontendga qo‘shmang.

CLI orqali o‘rnatish varianti (Supabase akkauntingiz bilan autentifikatsiya talab qiladi):

```sh
npx supabase@latest login
npx supabase@latest functions deploy manage-members --project-ref pumkmcpekrbshcvfojim --no-verify-jwt
```

## SQL Editor orqali birinchi direktor hisobini tiklash

Agar `repair-schema.sql` natijasida `director_accounts = 0` chiqsa va Auth Admin API bilan ishlash uchun server kaliti muhitga uzatilmayotgan bo‘lsa, loyiha administratori SQL Editor’da `scripts/create-director.sql` faylini **to‘liq** bajarishi mumkin.

Bu administrator uchun tiklash skripti: `auth.users`, email `auth.identities` va Themelio profilini yaratadi. Login `direktor`, tasodifiy parol esa oxirgi **Results → new_password** ustunida ko‘rinadi. Parolni xavfsiz saqlang. Mavjud direktor topilsa, uning paroli o‘zgartirilmaydi; parol yo‘qolgan bo‘lsa `scripts/reset-director.sql` ishlatiladi. Ushbu fayllar frontendga qo‘shilmaydi va ommaviy RPC yaratmaydi.

Bu usul standart Supabase Auth sxemasi va `extensions` sxemasidagi pgcrypto funksiyalariga mo‘ljallangan. SQL sxemasi mahalliy modelda tekshirilgan; haqiqiy Auth kirishi SQL bajarilgandan keyin tekshiriladi. Kundalik yangi xodimlar uchun rasmiy Auth Admin API’ni ishlatuvchi Edge Function afzal.

Birinchi direktor kirgach, qolgan 9 ta xodim lavozimini kabinet orqali bittadan yaratishi mumkin. Bu bilan dastlabki xodimlar parollari direktorning tegishli oynasida ko‘rsatiladi.

## 3. Dastlabki 10 ta hisobni yarating

Bu amalni ishonchli lokal terminalda yoki shu cloud muhitda bajaring. Kerakli administrator kaliti: Supabase **Project Settings → API Keys → service_role / server secret key**. Public/publishable kalitni ishlatmang.

Kalitni chatga yoki GitHubga yubormang. Shu cloud muhitda ishlatish uchun environment settings’dagi `SUPABASE_SERVICE_ROLE_KEY` maxfiy talabi orqali xavfsiz kiriting; loyiha domeniga tarmoq kirishini ham saqlang. Muhit sozlamalari o‘zgarishi joriy jarayonga qo‘llangach skript qayta tekshiriladi. Lokal Bash terminalda esa kalitni buyruqlar tarixiga yozmasdan kiriting:

```sh
read -rsp 'Supabase server key: ' SUPABASE_SERVICE_ROLE_KEY
export SUPABASE_SERVICE_ROLE_KEY
printf '\n'
npm ci
npm run provision
unset SUPABASE_SERVICE_ROLE_KEY
```

Natija:

- `direktor` — Direktor.
- `xodim01` … `xodim09` — xodimlar; boshlang‘ich lavozimlar skriptdagi `positions` ro‘yxatida. Kerak bo‘lsa, skriptni bajarishdan oldin shu lavozimlarni o‘zgartiring.
- Har bir hisob uchun alohida tasodifiy kuchli parol yaratiladi. `auth.users`ga to‘g‘ridan-to‘g‘ri SQL yozilmaydi, rasmiy Auth Admin API ishlatiladi.
- Yangi parollar faqat `.private/themelio-credentials.json` fayliga `0600` ruxsat bilan yoziladi; konsolga chiqarilmaydi, Git’dan chiqarib tashlangan. Faylni xavfsiz joyda saqlang va har bir xodimga faqat uning login-parolini bering.
- Oldin mavjud hisoblar/parollar o‘zgartirilmaydi. Qisman xatolik bo‘lsa, yaratilgan hisoblarning ma’lumotlari faylda qoladi. Qayta urinish uchun `CREDENTIALS_FILE=.private/credentials-next.json npm run provision` kabi boshqa chiqish faylini belgilang.
- Xodimning ismi va boshqa shaxsiy ma’lumotlari oldindan kiritilmaydi. Login qilib profilini to‘ldirgach, direktor ro‘yxatiga qo‘shiladi.

**10 ta hisobning barchasi yaratilgach, yana yangi hisob yaratib bo‘lmaydi.** Dastlabki 9 xodim lavozimi oldindan tayyorlanadi; ularni ushbu jamoangiz uchun moslab oling. Hisobni to‘liq o‘chirish/almashtirish uchun administrator amali kerak bo‘ladi; frontendda o‘chirish hali qo‘shilmagan.

## 4. Vercel sozlamalari

`.env.example` frontend uchun faqat ommaviy qiymatlarni ko‘rsatadi:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Bu loyihaning public qiymatlari kodda standart sifatida ham mavjud. Vercel → Project → Settings → Environment Variables’da ularni belgilab, **Redeploy** qilish mumkin. Brauzer kodi ichida `service_role`, server secret key yoki Supabase access token bo‘lmasligi kerak. Vercelga server kalitini berish talab qilinmaydi: hisob yaratish Supabase Edge Function’da bajariladi.

## 5. Haqiqiy ishga tushirish tekshiruvi

1. `direktor` bilan kiring; direktorning o‘z profilini to‘ldiring.
2. Boshqa qurilma yoki inkognito brauzerda `xodim01` bilan kiring, profilini yakunlang.
3. Direktorning Xodimlar sahifasida shu xodim ko‘ringanini tekshiring.
4. Xodim ertalabki/yakuniy hisobot yuborsin; direktor ayni sana va tur filtrida hisobotni ochib tasdiqlasin.
5. Xodim sahifasida **Qabul qilindi** holati paydo bo‘lsin.
6. `xodim02` bilan kirganda boshqa xodimning hisoboti ko‘rinmasligi kerak.
7. Direktor topshiriq biriktirsin; tegishli xodim o‘z kabinetida bajarilish foizini yangilasin.

SQL bazasi, Auth hisoblari va Edge Function o‘rnatilmaguncha ushbu haqiqiy tekshiruvlar o‘tkazilgan hisoblanmaydi.

## Chegaralar va test dalillari

- Kamera orqali olingan JPEG rasmlar hisobotga qo‘shiladi. Har bir hisobotga 5 tagacha, har bir rasm 5 MB gacha. Galereya/fayl tanlash yo‘q. PDF yuklash hali qo‘shilmagan.
- Loyiha bitta kompaniyaga mo‘ljallangan. Bir nechta kompaniya uchun alohida tenant va RLS qoidalari kerak.
- Savdo va obyekt boshqaruvi hozircha bo‘sh interfeys holatida.
- `test:db` — aynan SQL migratsiyasini PGlite/PostgreSQL’da bajarib RLS, rollar, 10 hisob limiti, hisobotlar, topshiriqlar va xabarlar ruxsatlarini tekshiradi.
- `test:edge` — Edge handlerni mock Auth Admin API bilan tekshiradi.
- `test:ui` — Supabase HTTP javoblarini mock qilib haqiqiy brauzerda ikki mustaqil sessiya oqimini tekshiradi. Haqiqiy Supabase loyihasiga ulanmaydi.
- Cloud test muhitida Supabase domeniga dastlabki so‘rovlar proxy tomonidan `403 Forbidden` bilan rad etilgan. Domen muhit konfiguratsiyasi loyihasiga qo‘shilgan; bu joriy tarmoq allaqachon ochilganini bildirmaydi.

## Faqat kameradan rasmli hisobot

`202610150002_report_photos.sql` migratsiyasi `report-photos` nomli **yopiq** Storage bucket va rasmlarni hisobotga biriktirish funksiyasini yaratadi.

- Xodim faol profil bilan kiradi, **Kamerani ochish → Rasmga olish** tugmalaridan foydalanadi. Brauzerga kamera ruxsati berilishi kerak. Telefonning orqa kamerasi afzal tanlanadi; kameralarni almashtirish ham bor.
- Qurilma kamerasidan `getUserMedia` orqali olinadi; galereya uchun `input[type=file]` mavjud emas. Kamera uchun HTTPS yoki localhost kerak. Haqiqiy telefonlarda kamera ruxsatlari va brauzer qo‘llab-quvvatlashini tekshiring.
- Rasm JPEG sifatida maksimal 1920 pikselga moslanadi. Yuborishdan oldin preview ko‘rinadi; ortiqcha rasmni o‘chirish mumkin.
- Kamera surat olingach, oyna yopilgach yoki sahifa yashirilgach to‘xtatiladi. Mikrofon so‘ralmaydi.
- Fayllar faqat xodimning UUID papkasiga yuklanadi. Xodim o‘z rasmlarini, direktor esa yuborilgan hisobotga biriktirilgan rasmlarni ko‘radi. Boshqa xodimlar ko‘ra olmaydi. Bucket ommaviy emas.
- Rasm ko‘rish uchun 10 daqiqalik vaqtinchalik havola yaratiladi. Ochiq sahifada havolalar yangilanadi. Hisobotga biriktirilgan rasmlarni xodim almashtira yoki o‘chira olmaydi.
- Yuborishda xatolik bo‘lsa, tanlangan rasmlar va matn formadan o‘chmaydi. Yuklangan qoralamalarni tozalashga urinish qilinadi. Ulanish to‘liq uzilsa, yuborilmagan fayl bucketda qolishi mumkin; keyinchalik administrator qoralamalarni tozalashi mumkin.
- Har bir yuborishning UUIDsi bor: server javobi yo‘qolganidan keyin qayta urinish bir xil hisobotni takror yaratmaydi.

Mahalliy baza testlari Storage jadvallari modeli bilan haqiqiy SQL siyosatlarini bajaradi; brauzer testi sun’iy kamera va mock Supabase Storage javoblarini ishlatadi. Haqiqiy Supabase Storage va jismoniy telefondagi kamera tekshiruvi migratsiya o‘rnatilgandan keyin alohida bajariladi.
