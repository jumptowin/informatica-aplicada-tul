// =====================================================================
// BiciTUL - aplicación web de la Etapa 2 (HTML + CSS + JavaScript)
// Se conecta a Supabase con la librería supabase-js. Cada pantalla es
// una función "pantallaX" que lee la base, arma el HTML y escucha formularios.
// =====================================================================
const cfg = window.APP_CONFIG || {};
const db = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
const $main = document.getElementById("contenido");

// ---------- utilidades ----------
const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const ahora = () => new Date().toISOString();
const fechaHora = (v) => v ? new Date(v).toLocaleString("es-AR", { timeZone: "America/Argentina/Buenos_Aires", dateStyle: "short", timeStyle: "short" }) : "—";
const fecha = (v) => v ? new Date(v + "T12:00:00").toLocaleDateString("es-AR") : "—";
const hoy = () => new Date().toLocaleDateString("en-CA", { timeZone: "America/Argentina/Buenos_Aires" });

function aviso(texto, esError = false) {
  const a = document.getElementById("aviso");
  a.textContent = texto; a.className = "aviso" + (esError ? " error" : ""); a.hidden = false;
  window.scrollTo({ top: 0, behavior: "smooth" });
  clearTimeout(aviso.t); aviso.t = setTimeout(() => (a.hidden = true), 7000);
}
// Ejecuta una consulta de Supabase y, si hay error, lo muestra y corta.
async function q(promesa) {
  const { data, error } = await promesa;
  if (error) throw new Error(traducirError(error));
  return data;
}
// Mensajes de la base traducidos a algo entendible
function traducirError(e) {
  const m = e.message || String(e);
  if (m.includes("supera su capacidad")) return "La estación de destino está completa (supera su capacidad máxima).";
  if (m.includes("un_viaje_abierto_por_bici")) return "Esa bicicleta ya tiene un viaje en curso.";
  if (m.includes("un_viaje_abierto_por_usuario")) return "Ese usuario ya tiene un viaje en curso.";
  if (m.includes("stock_actual")) return "No hay stock suficiente de ese repuesto.";
  if (m.includes("codigo_estacion_desde") || m.includes("redistribucion_check")) return "La estación de salida y la de llegada tienen que ser distintas.";
  if (m.includes("row-level security")) return "La base no permite esta operación (permisos RLS).";
  if (m.includes("duplicate key")) return "Ya existe un registro con ese código.";
  return "Error de la base: " + m;
}
const opciones = (lista, valor, texto, elegido) =>
  lista.map((x) => `<option value="${esc(x[valor])}" ${x[valor] == elegido ? "selected" : ""}>${esc(texto(x))}</option>`).join("");
const tabla = (cabeceras, filas) =>
  `<div class="tabla"><table><thead><tr>${cabeceras.map((c) => `<th>${c}</th>`).join("")}</tr></thead><tbody>${
    filas.length ? filas.join("") : `<tr><td colspan="${cabeceras.length}">No hay registros.</td></tr>`}</tbody></table></div>`;
// Cada pantalla registra con alMostrar lo que hay que hacer cuando su HTML ya está en la página
let pendiente = null;
const alMostrar = (fn) => (pendiente = fn);
const datosForm = (form) => Object.fromEntries(new FormData(form).entries());
function alEnviar(id, fn) {
  const f = document.getElementById(id);
  if (!f) return;
  f.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const b = f.querySelector("button[type=submit]"); if (b) b.disabled = true;
    try { await fn(datosForm(f), f); } catch (e) { aviso(e.message, true); } finally { if (b) b.disabled = false; }
  });
}
function alClick(selector, fn) {
  document.querySelectorAll(selector).forEach((b) => b.addEventListener("click", async () => {
    b.disabled = true;
    try { await fn(b.dataset); } catch (e) { aviso(e.message, true); } finally { b.disabled = false; }
  }));
}

