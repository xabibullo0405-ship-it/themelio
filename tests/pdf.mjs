import {readFile} from 'node:fs/promises';
import {PDFDocument,PDFName,PDFDict} from 'pdf-lib';
import assert from 'node:assert/strict';
import {buildReportsPdf} from '../src/lib/pdfDocument.js';
const fontBytes=await readFile('src/assets/DejaVuSans.ttf'),boldFontBytes=await readFile('src/assets/DejaVuSans-Bold.ttf');
const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j8S8AAAAASUVORK5CYII=','base64');
const report={title:'O‘zbekcha qurilish hisoboti',person:'one',project:'site',date:'2026-10-16',time:'09:00',type:'morning',status:'rejected',rejectionReason:'Rasmni aniqlashtiring',text:'Qurilish ishlari to‘g‘risida hisobot. '.repeat(200),photos:['one','two']};
const input={reports:[report],getPerson:()=>({name:'Sinov Xodimi',role:'Prorab'}),getProject:()=> 'Andijon obyekt',fontBytes,boldFontBytes,loadPhoto:async()=>image};
const bytes=await buildReportsPdf(input);assert.equal(Buffer.from(bytes).subarray(0,4).toString(),'%PDF');
const doc=await PDFDocument.load(bytes);assert(doc.getPageCount()>1,'Long text must paginate');
let images=0;for(const page of doc.getPages()){const resources=page.node.Resources();const objects=resources?.lookupMaybe(PDFName.of('XObject'),PDFDict);if(objects)images+=objects.keys().length}
assert.equal(images,2,'All attached photos must be embedded');
await assert.rejects(buildReportsPdf({...input,loadPhoto:async()=>{throw new Error('Denied')}}),/Denied/);
await assert.rejects(buildReportsPdf({...input,reports:[]}),/hisobot tanlang/);
console.log('PDF passed: Unicode font embedding, multi-page wrapping, both photos embedded, failed photo load prevents incomplete download and empty report validation.');
