(function(){
  var SB="https://ustkwaeyanwhdoirrpld.supabase.co", KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzdGt3YWV5YW53aGRvaXJycGxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzNTk0OTcsImV4cCI6MjEwOTkzNTQ5N30.FJS_Sv-CnZc1jwTKP1v6FSQhr7IqIT4tynFz9aMRwQk";
  var $=function(id){return document.getElementById(id)};

  // Cuenta regresiva: 12 dic 2026, 10:00, hora CDMX (UTC-6, sin horario de verano)
  var objetivo=new Date("2026-12-12T10:00:00-06:00").getTime();
  function tick(){
    var d=objetivo-Date.now();
    if(d<=0){
      $("cuenta").hidden=true;
      $("cuenta-msg").textContent = d>-6*3600e3 ? "¡Hoy es la fiesta!" : "La fiesta ya pasó. ¡Gracias por venir!";
      return;
    }
    var s=Math.floor(d/1000);
    $("c-d").textContent=Math.floor(s/86400);
    $("c-h").textContent=Math.floor(s%86400/3600);
    $("c-m").textContent=Math.floor(s%3600/60);
    $("c-s").textContent=s%60;
    setTimeout(tick,1000);
  }
  tick();

  // Mostrar/ocultar personas
  var radios=document.querySelectorAll("input[name=asiste]");
  function sync(){ $("personas").hidden = !$("si").checked; }
  radios.forEach(function(r){r.addEventListener("change",sync)});

  document.querySelectorAll(".step button").forEach(function(b){
    b.addEventListener("click",function(){
      var i=$(b.dataset.t), v=(parseInt(i.value,10)||0)+parseInt(b.dataset.d,10);
      i.value=Math.max(0,Math.min(20,v));
    });
  });

  // Prellenar si ya confirmó desde este teléfono
  var prev=null; try{prev=JSON.parse(localStorage.getItem("cumple-ez"))}catch(e){}
  if(prev){ mostrarGracias(prev); }

  function mostrarGracias(r){
    $("rsvp").hidden=true; $("gracias").hidden=false;
    if(r.asiste){
      var n=r.adultos+r.ninos;
      $("g-titulo").textContent="¡Qué bueno que vienen, "+r.nombre+"!";
      $("g-texto").textContent="Los esperamos: "+n+(n===1?" persona":" personas")+" ("+r.adultos+(r.adultos===1?" adulto":" adultos")+" y "+r.ninos+(r.ninos===1?" niño":" niños")+"). Nos vemos el 12 de diciembre a las 10:00.";
    }else{
      $("g-titulo").textContent="Gracias por avisarnos, "+r.nombre;
      $("g-texto").textContent="Lástima que no puedan venir. Si cambian de opinión, solo cambia tu respuesta aquí abajo.";
    }
  }
  $("editar").addEventListener("click",function(){
    var r=prev||{};
    $("nombre").value=r.nombre||"";
    if(r.asiste===true){$("si").checked=true}else if(r.asiste===false){$("no").checked=true}
    $("adultos").value=r.adultos!=null?r.adultos:1; $("ninos").value=r.ninos||0; $("mensaje").value=r.mensaje||"";
    sync(); $("gracias").hidden=true; $("rsvp").hidden=false; $("nombre").focus();
  });

  function err(t){var e=$("error"); e.textContent=t; e.hidden=!t;}

  $("rsvp").addEventListener("submit",function(ev){
    ev.preventDefault(); err("");
    var nombre=$("nombre").value.trim();
    var si=$("si").checked, no=$("no").checked;
    var ad=Math.max(0,parseInt($("adultos").value,10)||0), ni=Math.max(0,parseInt($("ninos").value,10)||0);
    if(nombre.length<2){err("Escribe el nombre de tu familia o el tuyo."); $("nombre").focus(); return;}
    if(!si&&!no){err("Dinos si podrán asistir o no."); return;}
    if(si&&ad+ni<1){err("Indica cuántas personas vienen (adultos o niños)."); return;}
    if(ad>20||ni>20){err("Ese número es muy alto. Si son más de 20, avísanos directamente."); return;}
    var body={p_nombre:nombre,p_asiste:si,p_adultos:si?ad:0,p_ninos:si?ni:0,p_mensaje:$("mensaje").value.trim()};
    var btn=$("enviar"); btn.disabled=true; btn.textContent="Enviando…";
    fetch(SB+"/rest/v1/rpc/cumple_enviar",{method:"POST",headers:{"apikey":KEY,"Authorization":"Bearer "+KEY,"Content-Type":"application/json"},body:JSON.stringify(body)})
      .then(function(r){return r.json().then(function(j){if(!r.ok)throw new Error(j.message||"error");return j;});})
      .then(function(){
        prev={nombre:nombre,asiste:si,adultos:body.p_adultos,ninos:body.p_ninos,mensaje:body.p_mensaje};
        try{localStorage.setItem("cumple-ez",JSON.stringify(prev))}catch(e){}
        mostrarGracias(prev); window.scrollTo({top:$("confirmar").offsetTop-10,behavior:"smooth"});
      })
      .catch(function(e){
        err(/limite/.test(e.message)?"Ya no estamos recibiendo más confirmaciones por aquí. Escríbenos directamente.":"No se pudo enviar. Revisa tu conexión e inténtalo otra vez.");
      })
      .then(function(){btn.disabled=false; btn.textContent="Enviar confirmación";});
  });
})();