// ---------- F5 Panel con indicadores ----------
async function pantallaPanel() {
  const [ind] = await q(db.from("v_indicadores").select("*"));
  const est = await q(db.from("v_disponibilidad_estacion").select("*").order("codigo"));
  const rep = await q(db.from("v_repuestos_a_reponer").select("*"));
  const man = await q(db.from("v_mantenimientos_pendientes").select("*"));
  const enCurso = await q(db.from("viaje").select("numero_serie", { count: "exact" }).is("fecha_hora_fin", null));
  const tarjeta = (v, n) => `<div class="ind"><div class="valor">${esc(v ?? "—")}</div><div class="nombre">${n}</div></div>`;
  return `<h1>Panel de la operación</h1>
  <p class="ayuda">Indicadores calculados en la base (vista v_indicadores). Se actualizan cada vez que se abre esta pantalla.</p>
  <div class="indicadores">
    ${tarjeta(ind.viajes_terminados, "Viajes terminados")}
    ${tarjeta(enCurso.length, "Viajes en curso")}
    ${tarjeta(ind.duracion_promedio_min != null ? Number(ind.duracion_promedio_min).toLocaleString("es-AR") + " min" : "—", "Duración promedio del viaje")}
    ${tarjeta(Number(ind.pct_flota_en_mantenimiento ?? 0).toLocaleString("es-AR") + " %", "Flota en mantenimiento")}
    ${tarjeta(ind.estaciones_con_alerta, "Estaciones con alerta")}
    ${tarjeta(ind.fallas_abiertas, "Fallas abiertas")}
  </div>
  <h2>Alertas de estaciones</h2>
  ${tabla(["Estación", "Disponibles", "Alerta"], est.filter((e) => e.alerta !== "OK").map((e) =>
    `<tr><td>${esc(e.codigo)} · ${esc(e.direccion)}</td><td class="num">${e.bicis_disponibles}</td><td><span class="alerta ${e.alerta}">${e.alerta}</span></td></tr>`))}
  <h2>Repuestos a reponer</h2>
  ${tabla(["Repuesto", "Stock", "Mínimo"], rep.map((r) =>
    `<tr><td>${esc(r.descripcion)}</td><td class="num">${r.stock_actual}</td><td class="num">${r.stock_minimo}</td></tr>`))}
  <h2>Mantenimientos pendientes</h2>
  ${tabla(["Fecha", "Tarea", "Operario"], man.map((m) =>
    `<tr><td>${fecha(m.fecha)}</td><td>${esc(m.descripcion)}${m.numero_serie ? " (" + esc(m.numero_serie) + ")" : ""}</td><td>${esc(m.operario)}</td></tr>`))}`;
}

// ---------- F1 Estaciones: disponibilidad y alertas ----------
async function pantallaEstaciones() {
  const est = await q(db.from("v_disponibilidad_estacion").select("*").order("codigo"));
  return `<h1>Estaciones</h1>
  <p class="ayuda">VACIA: hay menos bicis disponibles que el umbral mínimo. LLENA: las bicis asignadas superan el umbral máximo. Estas alertas indican dónde hace falta una redistribución.</p>
  ${tabla(["Código", "Dirección", "Disponibles", "Asignadas / capacidad", "Umbral mín. / máx.", "Alerta"], est.map((e) =>
    `<tr><td>${esc(e.codigo)}</td><td>${esc(e.direccion)}</td><td class="num">${e.bicis_disponibles}</td>
     <td class="num">${e.bicis_asignadas} / ${e.capacidad_max}</td><td class="num">${e.umbral_minimo} / ${e.umbral_maximo ?? "—"}</td>
     <td><span class="alerta ${e.alerta}">${e.alerta}</span></td></tr>`))}
  <p><a class="boton" href="#/redistribucion">Crear orden de redistribución</a></p>`;
}

// ---------- Bicicletas y estados ----------
async function pantallaBicicletas(params) {
  const filtro = params.get("estado") || "";
  let consulta = db.from("bicicleta").select("*").order("numero_serie");
  if (filtro) consulta = consulta.eq("estado", filtro);
  const bicis = await q(consulta);
  const est = await q(db.from("estacion").select("codigo,direccion").order("codigo"));
  const estados = ["DISPONIBLE", "EN_USO", "EN_MANTENIMIENTO", "EN_TRASLADO"];
  alMostrar(() => {
    document.getElementById("filtro").addEventListener("change", (e) => (location.hash = "#/bicicletas" + (e.target.value ? "?estado=" + e.target.value : "")));
    alEnviar("f-bici", async (d, f) => {
      await q(db.from("bicicleta").insert({ numero_serie: d.numero_serie.trim().toUpperCase(), codigo_estacion: d.codigo_estacion, estado: "DISPONIBLE", fecha_alta: hoy() }));
      aviso("Bicicleta " + d.numero_serie + " dada de alta."); router();
    });
  });
  return `<h1>Bicicletas</h1>
  <label for="filtro">Filtrar por estado</label>
  <select id="filtro"><option value="">Todas</option>${estados.map((e) => `<option ${e === filtro ? "selected" : ""}>${e}</option>`).join("")}</select>
  <p class="ayuda">${bicis.length} bicicleta(s).</p>
  ${tabla(["N.º de serie", "Estado", "Estación", "Alta"], bicis.map((b) =>
    `<tr><td>${esc(b.numero_serie)}</td><td><span class="estado">${b.estado}</span></td><td>${esc(b.codigo_estacion)}</td><td>${fecha(b.fecha_alta)}</td></tr>`))}
  <form id="f-bici"><h3>Alta de bicicleta (supervisor)</h3>
    <div class="fila"><div><label>N.º de serie</label><input name="numero_serie" required placeholder="BK-0010" maxlength="30"></div>
    <div><label>Estación</label><select name="codigo_estacion">${opciones(est, "codigo", (e) => e.codigo + " · " + e.direccion)}</select></div></div>
    <button type="submit">Dar de alta</button></form>`;
}

