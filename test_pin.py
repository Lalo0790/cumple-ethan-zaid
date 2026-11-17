import os,json,urllib.request
from playwright.sync_api import sync_playwright
PIN=os.environ["CUMPLE_PANEL_PIN"]; BAD="0000" if PIN!="0000" else "1111"
U="https://lalo0790.github.io/cumple-ethan-zaid/"; S="/workspace/cumple-ethan-zaid/shots/"
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/usr/bin/google-chrome",args=["--no-sandbox"])
    ctx=b.new_context(viewport={"width":390,"height":844},device_scale_factor=2,is_mobile=True,has_touch=True,locale="es-MX")
    pg=ctx.new_page(); errs=[]; pg.on("pageerror",lambda e:errs.append(str(e)))
    pg.goto(U,wait_until="networkidle"); pg.screenshot(path=S+"10-portada.png")
    pg.goto(U+"admin.html",wait_until="networkidle")
    print("input mode:",pg.get_attribute("#pi","inputmode"),"| titulo:",pg.inner_text("#pin h2"),"|",pg.inner_text("#pin p"))
    pg.screenshot(path=S+"11-pin.png")
    pg.fill("#pi",BAD); pg.wait_for_selector("#pe:not(:empty)"); print("PIN malo ->",pg.inner_text("#pe"),"| panel visible:",pg.is_visible("#m"))
    pg.fill("#pi",PIN); pg.wait_for_selector("#m:not([hidden])")
    print("PIN bueno -> panel:",{i:pg.inner_text("#"+i) for i in ("t-total","t-fam","t-no")},pg.inner_text("#l-fam"),"|",pg.inner_text("#lista"))
    print("guardado en localStorage:",pg.evaluate("!!localStorage.getItem('cumple-pin')"))
    pg.screenshot(path=S+"12-panel.png")
    pg.reload(wait_until="networkidle"); pg.wait_for_selector("#m:not([hidden])"); print("recarga sin teclear PIN -> panel visible: True")
    pg.click("#salir"); pg.wait_for_selector("#pin:not([hidden])"); print("Salir -> pide PIN:",pg.is_visible("#pin"),"| guardado:",pg.evaluate("!!localStorage.getItem('cumple-pin')"))
    pg.goto(U+"admin.html#k=bI4NoCKZ8q7C-oqnn_f5B5DG",wait_until="networkidle"); print("enlace viejo -> pide PIN:",pg.is_visible("#pin"),"| panel:",pg.is_visible("#m"))
    # respuesta de las funciones con clave vieja
    print("errores JS:",errs); b.close()
# lockout directo
import re
cfg=open("js/app.js").read(); key=re.search(r'KEY="([^"]+)"',cfg).group(1)
def rpc(pin):
    r=urllib.request.Request("https://ustkwaeyanwhdoirrpld.supabase.co/rest/v1/rpc/cumple_lista",json.dumps({"p_pin":pin}).encode(),{"apikey":key,"Authorization":"Bearer "+key,"Content-Type":"application/json"})
    j=json.load(urllib.request.urlopen(r)); return {k:j[k] for k in ("ok","error","restantes") if k in j}
print("fallos:",[rpc(BAD) for _ in range(6)])
print("PIN correcto estando bloqueado:",rpc(PIN))
