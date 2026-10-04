# HANDOFF — LIBERTADORES: BLOOD OF INDEPENDENCE

Resumen para continuar el trabajo en una sesión/agente nuevo. Repo: `dantopa/libertadores` (rama `main`).
El usuario habla español rioplatense (argentino, vive en Medellín); responderle con ese tono, directo y con humor.
Es ingeniero de software (arquitectura frontend). Apunta a calidad "tipo Mortal Kombat 3" (realista: indie vendible, no AAA).

## 1. Qué es el proyecto
Juego de pelea 2D en el navegador (Phaser 3.80 + TypeScript + Vite + Vitest). 20 libertadores latinoamericanos con
4 especiales, remate (fatality sin gore) y remate secundario cada uno. Modos: Torneo (20 → 4 preliminares + 12 byes =
16 → octavos → cuartos → semis → final), Combate rápido, Versus local. IA con perfiles por personaje, 4 dificultades.
`npm install && npm run dev` (http://localhost:5173) · `npm run build` · `npm run test` (34 tests, todos verdes).
`?canvas` en la URL fuerza el renderer Canvas 2D (en este entorno sin GPU WebGL por software va a ~5 FPS; Canvas ~49).

## 2. Arquitectura (README.md tiene el detalle)
- `src/combat/` motor puro sin Phaser (sim.ts: 60 fps fijos, frame data, combos, bloqueo, medidor, rondas, fatality).
- `src/characters/` datos de los 20 (builders.ts + roster1/2.ts). Balance verificado por round-robin de IA (test).
- `src/ai/`, `src/data/` (tournament, stages), `src/scenes/`, `src/ui/`, `src/fatality/` (24 FX cinemáticos), `src/audio/`
  (todo sintetizado), `src/systems/` (input, storage, efectos).
- Render de luchadores (`src/ui/fighterVisual.ts`): 3 niveles con fallback automático:
  1) **animación cuadro por cuadro** si existe `public/assets/fighters/<id>/anims.json` (+ frames webp) → `frameAnim.ts`,
  2) **muñeco de papel** (piernas/torso/cabeza con bisagras, `puppetRig.ts`) si solo hay `idle.png`,
  3) render procedural (`fighterRenderer.ts`).
- Efectos 2.5D (`src/ui/depth25d.ts`, desactivables en Opciones): profundidad de campo, luces, contraluz, sombras, primer plano.
- Los 20 personajes tienen `idle.png` pintado (generados con SDXL-Turbo local, calidad media: caras genéricas, armas a veces mal).
  Retratos pintados de selección en `public/assets/portraits/` (vienen del mockup del usuario).

## 3. FOCO ACTUAL: llevar a San Martín a nivel MK3 (después replicar a los otros 19)
Flujo que funciona: el usuario genera **tiras de animación** en ChatGPT (una fila horizontal de cuadros, fondo verde #00FF00,
mirando a la derecha, mismo estilo pixel-art), y comparte el link (`https://chatgpt.com/s/m_...`). Yo bajo la imagen con
`scripts/tools/fetch_chatgpt_share.sh <url> <out.png>` (extrae la imagen PNG más grande de la página compartida; no requiere sesión).

Estilo **definitivo** (el que mandó el usuario con la tira de bloqueo): pixel-art definido, casaca azul marino con bordado
dorado y charreteras, capa celeste y blanca, faja celeste, pantalón blanco, botas negras, sable corvo en la mano derecha.
Las animaciones viejas de `public/assets/fighters/sanmartin/anims/` (de una hoja anterior, estilo "pintado" con capa roja)
**hay que reemplazarlas** cuando estén todas las tiras nuevas (mezclar estilos = San Martín cambia de ropa).