// ---------- Viajes: retiro y devolución ----------
async function pantallaViajes() {
  const usuarios = await q(db.from("usuario").select("*").order("nombre"));
  const tarjetas = await q(db.from("tarjeta").select("*"));
  const est = await q(db.from("v_disponibilidad_estacion").select("*").order("codigo"));
  const disp = await q(db.from("bicicleta").select("*").eq("estado", "DISPONIBLE").order("numero_serie"));
  const abiertos = await q(db.from("viaje").select("*").is("fecha_hora_fin", null).order("fecha_hora_inicio"));
  const ultimos = await q(db.from("viaje").select("*").not("fecha_hora_fin", "is", null).order("fecha_hora_inicio", { ascending: false }).limit(10));
  const operarios = await q(db.from("operario").select("*").order("legajo"));
  const nombre = (dni) => (usuarios.find((u) => u.dni === dni) || {}).nombre || dni;

  alMostrar(() => {
    const fu = document.getElementById("r-usuario"), ft = document.getElementById("r-tarjeta");
    const fe = document.getElementById("r-estacion"), fb = document.getElementById("r-bici");
    const llenarTarjetas = () => (ft.innerHTML = opciones(tarjetas.filter((t) => t.dni_usuario === fu.value), "id_tarjeta", (t) => `${t.marca} terminada en ${t.ultimos_4_digitos}`));
    const llenarBicis = () => {
      const l = disp.filter((b) => b.codigo_estacion === fe.value);
      fb.innerHTML = l.length ? opciones(l, "numero_serie", (b) => b.numero_serie) : `<option value="">No hay bicis disponibles</option>`;
    };
    fu.addEventListener("change", llenarTarjetas); fe.addEventListener("change", llenarBicis);
    llenarTarjetas(); llenarBicis();

    // RETIRO: la bici debe estar DISPONIBLE; se crea el viaje y la bici pasa a EN_USO
    alEnviar("f-retiro", async (d) => {
      if (!d.numero_serie) throw new Error("Elegí una bicicleta disponible.");
      if (!d.id_tarjeta) throw new Error("El usuario no tiene tarjeta cargada.");
      const inicio = ahora();
      await q(db.from("viaje").insert({ dni_usuario: d.dni_usuario, numero_serie: d.numero_serie, fecha_hora_inicio: inicio,
        codigo_estacion_origen: d.codigo_estacion, id_tarjeta: Number(d.id_tarjeta) }));
      await q(db.from("bicicleta").update({ estado: "EN_USO" }).eq("numero_serie", d.numero_serie));
      aviso(`Viaje iniciado: ${nombre(d.dni_usuario)} retiró ${d.numero_serie} en ${d.codigo_estacion}.`); router();
    });
    // DEVOLUCIÓN: la bici se mueve a la estación de destino (la base controla la capacidad),
    // se cierra el viaje y, si hay falla, se crea el reporte y un mantenimiento CORRECTIVO.
    alEnviar("f-devolucion", async (d) => {
      const v = abiertos.find((x) => x.numero_serie === d.numero_serie);
      if (!v) throw new Error("Elegí un viaje en curso.");
      const conFalla = d.falla && d.falla.trim();
      await q(db.from("bicicleta").update({ codigo_estacion: d.destino, estado: conFalla ? "EN_MANTENIMIENTO" : "DISPONIBLE" }).eq("numero_serie", v.numero_serie));
      try {
        await q(db.from("viaje").update({ fecha_hora_fin: ahora(), codigo_estacion_destino: d.destino })
          .eq("numero_serie", v.numero_serie).is("fecha_hora_fin", null));
      } catch (e) { // si no se pudo cerrar el viaje, devuelvo la bici a como estaba
        await db.from("bicicleta").update({ codigo_estacion: v.codigo_estacion_origen, estado: "EN_USO" }).eq("numero_serie", v.numero_serie);
        throw e;
      }
      if (conFalla) {
        await q(db.from("reporte_falla").insert({ dni_usuario: v.dni_usuario, numero_serie: v.numero_serie, fecha_hora_inicio: v.fecha_hora_inicio, descripcion: d.falla.trim() }));
        await q(db.from("mantenimiento").insert({ fecha: hoy(), descripcion: "Reparar falla reportada: " + d.falla.trim(), codigo_estacion: d.destino,
          legajo_operario: Number(d.legajo), tipo: "CORRECTIVO", estado: "PROGRAMADO", numero_serie: v.numero_serie }));
      }
      aviso(`Viaje cerrado: ${v.numero_serie} devuelta en ${d.destino}.` + (conFalla ? " Se registró la falla y se programó un mantenimiento correctivo." : "")); router();
    });
  });
  return `<h1>Viajes</h1>
  <form id="f-retiro"><h3>Retirar una bicicleta</h3>
    <div class="fila"><div><label>Usuario</label><select id="r-usuario" name="dni_usuario">${opciones(usuarios, "dni", (u) => `${u.nombre} (DNI ${u.dni})`)}</select></div>
    <div><label>Tarjeta para pagar</label><select id="r-tarjeta" name="id_tarjeta"></select></div></div>
    <div class="fila"><div><label>Estación de retiro</label><select id="r-estacion" name="codigo_estacion">${opciones(est, "codigo", (e) => `${e.codigo} · ${e.direccion} (${e.bicis_disponibles} disp.)`, [...est].sort((a, b) => b.bicis_disponibles - a.bicis_disponibles)[0]?.codigo)}</select></div>
    <div><label>Bicicleta</label><select id="r-bici" name="numero_serie"></select></div></div>
    <button type="submit">Iniciar viaje</button></form>

  <form id="f-devolucion"><h3>Devolver una bicicleta</h3>
    ${abiertos.length ? `
    <div class="fila"><div><label>Viaje en curso</label><select name="numero_serie">${opciones(abiertos, "numero_serie", (v) => `${v.numero_serie} · ${nombre(v.dni_usuario)} · desde ${v.codigo_estacion_origen}`)}</select></div>
    <div><label>Estación de devolución</label><select name="destino">${opciones(est, "codigo", (e) => `${e.codigo} · ${e.direccion} (${e.bicis_asignadas}/${e.capacidad_max})`)}</select></div></div>
    <label>¿La bici tiene alguna falla? (opcional)</label><textarea name="falla" placeholder="Ej.: el freno trasero no frena"></textarea>
    <label>Operario que atiende la falla (si hay)</label><select name="legajo">${opciones(operarios, "legajo", (o) => `${o.legajo} · ${o.nombre}`)}</select>
    <button type="submit">Terminar viaje</button>` : `<p>No hay viajes en curso.</p>`}</form>

  <h2>Viajes en curso</h2>
  ${tabla(["Bici", "Usuario", "Desde", "Inicio"], abiertos.map((v) => `<tr><td>${esc(v.numero_serie)}</td><td>${esc(nombre(v.dni_usuario))}</td><td>${esc(v.codigo_estacion_origen)}</td><td>${fechaHora(v.fecha_hora_inicio)}</td></tr>`))}
  <h2>Últimos viajes terminados</h2>
  ${tabla(["Bici", "Usuario", "Recorrido", "Inicio", "Fin"], ultimos.map((v) => `<tr><td>${esc(v.numero_serie)}</td><td>${esc(nombre(v.dni_usuario))}</td><td>${esc(v.codigo_estacion_origen)} → ${esc(v.codigo_estacion_destino)}</td><td>${fechaHora(v.fecha_hora_inicio)}</td><td>${fechaHora(v.fecha_hora_fin)}</td></tr>`))}`;
}

