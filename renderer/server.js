const http=require('http');
const fs=require('fs');
const dns=require('dns').promises;
const net=require('net');
const {chromium}=require('playwright-core');

const SOCKET=process.env.RENDERER_SOCKET||'/run/lumenapi-renderer/render.sock';
const PORT=Number(process.env.RENDERER_PORT||0);
const HOST=process.env.RENDERER_HOST||'0.0.0.0';
const MAX_BODY=16384;
const MAX_ACTIVE=2;
let active=0;
let browser;
const dnsCache=new Map();
const DNS_TTL=60000;
const CONTEXT_POOL_SIZE=2;
const contextPool=[];
let fillingPool=false;
const contextOptions={
  userAgent:'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/154 Safari/537.36',
  locale:'zh-CN',javaScriptEnabled:true,ignoreHTTPSErrors:false
};

function publicIp(ip){
  if(!net.isIP(ip)) return false;
  if(net.isIPv4(ip)){
    const p=ip.split('.').map(Number);
    if(p[0]===10||p[0]===127||p[0]===0||p[0]>=224||(p[0]===169&&p[1]===254)||(p[0]===172&&p[1]>=16&&p[1]<=31)||(p[0]===192&&p[1]===168)||(p[0]===100&&p[1]>=64&&p[1]<=127)) return false;
    return true;
  }
  const x=ip.toLowerCase();
  return !(x==='::1'||x==='::'||x.startsWith('fc')||x.startsWith('fd')||x.startsWith('fe8')||x.startsWith('fe9')||x.startsWith('fea')||x.startsWith('feb')||x.startsWith('::ffff:127.')||x.startsWith('::ffff:10.')||x.startsWith('::ffff:192.168.'));
}
async function safeUrl(raw){
  let u; try{u=new URL(raw);}catch{return false;}
  if(!['http:','https:'].includes(u.protocol)||u.username||u.password) return false;
  const host=u.hostname.replace(/^\[|\]$/g,'').toLowerCase();
  if(host==='localhost'||host.endsWith('.localhost')) return false;
  if(net.isIP(host)) return publicIp(host);
  const now=Date.now(), cached=dnsCache.get(host);
  if(cached&&cached.expires>now) return cached.safe;
  try{
    const rows=await dns.lookup(host,{all:true,verbatim:true});
    const safe=rows.length>0&&rows.every(x=>publicIp(x.address));
    dnsCache.set(host,{safe,expires:now+DNS_TTL});
    if(dnsCache.size>2048){
      for(const [k,v] of dnsCache){if(v.expires<=now)dnsCache.delete(k);}
      while(dnsCache.size>2048)dnsCache.delete(dnsCache.keys().next().value);
    }
    return safe;
  }catch{
    dnsCache.set(host,{safe:false,expires:now+5000});
    return false;
  }
}
function placeholderTitle(title){
  const t=String(title||'').trim().toLowerCase();
  if(!t) return true;
  const exact=new Set(['loading','loading...','加载中','加载中...','请稍后','请稍后...','please wait','please wait...','just a moment','just a moment...','checking','checking...']);
  if(exact.has(t)) return true;
  return /^(正在)?(加载|跳转|验证|检查)(中|\.\.\.|…)?$/.test(t);
}
function send(res,status,obj){
  const b=JSON.stringify(obj);
  res.writeHead(status,{'content-type':'application/json; charset=utf-8','content-length':Buffer.byteLength(b)});
  res.end(b);
}
async function ensureBrowser(){
  if(browser&&browser.isConnected()) return browser;
  browser=await chromium.launch({
    executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium-browser',
    headless:true,
    args:['--disable-dev-shm-usage','--disable-gpu','--no-sandbox']
  });
  return browser;
}
async function fillContextPool(){
  if(fillingPool) return;
  fillingPool=true;
  try{
    const b=await ensureBrowser();
    while(contextPool.length<CONTEXT_POOL_SIZE){
      const ctx=await b.newContext(contextOptions);
      const page=await ctx.newPage();
      contextPool.push({ctx,page});
    }
  }finally{fillingPool=false;}
}
async function acquireContext(){
  const item=contextPool.shift();
  if(item){fillContextPool().catch(()=>{});return item;}
  const b=await ensureBrowser();
  const ctx=await b.newContext(contextOptions);
  const page=await ctx.newPage();
  return {ctx,page};
}
async function render(url,timeout,selector=''){
  const tm={start:Date.now()};
  if(!await safeUrl(url)) throw Object.assign(new Error('unsafe_url'),{status:422});
  tm.safe=Date.now();
  await ensureBrowser();
  const item=await acquireContext();
  const ctx=item.ctx, page=item.page;
  tm.page=Date.now();
  try{
    await page.route('**/*',async route=>{
      const req=route.request(), ru=req.url(), type=req.resourceType();
      if(['image','media','font'].includes(type)) return route.abort('blockedbyclient');
      if(ru.startsWith('data:')||ru.startsWith('blob:')||ru==='about:blank') return route.continue();
      if(!await safeUrl(ru)) return route.abort('blockedbyclient');
      return route.continue();
    });

    // Generic title requests start at commit for speed. Selector-based private
    // extraction waits for DOMContentLoaded so the configured body node can exist.
    let response=null, navError=null, navDone=false;
    if(selector){
      try{response=await page.goto(url,{waitUntil:'domcontentloaded',timeout});navDone=true;}
      catch(e){navError=e;navDone=true;}
    }else{
      page.goto(url,{waitUntil:'commit',timeout}).then(r=>{response=r;navDone=true;}).catch(e=>{navError=e;navDone=true;});
    }
    const started=Date.now();
    let title='',last='',stableSince=0,firstTitleAt=0;
    const stableMs=450, minObserveMs=3500, pollMs=75;
    while(Date.now()-started<timeout){
      try{title=(await page.title()).trim();}catch{title='';}
      if(title!==last){
        last=title;
        stableSince=title?Date.now():0;
        if(title&&!firstTitleAt) firstTitleAt=Date.now();
      }
      // Give client-side apps a short opportunity to replace an initial placeholder,
      // then return as soon as the title is stable.
      if(title&&!placeholderTitle(title)&&stableSince&&Date.now()-stableSince>=stableMs&&Date.now()-firstTitleAt>=minObserveMs) break;
      if(navDone&&navError&&!title) throw navError;
      await page.waitForTimeout(pollMs);
    }
    tm.goto=Date.now();
    if(!title) throw Object.assign(new Error('title_not_found'),{status:422});
    let meta={description:'',keywords:''};
    try{
      meta=await page.evaluate(()=>({
        description:(document.querySelector('meta[name="description" i]')?.getAttribute('content')||'').trim(),
        keywords:(document.querySelector('meta[name="keywords" i]')?.getAttribute('content')||'').trim()
      }));
    }catch{}
    let selectorText='';
    selector=String(selector||'').trim();
    if(selector&&selector.length<=256){
      try{
        try{await page.waitForLoadState('domcontentloaded',{timeout:2500});}catch{}
        const node=page.locator(selector).first();
        await node.waitFor({state:'attached',timeout:2500});
        selectorText=(await node.textContent()||'').trim();
      }catch{}
    }
    const finalUrl=page.url();
    // finalUrl is the browser's committed/current URL. Redirect/request safety has
    // already been enforced by page.route() before network access. Do not perform
    // another DNS lookup here or wait for window.stop() on the response path.
    tm.done=Date.now();
    const titleHtml='<title>'+title.replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;')+'</title>';
    return {ctx,data:{title,title_html:titleHtml,selector_text:selectorText,description:meta.description,keywords:meta.keywords,final_url:finalUrl,http_status:response?response.status():0,timing:{
      safe_ms:tm.safe-tm.start,page_ms:tm.page-tm.safe,title_wait_ms:tm.goto-tm.page,
      finish_ms:tm.done-tm.goto,total_ms:tm.done-tm.start
    }}};
  }catch(e){
    // Error paths still clean up before returning so failed pages cannot linger.
    try{await ctx.close();}catch{}
    throw e;
  }
}
const server=http.createServer((req,res)=>{
  if(req.method==='GET'&&req.url==='/healthz') return send(res,200,{ok:true});
  if(req.method!=='POST'||req.url!=='/render') return send(res,404,{error:'not_found'});
  if(active>=MAX_ACTIVE) return send(res,503,{error:'busy'});
  let body='',size=0;
  req.on('data',c=>{size+=c.length;if(size>MAX_BODY){req.destroy();return;}body+=c;});
  req.on('end',async()=>{
    let data;try{data=JSON.parse(body);}catch{return send(res,400,{error:'invalid_json'});}
    const url=String(data.url||'').trim();
    const timeout=Math.min(15000,Math.max(2000,Number(data.timeout)||10000));
    const selector=String(data.selector||'').trim();
    active++;
    try{
      const result=await render(url,timeout,selector);
      send(res,200,{ok:true,...result.data});
      // Response is already handed to PHP. Close only this request's isolated context.
      result.ctx.close().catch(()=>{}).finally(()=>{active--;});
    }
    catch(e){send(res,e.status||502,{ok:false,error:e.message||'render_failed'});active--;}
  });
});
(async()=>{
  await ensureBrowser();
  await fillContextPool();
  if(PORT>0){
    server.listen(PORT,HOST);
  }else{
    try{fs.unlinkSync(SOCKET);}catch{}
    server.listen(SOCKET,()=>{fs.chmodSync(SOCKET,0o660);});
  }
})();
process.on('SIGTERM',async()=>{try{server.close();if(browser)await browser.close();}finally{process.exit(0);}});
