import re,sys
from playwright.sync_api import sync_playwright
BASE="https://lalo0790.github.io/cumple-ethan-zaid/"
adm=re.search(r'(https://\S+admin\.html#k=\S+)',open('/home/box/private/cumple-ethan-zaid.txt').read()).group(1)
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/usr/bin/google-chrome",args=["--no-sandbox"]) 
    ctx=b.new_context(viewport={"width":390,"height":844},device_scale_factor=2,is_mobile=True,has_touch=True,locale="es-MX",timezone_id="America/Mexico_City")
    pg=ctx.new_page(); errs=[]; pg.on("console",lambda m: errs.append(m.text) if m.type=="error" else None); pg.on("pageerror",lambda e: errs.append(str(e)))
    pg.goto(BASE,wait_until="networkidle")
    pg.screenshot(path="/workspace/cumple-ethan-zaid/shots/01-portada.png")
    pg.locator("#detalles").scroll_into_view_if_needed(); pg.wait_for_timeout(500)
    pg.screenshot(path="/workspace/cumple-ethan-zaid/shots/full.png",full_page=True)
    print("countdown",[pg.inner_text(i) for i in ("#c-d","#c-h","#c-m","#c-s")])
    # test 1: sí
    pg.fill("#nombre","PRUEBA Familia Test Uno"); pg.click("label[for=si]")
    pg.fill("#adultos","2"); pg.fill("#ninos","3"); pg.fill("#mensaje","mensaje de prueba")
    pg.click("#enviar"); pg.wait_for_selector("#gracias:not([hidden])"); print("gracias:",pg.inner_text("#g-texto"))
    pg.locator("#confirmar").scroll_into_view_if_needed(); pg.screenshot(path="/workspace/cumple-ethan-zaid/shots/02-gracias.png")
    # test 2: no (fresh context)
    c2=b.new_context(viewport={"width":390,"height":844}); p2=c2.new_page(); p2.goto(BASE,wait_until="networkidle")
    p2.click("#enviar"); print("validación:",p2.inner_text("#error"))
    p2.fill("#nombre","PRUEBA Familia Test Dos"); p2.click("label[for=no]"); p2.click("#enviar"); p2.wait_for_selector("#gracias:not([hidden])"); print("gracias2:",p2.inner_text("#g-titulo"))
    # admin
    a=ctx.new_page(); a.goto(adm,wait_until="networkidle"); a.wait_for_selector("#m:not([hidden])")
    print("admin:",{i:a.inner_text("#"+i) for i in ("t-total","t-fam","t-no","t-ad","t-ni")})
    a.screenshot(path="/workspace/cumple-ethan-zaid/shots/03-admin.png",full_page=True)
    # clave incorrecta
    w=ctx.new_page(); w.goto(BASE+"admin.html#k=mala",wait_until="networkidle"); w.wait_for_timeout(800); print("clave mala:",w.inner_text("#aviso"))
    # borrar vía UI
    a.on("dialog",lambda d:d.accept())
    while a.locator(".fila button").count():
        n=a.locator(".fila button").count(); a.locator(".fila button").first.click(); a.wait_for_function(f"document.querySelectorAll('.fila button').length<{n}")
    print("admin tras borrar:",{i:a.inner_text("#"+i) for i in ("t-total","t-fam","t-no","t-ad","t-ni")},a.inner_text("#lista"))
    print("errores consola:",errs)
    b.close()