// ---------- F2 Redistribución de flota ----------
async function pantallaRedistribucion(params) {
  const est = await q(db.from("v_disponibilidad_estacion").select("*").order("codigo"));
  const operarios = await q(db.from("operario").select("*").order("legajo"));
  const disp = await q(db.from("bicicleta").select("*").eq("estado", "DISPONIBLE").order("numero_serie"));
  const ordenes = await q(db.from("redistribucion").select("*, redistribucion_bicicleta(numero_serie)").order("id_redistribucion", { ascending: false }));
  // sugerencia: desde la más LLENA (o con más disponibles) hacia una VACIA
  const llena = est.find((e) => e.alerta === "LLENA") || [...est].sort((a, b) => b.bicis_disponibles - a.bicis_disponibles)[0];
  const vacia = est.find((e) => e.alerta === "VACIA" && e.codigo !== llena?.codigo) || est.find((e) => e.codigo !== llena?.codigo);
  const desde = params.get("desde") || llena?.codigo;

  alMostrar(() => {
    document.getElementById("o-desde").addEventListener("change", (e) => (location.hash = "#/redistribucion?desde=" + e.target.value));
    alEnviar("f-orden", async (d, f) => {
      const bicis = [...f.querySelectorAll("input[name=bici]:checked")].map((x) => x.value);
      if (d.desde === d.hacia) throw new Error("La estación de salida y la de llegada tienen que ser distintas.");
      if (!bicis.length) throw new Error("Marcá al menos una bicicleta para trasladar.");
      const [orden] = await q(db.from("redistribucion").insert({ codigo_estacion_desde: d.desde, codigo_estacion_hacia: d.hacia, legajo_operario: Number(d.legajo), estado: "PENDIENTE" }).select());
      await q(db.from("redistribucion_bicicleta").insert(bicis.map((n) => ({ id_redistribucion: orden.id_redistribucion, numero_serie: n }))));
      aviso(`Orden N.º ${orden.id_redistribucion} creada con ${bicis.length} bici(s).`); location.hash = "#/redistribucion";
    });
    // Salida: las bicis pasan a EN_TRASLADO
    alClick("button[data-salir]", async ({ salir }) => {
      const o = ordenes.find((x) => x.id_redistribucion == salir);
      const series = o.redistribucion_bicicleta.map((b) => b.numero_serie);
      await q(db.from("bicicleta").update({ estado: "EN_TRASLADO" }).in("numero_serie", series));
      await q(db.from("redistribucion").update({ estado: "EN_CURSO", fecha_hora_salida: ahora() }).eq("id_redistribucion", o.id_redistribucion));
      aviso(`Orden ${o.id_redistribucion} en curso: ${series.length} bici(s) en traslado.`); router();
    });
    // Llegada: las bicis cambian de estación (la base controla la capacidad) y vuelven a DISPONIBLE
    alClick("button[data-llegar]", async ({ llegar }) => {
      const o = ordenes.find((x) => x.id_redistribucion == llegar);
      const movidas = [];
      for (const b of o.redistribucion_bicicleta) {
        const r = await db.from("bicicleta").update({ codigo_estacion: o.codigo_estacion_hacia, estado: "DISPONIBLE" }).eq("numero_serie", b.numero_serie);
        if (r.error) { // vuelvo atrás lo que ya moví
          for (const n of movidas) await db.from("bicicleta").update({ codigo_estacion: o.codigo_estacion_desde, estado: "EN_TRASLADO" }).eq("numero_serie", n);
          throw new Error(traducirError(r.error));
        }
        movidas.push(b.numero_serie);
      }
      await q(db.from("redistribucion").update({ estado: "COMPLETADA", fecha_hora_llegada: ahora() }).eq("id_redistribucion", o.id_redistribucion));
      aviso(`Orden ${o.id_redistribucion} completada: ${movidas.length} bici(s) llegaron a ${o.codigo_estacion_hacia}.`); router();
    });
  });
  const lista = disp.filter((b) => b.codigo_estacion === desde);
  const ocupadas = new Set(ordenes.filter((o) => o.estado !== "COMPLETADA").flatMap((o) => o.redistribucion_bicicleta.map((b) => b.numero_serie)));
  return `<h1>Redistribución de flota</h1>
  <p class="ayuda">Estado de las estaciones: ${est.map((e) => `${e.codigo} <span class="alerta ${e.alerta}">${e.alerta}</span>`).join(" · ")}</p>
  <form id="f-orden"><h3>Nueva orden de traslado</h3>
    <div class="fila"><div><label>Desde</label><select id="o-desde" name="desde">${opciones(est, "codigo", (e) => `${e.codigo} · ${e.direccion} (${e.bicis_disponibles} disp., ${e.alerta})`, desde)}</select></div>
    <div><label>Hacia</label><select name="hacia">${opciones(est, "codigo", (e) => `${e.codigo} · ${e.direccion} (${e.bicis_asignadas}/${e.capacidad_max}, ${e.alerta})`, vacia?.codigo)}</select></div></div>
    <label>Operario</label><select name="legajo">${opciones(operarios, "legajo", (o) => `${o.legajo} · ${o.nombre}`)}</select>
    <label>Bicicletas a trasladar (disponibles en ${esc(desde)})</label>
    <div class="checks">${lista.length ? lista.map((b) => `<label><input type="checkbox" name="bici" value="${esc(b.numero_serie)}" ${ocupadas.has(b.numero_serie) ? "disabled" : ""}> ${esc(b.numero_serie)}${ocupadas.has(b.numero_serie) ? " (ya está en otra orden)" : ""}</label>`).join("") : "<p>No hay bicis disponibles en esa estación.</p>"}</div>
    <button type="submit">Crear orden</button></form>
  <h2>Órdenes</h2>
  ${tabla(["N.º", "Recorrido", "Operario", "Bicis", "Estado", "Acción"], ordenes.map((o) =>
    `<tr><td>${o.id_redistribucion}</td><td>${esc(o.codigo_estacion_desde)} → ${esc(o.codigo_estacion_hacia)}</td><td>${o.legajo_operario}</td>
     <td>${o.redistribucion_bicicleta.map((b) => esc(b.numero_serie)).join(", ")}</td><td><span class="estado">${o.estado}</span><br><small>${o.fecha_hora_salida ? "Salió " + fechaHora(o.fecha_hora_salida) : ""}${o.fecha_hora_llegada ? "<br>Llegó " + fechaHora(o.fecha_hora_llegada) : ""}</small></td>
     <td>${o.estado === "PENDIENTE" ? `<button class="chico" data-salir="${o.id_redistribucion}">Registrar salida</button>` : o.estado === "EN_CURSO" ? `<button class="chico" data-llegar="${o.id_redistribucion}">Registrar llegada</button>` : "—"}</td></tr>`))}`;
}

