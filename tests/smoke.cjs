const { chromium } = require('playwright');
const assert = require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.BROWSER_PATH || undefined,args:['--no-sandbox']});
 try{
 const page=await browser.newPage({viewport:{width:1440,height:1050},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const base=process.env.BASE_URL || 'http://localhost:3000';
 await page.goto(base);
 await page.getByRole('heading',{name:'Themelio’ga xush kelibsiz!'}).waitFor();
 assert.equal(await page.locator('.report-row').count(),0);
 assert.deepEqual(await page.locator('.stat-value').allTextContents(),['0ta','0ta','0ta','0/ 0']);
 await page.getByRole('button',{name:'Bildirishnomalar',exact:true}).click();
 await page.getByRole('heading',{name:'Yangi bildirishnomalar yo‘q'}).waitFor();
 await page.keyboard.press('Escape');
 for(const name of ['Xodimlar','Topshiriqlar','Sotuvlar','Arxiv','Chat']){
  await page.getByRole('button',{name,exact:true}).click();
  assert.equal(await page.locator('.person-card,.task-card,.archive-card,tbody tr,.message').count(),0,name+' should start empty');
  assert(!/Aliyev|Karimov|Sobirova|Rasulov|Rahimov|Umarov|Yusupov|Akbarov/.test(await page.locator('body').innerText()));
 }
 await page.getByRole('button',{name:'Sozlamalar',exact:true}).click();
 assert.equal(await page.getByRole('textbox',{name:'Ism va familiya',exact:true}).inputValue(),'');
 assert.equal(await page.getByRole('textbox',{name:'Elektron pochta',exact:true}).inputValue(),'');
 await page.getByRole('button',{name:'Xodimlar',exact:true}).click();
 await page.getByRole('button',{name:'Birinchi xodimni qo‘shish'}).click();
 await page.getByRole('textbox',{name:'Ism va familiya'}).fill('Sinov Xodimi');
 await page.getByRole('button',{name:'Xodimni qo‘shish',exact:true}).click();
 await page.getByRole('heading',{name:'Sinov Xodimi'}).waitFor();
 const search=page.getByRole('textbox',{name:'Qidirish',exact:true});
 await search.fill('Sinov');await search.press('End');await search.type(' Xodimi');
 assert.equal(await search.inputValue(),'Sinov Xodimi');
 assert.equal(await page.locator('.person-card').count(),1);
 await page.getByRole('button',{name:'Topshiriqlar',exact:true}).click();
 await page.getByRole('button',{name:'Topshiriq yaratish',exact:true}).first().click();
 await page.getByRole('textbox',{name:'Topshiriq nomi'}).fill('Sinov topshirig‘i');
 await page.getByRole('textbox',{name:'Tavsif'}).fill('Bajarilishni tekshirish');
 await page.getByRole('button',{name:'Topshiriqni yaratish'}).click();
 await page.locator('.task-card').getByRole('button',{name:'Batafsil'}).click();
 await page.getByRole('spinbutton').fill('100');
 await page.getByRole('button',{name:'O‘zgarishlarni saqlash'}).click();
 await page.getByRole('button',{name:/^Bajarilgan/}).click();
 await page.getByRole('heading',{name:'Sinov topshirig‘i'}).waitFor();
 await page.getByRole('button',{name:'Chat',exact:true}).click();
 await page.getByRole('heading',{name:'Suhbatni tanlang'}).waitFor();
 await page.locator('.conversation').click();
 await page.getByRole('heading',{name:'Hali xabarlar yo‘q'}).waitFor();
 await page.getByRole('textbox',{name:'Xabar',exact:true}).fill('Sinov xabari');
 await page.getByRole('button',{name:'Xabar yuborish'}).click();
 await page.reload();await page.getByRole('button',{name:'Chat',exact:true}).click();await page.locator('.conversation').click();
 assert.equal(await page.getByText('Sinov xabari',{exact:true}).count(),1);
 await page.getByRole('button',{name:'Sozlamalar',exact:true}).click();
 await page.getByRole('textbox',{name:'Ism va familiya',exact:true}).fill('Shaxsiy Profil');
 await page.getByRole('textbox',{name:'Elektron pochta',exact:true}).fill('profile@example.com');
 await page.getByRole('button',{name:'O‘zgarishlarni saqlash'}).click();await page.reload();
 assert.equal(await page.getByRole('heading',{name:'Themelio’ga xush kelibsiz!'}).count(),0);
 // Upgrade an existing demo browser; preserve manually entered records and custom profile.
 await page.evaluate(()=>{
  localStorage.removeItem('themelio-data-version');
  for(const key of ['people','reports','tasks']){
   const items=JSON.parse(localStorage.getItem('themelio-'+key)||'[]');
   items.push({id:1,name:'Anvar Aliyev',title:'Demo'});
   localStorage.setItem('themelio-'+key,JSON.stringify(items));
  }
 });await page.reload();
 const data=await page.evaluate(()=>({people:JSON.parse(localStorage.getItem('themelio-people')),tasks:JSON.parse(localStorage.getItem('themelio-tasks')),reports:JSON.parse(localStorage.getItem('themelio-reports')),profile:JSON.parse(localStorage.getItem('themelio-profile'))}));
 assert.equal(data.people.length,1);assert.equal(data.people[0].name,'Sinov Xodimi');assert.equal(data.tasks.length,1);assert.equal(data.reports.length,0);assert.equal(data.profile.name,'Shaxsiy Profil');
 // Original default profile must also disappear on upgrade.
 await page.evaluate(()=>{localStorage.removeItem('themelio-data-version');localStorage.setItem('themelio-profile',JSON.stringify({name:'Aziz Karimov',email:'aziz@themelio.uz',notify:true}));});
 await page.reload();await page.getByRole('button',{name:'Sozlamalar',exact:true}).click();
 assert.equal(await page.getByRole('textbox',{name:'Ism va familiya',exact:true}).inputValue(),'');
 await page.evaluate(()=>localStorage.clear());await page.reload();
 await page.screenshot({path:'/tmp/themelio-desktop.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(300);
 await page.screenshot({path:'/tmp/themelio-mobile.png',fullPage:true});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth),false);
 await page.getByRole('button',{name:'Menyu',exact:true}).click();await page.getByRole('button',{name:'Xodimlar',exact:true}).click();
 await page.getByRole('heading',{name:'Hali xodim qo‘shilmagan'}).waitFor();
 assert.deepEqual(errors,[]);
 console.log('Passed: fresh empty state on every page, zero statistics, blank profile, safe notifications/chat, employee and task creation, search, completion, chat persistence, legacy demo cleanup, preservation of user data, mobile layout and navigation.');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
