# Progress — Vektra (app de diseño UI/UX nativa, Android + Godot)

## Visión

App nativa de diseño UI/UX estilo Figma, 100% Android, open source, sin anuncios ni pagos, offline. Motor: Godot (render 2D / Vulkan Mobile). Lógica de dominio inspirada en Penpot (MPL-2.0, solo lógica, no código web). Gestos propios.

## Stack

- Godot 4.7.2 (render 2D, Vulkan renderer Mobile)
- Repo: `github.com/apexmiguel9-hub/vektra` (público, MIT)
- Godot headless local: `/root/godot/godot`
- Core headless separado de la UI (para futuro exporter Kotlin/Compose)
- Export: PNG → SVG → MP4 (ffmpeg)
- Pruebas en 2 móviles reales: gama baja G80 (Vulkan 1.1) + gama media Dimensity/PowerVR (Vulkan 1.3)

## Nota entorno local (proot)

- `godot --headless --import` crashea (signal 11) bajo proot ARM64 → NO usar import localmente.
- Clases globales (`class_name`) no resuelven en modo `-s` → el core usa `preload` consts (funciona igual en CI).
- Verificación local: `godot --headless -s res://tests/run_tests.gd`
- CI (GitHub Actions) hace `--import` normal en runner x64 sin problema.

## Roadmap

### Fase 0 — Fundaciones (2–4 semanas)
- [x] Proyecto Godot, renderer Mobile ✅ (2026-09-18)
- [x] Estructura core/shell (core sin UI ni dependencias) ✅
- [x] Core de figuras: rect, elipse, línea (matrices, bounds, hit-testing) ✅ (40 tests)
- [x] Core de path (pluma): nodos/beziers, parser/serializador SVG path, hit-test ✅ (93 tests)
- [x] Sistema de comandos / undo (estilo Penpot changes-builder) ✅ (56 tests total)
- [x] Tests del core (portar specs de Penpot) ✅
- [x] Export Android configurado (`export_presets.cfg`, arm64-v8a, `io.vektra.app`) — falta exportar APK con editor+templates en máquina del dev
- [x] Banco de stress (`stress/` + `tests/stress_headless.gd`) → falta baseline FPS en ambos móviles
- [ ] Boolean ops → movidas a Fase 2 (módulo más duro, no requiere el core base para construirse)

### Fase 1 — Canvas y edición básica (4–6 semanas)
- [ ] Gestos propios: pan/zoom (pinch), selección tap/drag, marquee multi-selección
- [ ] Tools: selección, rect, elipse, línea
- [ ] Handles move/resize/rotate + constraints
- [ ] Panel de capas, z-order, duplicar/borrar
- [ ] Snap a grid + pixel snap
- [ ] Export PNG
- [ ] APK usable en ambos móviles

### Fase 2 — Vector y texto (6–8 semanas)
- [ ] Tool pluma + edición de nodos/beziers (interactiva sobre el core ya listo)
- [ ] Boolean ops (intersect/union/difference XOR — portar de Penpot geom/shapes)
- [ ] Texto (Godot TextServer: tipografía, alineación, wrap)
- [ ] Reglas/guías
- [ ] Auto-layout flex/grid (diferenciador)
- [ ] Export SVG

### Fase 3 — Animación y export MP4 (4–6 semanas)
- [ ] Timeline, keyframes, easing
- [ ] Render offscreen por frames → ffmpeg → MP4

### Fase 4 — Release open source + futuro
- [ ] Undo duro, atajos, tema oscuro, onboarding
- [ ] Exporter Kotlin/Compose
- [ ] Publicar en F-Droid + GitHub, donaciones opcionales
- [ ] Post-1.0: pinceles/shader drawing (estilo Pixelorama), plugins

## Etapa actual

**Fase 0 completa — próximos pasos concretos (Fase 1):**
- [x] Proyecto Godot base (Mobile renderer) ✅
- [x] Esqueleto `core/` + `tests/` + `shell/` + `stress/` ✅
- [x] Core figuras rect/elipse/línea (matriz, bounds, hit-test) + 40 tests ✅
- [x] CI GitHub Actions verde (import + tests) ✅
- [x] Sistema de comandos/undo (add/remove/move + redo/cap) ✅
- [x] Path de 4 nodos en el core (beziers, hit-test, SVG d parse/serialize, selrect) + 93 tests ✅
- [x] `export_presets.cfg` Android (arm64-v8a, `io.vektra.app`) ✅
- [x] `stress/` (escena 200+200 shapes, FPS overlay) + `tests/stress_headless.gd` (baseline CPU) ✅
- [ ] Baseline FPS real en los 2 móviles (export APK en máquina del dev e instalar)
- [ ] Boolean ops (ahora en Fase 2)

## Recursos

- Repo Penpot clonado: `/root/penpot` (lógica de dominio en `common/src/app/common/geom/` y `frontend/src/app/main/data/workspace/`)
- Godot headless local: `/root/godot/godot`
- Conclusión técnica validada en código: Vulkan min 1.0; features 1.1/1.2/1.3 se activan condicionalmente; PowerVR ya tiene workarounds en Godot
- Baseline stress CPU local: 2000 shapes → serializar 106 ms, 2000 hit-tests 24 ms, cargar 240 ms (en proot emulado, más lento que en móvil)