// ---------- F3 Mantenimiento y reportes de falla ----------
async function pantallaMantenimiento() {
  const pend = await q(db.from("v_mantenimientos_pendientes").select("*"));
  const hechos = await q(db.from("mantenimiento").select("*").eq("estado", "REALIZADO").order("fecha", { ascending: false }).limit(10));
  const fallas = await q(db.from("reporte_falla").select("*").order("fecha_hora", { ascending: false }));
  const est = await q(db.from("estacion").select("codigo,direccion").order("codigo"));
  const operarios = await q(db.from("operario").select("*").order("legajo"));
  const bicis = await q(db.from("bicicleta").select("numero_serie,estado,codigo_estacion").order("numero_serie"));

  alMostrar(() => {
    alEnviar("f-mant", async (d) => {
      const fila = { fecha: d.fecha, descripcion: d.descripcion, codigo_estacion: d.codigo_estacion, legajo_operario: Number(d.legajo), tipo: d.tipo, estado: "PROGRAMADO", numero_serie: d.numero_serie || null };
      await q(db.from("mantenimiento").insert(fila));
      // un correctivo sobre una bici disponible la saca de servicio
      if (fila.numero_serie && fila.tipo === "CORRECTIVO")
        await q(db.from("bicicleta").update({ estado: "EN_MANTENIMIENTO" }).eq("numero_serie", fila.numero_serie).eq("estado", "DISPONIBLE"));
      aviso("Mantenimiento programado."); router();
    });
    // Realizado: la bici vuelve a DISPONIBLE y sus reportes abiertos pasan a RESUELTO
    alClick("button[data-hecho]", async ({ hecho, bici }) => {
      await q(db.from("mantenimiento").update({ estado: "REALIZADO" }).eq("id_mantenimiento", Number(hecho)));
      if (bici) {
        await q(db.from("bicicleta").update({ estado: "DISPONIBLE" }).eq("numero_serie", bici).eq("estado", "EN_MANTENIMIENTO"));
        await q(db.from("reporte_falla").update({ estado: "RESUELTO" }).eq("numero_serie", bici).eq("estado", "ABIERTO"));
      }
      aviso("Mantenimiento marcado como realizado" + (bici ? `; ${bici} vuelve a estar disponible.` : ".")); router();
    });
  });
  return `<h1>Mantenimiento y reportes de falla</h1>
  <h2>Tareas pendientes</h2>
  ${tabla(["Fecha", "Tipo", "Tarea", "Bici", "Estación", "Operario", ""], pend.map((m) =>
    `<tr><td>${fecha(m.fecha)}</td><td>${m.tipo}</td><td>${esc(m.descripcion)}</td><td>${esc(m.numero_serie || "—")}</td><td>${esc(m.codigo_estacion)}</td><td>${esc(m.operario)}</td>
     <td><button class="chico" data-hecho="${m.id_mantenimiento}" data-bici="${esc(m.numero_serie || "")}">Marcar realizado</button></td></tr>`))}
  <form id="f-mant"><h3>Programar mantenimiento</h3>
    <div class="fila"><div><label>Fecha</label><input type="date" name="fecha" required value="${hoy()}"></div>
    <div><label>Tipo</label><select name="tipo"><option>PREVENTIVO</option><option>CORRECTIVO</option></select></div></div>
    <label>Descripción</label><input name="descripcion" required placeholder="Ej.: revisión de frenos y cadena">
    <div class="fila"><div><label>Estación</label><select name="codigo_estacion">${opciones(est, "codigo", (e) => e.codigo + " · " + e.direccion)}</select></div>
    <div><label>Operario</label><select name="legajo">${opciones(operarios, "legajo", (o) => `${o.legajo} · ${o.nombre}`)}</select></div></div>
    <label>Bicicleta (opcional; vacío = tarea de la estación)</label><select name="numero_serie"><option value="">—</option>${opciones(bicis, "numero_serie", (b) => `${b.numero_serie} (${b.estado}, ${b.codigo_estacion})`)}</select>
    <button type="submit">Programar</button></form>
  <h2>Reportes de falla</h2>
  <p class="ayuda">Los reportes los carga el usuario al devolver la bici (pantalla Viajes).</p>
  ${tabla(["Fecha", "Bici", "Usuario", "Descripción", "Estado"], fallas.map((r) =>
    `<tr><td>${fechaHora(r.fecha_hora)}</td><td>${esc(r.numero_serie)}</td><td>${esc(r.dni_usuario)}</td><td>${esc(r.descripcion)}</td><td><span class="estado">${r.estado}</span></td></tr>`))}
  <h2>Últimos realizados</h2>
  ${tabla(["Fecha", "Tipo", "Tarea", "Bici"], hechos.map((m) => `<tr><td>${fecha(m.fecha)}</td><td>${m.tipo}</td><td>${esc(m.descripcion)}</td><td>${esc(m.numero_serie || "—")}</td></tr>`))}`;
}