Tiras ya recibidas, en `scripts/art/gpt/source/sanmartin_strips/` (8 de 19): idle(6), walk_fwd(6), walk_back(6), crouch(3),
jump(4), block(4), light=estocada(4), heavy=sablazo(6). **Faltan** (prioridad): hit_high (3, golpe recibido), knockdown (5, caída),
win (5, victoria); luego crouch_light (4, barrida), crouch_heavy (5, corte ascendente), air_attack (3), crouch_block (2),
getup (3), special_cast (5, Sable Corvo con energía celeste), rush (4, Carga de Granaderos), throw (4, solo San Martín sin rival),
turn (3). El prompt maestro y la lista completa de pedidos a ChatGPT están en la conversación original; resumen en
`docs/ART_PIPELINE.md`. Reglas de cada tira: una fila, cuadros parejos, misma escala, pies en la misma línea, mira a la derecha,
solo el personaje (sin texto ni rival), fondo verde liso, sin efectos salvo en especiales.

### Procesador de tiras: `scripts/art/gpt/strips.py`
`python3 scripts/art/gpt/strips.py sanmartin scripts/art/gpt/source/sanmartin_strips` →
quita el verde (chroma key con despill; ojo: usar int32, con int16 se rompía y dejaba agujeros), corta cada tira en la
cantidad de cuadros pedida (`COUNTS`), devuelve a cada cuadro su punta de sable/capa vecina, escala desde la altura del idle,
ancla por los pies y escribe `anims.json` + `anims/<clip>/NN.webp` + `idle.png`. Luego `npm run art:manifest` y `npm run build`.
Los nombres de archivo = nombres de clips del juego (idle, walk_fwd, walk_back, crouch, crouch_block, jump, block, light, heavy,
crouch_light, crouch_heavy, air_attack, hit_high, knockdown, getup, special_cast, rush, throw, turn, win, dazed, dead, counter).
Tiempos y fases (startup/active/recovery) por clip están en `CLIPS` de strips.py; los cuadros "active" no deben superar los ticks
activos del golpe en el motor (light 3, heavy 4, crouch light 3, crouch heavy 4). Faltan clips opcionales → fallback (puppet).
Verificado en pantalla con Playwright (ver abajo) antes de dar por buena cada tanda.

Cómo probar visualmente: `npm run build && npx vite preview --port 4175` y un script Playwright (playwright-core, Chromium en
`/opt/pw-browsers/chromium-1194/chrome-linux/chrome`, args `--no-sandbox`) que abre `http://localhost:4175/?canvas`, arranca
`window.__game.scene.start('Fight', {cfg:{...}})` y avanza la simulación con `scene.sim.step([...])` + `scene.render()`.

## 4. Pendientes / ideas (en orden)
1. Recibir las tiras que faltan, correr `strips.py`, reemplazar las viejas, probar en pelea, commitear.
2. Facing: ya se corrigió que el luchador se re-orienta al terminar ataque/recibir golpe/aterrizar y hay animación de giro.
   Varios sprites `idle.png` de los otros 19 salieron de frente/ambiguos (guerrero, louverture, katari, morelos, artigas…).
3. Replicar el pipeline (hoja de personaje → tiras verdes → strips.py) con los otros 19, empezando por los más importantes.
4. Poses extra sin gore para fatality; hoy el fatality de San Martín usa los FX procedurales.
5. Audio nunca fue escuchado por una persona: balance de volúmenes sin afinar.
6. Rendimiento en móvil (muchos frames cargados al inicio; evaluar atlas/lazy-load por pelea).
7. Canal automático ChatGPT→Claude: se intentó con Slack (#libertadores-battle); el conector estuvo con permisos limitados
   en la sesión anterior. Si en la sesión nueva aparecen `slack_read_channel`/`slack_send_message`, probar leer ese canal.

## 5. Notas operativas
- No hay GPU. Generación local de imágenes (SDXL-Turbo, ControlNet-OpenPose, IP-Adapter) quedó como respaldo en
  `scripts/art/` (generate.py, rescue.py, install.py, anim/*) pero la calidad no alcanza: la calidad real viene de ChatGPT.
- El usuario no quiere gore anatómico gratuito en los remates (brief original), y no copiar IP de Mortal Kombat
  (por eso los emblemas son soles de rayos propios, no dragones).
- No crear PRs salvo pedido explícito. Commits con las líneas de atribución que indique la sesión.
- El repo viejo `dantopa/curso` ya no contiene el juego (era un proyecto PHP ajeno).