// ---------- F4 Repuestos ----------
async function pantallaRepuestos() {
  const rep = await q(db.from("repuesto").select("*").order("codigo_repuesto"));
  const mants = await q(db.from("mantenimiento").select("id_mantenimiento,fecha,descripcion,numero_serie,estado").order("id_mantenimiento", { ascending: false }));
  const consumos = await q(db.from("consumo_repuesto").select("*, repuesto(descripcion), mantenimiento(fecha,descripcion)").order("id_mantenimiento", { ascending: false }));

  alMostrar(() => {
    // El descuento de stock lo hace la base (trigger trg_descontar_stock)
    alEnviar("f-consumo", async (d) => {
      await q(db.from("consumo_repuesto").insert({ id_mantenimiento: Number(d.id_mantenimiento), codigo_repuesto: d.codigo_repuesto, cantidad: Number(d.cantidad) }));
      aviso("Consumo registrado; el stock se descontó automáticamente."); router();
    });
    alEnviar("f-ingreso", async (d) => {
      const r = rep.find((x) => x.codigo_repuesto === d.codigo_repuesto);
      await q(db.from("repuesto").update({ stock_actual: r.stock_actual + Number(d.cantidad) }).eq("codigo_repuesto", r.codigo_repuesto));
      aviso(`Ingresaron ${d.cantidad} unidad(es) de ${r.descripcion}.`); router();
    });
    alEnviar("f-repuesto", async (d) => {
      await q(db.from("repuesto").insert({ codigo_repuesto: d.codigo.trim().toUpperCase(), descripcion: d.descripcion, stock_actual: Number(d.stock), stock_minimo: Number(d.minimo) }));
      aviso("Repuesto dado de alta."); router();
    });
  });
  return `<h1>Repuestos</h1>
  ${tabla(["Código", "Descripción", "Stock", "Mínimo", "Situación"], rep.map((r) =>
    `<tr><td>${esc(r.codigo_repuesto)}</td><td>${esc(r.descripcion)}</td><td class="num">${r.stock_actual}</td><td class="num">${r.stock_minimo}</td>
     <td>${r.stock_actual <= r.stock_minimo ? '<span class="alerta REPONER">REPONER</span>' : '<span class="alerta OK">OK</span>'}</td></tr>`))}
  <form id="f-consumo"><h3>Registrar repuestos usados (operario)</h3>
    <label>Mantenimiento</label><select name="id_mantenimiento">${opciones(mants, "id_mantenimiento", (m) => `N.º ${m.id_mantenimiento} · ${fecha(m.fecha)} · ${m.descripcion}${m.numero_serie ? " (" + m.numero_serie + ")" : ""}`)}</select>
    <div class="fila"><div><label>Repuesto</label><select name="codigo_repuesto">${opciones(rep, "codigo_repuesto", (r) => `${r.descripcion} (stock ${r.stock_actual})`)}</select></div>
    <div><label>Cantidad</label><input type="number" name="cantidad" min="1" value="1" required></div></div>
    <button type="submit">Registrar consumo</button></form>
  <form id="f-ingreso"><h3>Ingreso de stock (compra)</h3>
    <div class="fila"><div><label>Repuesto</label><select name="codigo_repuesto">${opciones(rep, "codigo_repuesto", (r) => r.descripcion)}</select></div>
    <div><label>Cantidad</label><input type="number" name="cantidad" min="1" value="5" required></div></div>
    <button type="submit">Sumar al stock</button></form>
  <form id="f-repuesto"><h3>Alta de repuesto (supervisor)</h3>
    <div class="fila"><div><label>Código</label><input name="codigo" required placeholder="R-CADENA" maxlength="20"></div><div><label>Descripción</label><input name="descripcion" required></div></div>
    <div class="fila"><div><label>Stock inicial</label><input type="number" name="stock" min="0" value="0" required></div><div><label>Stock mínimo</label><input type="number" name="minimo" min="0" value="2" required></div></div>
    <button type="submit">Dar de alta</button></form>
  <h2>Consumos registrados</h2>
  ${tabla(["Mantenimiento", "Repuesto", "Cantidad"], consumos.map((c) => `<tr><td>N.º ${c.id_mantenimiento} · ${esc(c.mantenimiento?.descripcion)}</td><td>${esc(c.repuesto?.descripcion)}</td><td class="num">${c.cantidad}</td></tr>`))}`;
}

// ---------- Navegación (rutas con #) ----------
const rutas = { panel: pantallaPanel, estaciones: pantallaEstaciones, bicicletas: pantallaBicicletas, viajes: pantallaViajes,
  redistribucion: pantallaRedistribucion, mantenimiento: pantallaMantenimiento, repuestos: pantallaRepuestos };

async function router() {
  const [ruta, query] = (location.hash.replace(/^#\/?/, "") || "panel").split("?");
  const fn = rutas[ruta] || pantallaPanel;
  document.querySelectorAll("nav a").forEach((a) => a.classList.toggle("activo", a.getAttribute("href") === "#/" + (rutas[ruta] ? ruta : "panel")));
  document.getElementById("menu").classList.remove("abierto");
  if (!cfg.SUPABASE_URL || cfg.SUPABASE_URL.includes("TU-PROYECTO")) {
    $main.innerHTML = `<h1>Falta configurar la conexión</h1><p>Completá config.js con la URL y la clave anon de Supabase (ver README).</p>`; return;
  }
  $main.innerHTML = "<p>Cargando…</p>";
  try {
    pendiente = null;
    $main.innerHTML = await fn(new URLSearchParams(query || ""));
    if (pendiente) pendiente();
  }
  catch (e) { $main.innerHTML = `<h1>No se pudo cargar</h1><p>${esc(e.message)}</p>`; }
}
document.getElementById("btn-menu").addEventListener("click", () => document.getElementById("menu").classList.toggle("abierto"));
window.addEventListener("hashchange", router);
router();
