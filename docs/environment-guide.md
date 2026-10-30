# Guía de entorno: Docker, Supabase, app móvil y web

Guía práctica en español para levantar todo el sistema en tu máquina.
Versión en inglés: [`environment-guide.en.md`](environment-guide.en.md) · Chuleta
de comandos: [`../QUICKSTART.md`](../QUICKSTART.md). Resumen
rápido: **sí, puedes montar y usar todo en local gratis**. Solo pagas cuando
publicas en internet o cuando activas integraciones externas (WhatsApp
automático, push real, tienda de apps).

No hay servidor de aplicación: el stack Supabase (Docker) + la app Flutter son
todo. Las reglas de negocio viven en PostgreSQL (funciones SQL) y las Edge
Functions solo cubren usuarios admin y envíos.

---

## 1. Qué vas a montar

| Pieza | Qué es | Dónde corre |
|---|---|---|
| PostgreSQL 17 + RLS + RPCs | Base de datos, permisos y lógica de negocio | Docker |
| GoTrue | Login por usuario + PIN (JWT) | Docker |
| PostgREST | API REST y `rpc/*` | Docker |
| Storage | Fotos de evidencias y logo | Docker |
| Realtime | Notificaciones in-app en vivo | Docker |
| Edge Functions | `admin-users`, `push-dispatch`, `evidence-archive`, `whatsapp-dispatch` | Docker |
| Studio | Panel web de la base de datos | Docker, misma URL |
| Envoy | Puerta de entrada única (`:8000`) | Docker |
| App Flutter | Android + Web (mismo código) | Tu equipo / emulador / navegador |

Todo se orquesta con `docker compose`; las migraciones de `supabase/migrations`
se aplican solas.

---

## 2. Requisitos

### Hardware / sistema

- 4 GB de RAM libres (8 GB si usas emulador Android).
- ~8 GB de disco para imágenes, base de datos y builds.
- Linux, macOS o Windows con WSL2. En Arch/Manjaro:

```bash
sudo pacman -S --needed docker docker-compose git curl python3 unzip
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"   # cierra sesión y vuelve a entrar
```

> En Linux se usa **Docker Engine**, que es gratis. Docker Desktop también es
> gratis para uso personal y empresas pequeñas; en Linux no lo necesitas.

### Flutter y Android

- Flutter en canal **beta** (el `pubspec.yaml` pide `^3.14.0-95.1.beta`; CI fija
  `3.49.0-0.1.pre`, localmente funciona 3.50 beta).
- Android SDK + un emulador (o un teléfono con depuración USB) solo si quieres
  la app móvil. Para web no hace falta Android.

```bash
flutter channel beta
flutter upgrade
flutter doctor          # resuelve lo que marque en rojo (Android toolchain, etc.)
flutter emulators       # lista emuladores; flutter emulators --launch <id>
```

---

## 3. Puesta en marcha local (paso a paso)

### 3.1 Clonar y generar secretos

```bash
git clone <repo> parking_management
cd parking_management

cp .env.example .env
sh supabase/generate-env.sh
```

`generate-env.sh` rellena contraseñas y claves (Postgres, JWT, `ANON_KEY`,
`SERVICE_ROLE_KEY`, Storage, contraseña de Studio). Es seguro re-ejecutarlo: no
sobrescribe valores que ya parecen reales.

Guarda bien `.env` (no se versiona). Permisos:

```bash
chmod 600 .env
```

Datos que necesitarás leer de `.env`:

| Clave | Para qué |
|---|---|
| `ANON_KEY` | Compilar la app contra tu Supabase local |
| `SERVICE_ROLE_KEY` | Solo servidor/cron; **nunca** en la app |
| `DASHBOARD_PASSWORD` | Entrar a Studio (`usuario: supabase`) |
| `SUPABASE_PUBLIC_URL` | `http://localhost:8000` por defecto |

### 3.2 Levantar el stack

```bash
docker compose up -d
docker compose ps            # espera a que db/auth/rest/storage/realtime estén healthy
```

La primera vez descarga imágenes (varios minutos). Cuando la base y GoTrue están
listos, el contenedor de un solo uso `supabase-migrate` aplica el esquema:

```bash
docker compose logs --tail=20 supabase-migrate
# ... "migrations up to date"
```

Si añades migraciones nuevas más adelante:

```bash
docker compose up -d supabase-migrate && docker compose logs --tail=5 supabase-migrate
```

### 3.3 Crear tu usuario administrador

```bash
sh supabase/create-operator.sh admin 123456 admin
```

- El usuario se guarda como `admin@parking.local` en GoTrue; el PIN es la
  contraseña (mínimo 6 dígitos).
- Entra a la app con **usuario `admin` y PIN `123456`**.
- Cambia ese PIN antes de usar datos reales: desde `/users` o con
  `sh supabase/rotate-pin.sh admin <nuevo-pin>`.

### 3.4 Studio (opcional, para mirar la base de datos)

Abre <http://localhost:8000> y usa:

- usuario: `supabase`
- contraseña: la que generó `generate-env.sh` (`DASHBOARD_PASSWORD` en `.env`).

### 3.5 Correr la app web

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY de .env>
```

Nota: el `ANON_KEY` es público (va en el binario), no es un secreto; el
`SERVICE_ROLE_KEY` sí y nunca debe ir en la app.

### 3.6 Correr la app Android

**Emulador** (el host se ve como `10.0.2.2`, no `localhost`):

```bash
flutter emulators --launch <id-del-emulador>
flutter run -d emulator-5554 \
  --dart-define=SUPABASE_URL=http://10.0.2.2:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>
```

**Teléfono físico por adb** (USB o adb inalámbrico; recomendado):

```bash
adb devices                       # busca el serial, p. ej. 192.168.0.2:38333
adb reverse tcp:8000 tcp:8000     # el localhost:8000 del teléfono llega a este PC
flutter run -d <serial> \
  --dart-define=SUPABASE_URL=http://localhost:8000 \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>
```

Repite `adb reverse tcp:8000 tcp:8000` (o `sh tool/run-android.sh`) cuando el
adb inalámbrico se reconecte: el teléfono vuelve en otro puerto y el túnel se
pierde, lo que se ve como "no conecta con el servidor".

Si no puedes usar `adb reverse`, usa la misma red Wi-Fi:

1. `ip addr` (o `ipconfig`) para ver la IP de tu PC, por ejemplo `192.168.1.50`.
2. `flutter run -d <device> --dart-define=SUPABASE_URL=http://192.168.1.50:8000 --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>`.
3. Si no conecta, revisa el firewall de tu PC (puerto 8000).

Los builds **debug** permiten HTTP en claro (el `AndroidManifest` de debug lo
habilita). Los builds **release** exigen HTTPS.

### 3.7 Identidad visual

La app trae un logo por defecto (`assets/branding/logo.png`) que usa el login
hasta que un admin sube el logo de su sede (Ajustes → logo). Para regenerar los
iconos del launcher y de la web tras cambiar el diseño:

```bash
python3 tool/generate_branding.py   # requiere Pillow
```

### 3.8 Builds de producción

```bash
# Web estático (sirve cualquier hosting; recuerda HTTPS en producción)
flutter build web --release \
  --dart-define=SUPABASE_URL=https://tu-dominio.com \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY de producción>

# Android (requiere tu keystore, ver android/key.properties)
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://tu-dominio.com \
  --dart-define=SUPABASE_ANON_KEY=<ANON_KEY de producción>
```

---

## 4. Verificar que todo funciona

```bash
flutter test                 # 838 tests
flutter analyze              # solo infos de deprecación del SDK beta
sh supabase/healthcheck.sh   # servicios, endpoints y backlog (exit 1 si falla)
sh supabase/tests/e2e.sh     # login → entrada → cobro → reporte → historial
```

Prueba manual mínima: login → entrada de una placa → salida con cobro → ver el
recibo → `/reports` → `/audit` → `/diagnostics`.

Tests SQL/RLS contra una base temporal (opcional):

```bash
PW=$(grep -E '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
docker exec supabase-db psql -U supabase_admin -d postgres -c "drop database if exists sql_test;"
docker exec supabase-db psql -U supabase_admin -d postgres -c "create database sql_test owner supabase_admin;"
docker run --rm --network parking_management_default -v "$PWD/supabase:/work" \
  -e PGHOST=supabase-db -e PGUSER=supabase_admin -e PGPASSWORD="$PW" \
  -e PGDATABASE=sql_test postgres:17-alpine sh -c "cd /work && sh tests/run.sh"
docker exec supabase-db psql -U supabase_admin -d postgres -c "drop database if exists sql_test;"
```

---

## 5. Integraciones: qué es obligatorio y qué no

**Obligatorio: nada.** Sin ninguna integración la app funciona completa: login,
entrada/salida, cobros, turnos, reportes, mensualidades, reservas, auditoría.

| Integración | ¿Hace falta? | Gratis | Qué requiere |
|---|---|---|---|
| Notificaciones **in-app** (campana + bandeja) | No, ya funcionan | Sí | Nada: Realtime del stack local |
| Push **Android** (FCM, con la app cerrada) | No | Sí (plan gratuito) | Proyecto Firebase + credenciales + build con `FCM_ENABLED=true` |
| Push **navegador** (VAPID, con la pestaña cerrada) | No | Sí | Generar par VAPID y compilar con la clave pública; HTTPS o localhost |
| WhatsApp **manual** (`wa.me`) | No | Sí | Nada; abre WhatsApp en el teléfono del operador |
| WhatsApp **automático** (Meta Cloud API) | No | **No** | Cuenta Meta, token, número, plantillas aprobadas; cobro por mensaje |
| Impresión térmica Bluetooth | No | Sí | Impresora Bluetooth + permiso en Android |
| OCR de placas | No | Sí | Solo Android (ML Kit on-device) |

### “No quiero notificaciones todavía”

No configures nada de push. En concreto:

- No pongas `FCM_SERVICE_ACCOUNT_JSON` ni `VAPID_*` en `.env`.
- No compiles con `FCM_ENABLED=true` ni `WEB_PUSH_VAPID_PUBLIC_KEY`.
- `push-dispatch` y `whatsapp-dispatch` responden `{configured:false}` sin hacer
  nada; el cron puede seguir corriendo sin efectos.

La campana y la bandeja de `/notifications` siguen llegando por **Realtime**,
sin coste ni configuración. Los avisos de vencimiento de mensualidad, overstay y
cierre de turno se generan igual y se ven dentro de la app.

> Si más adelante quieres push, el camino más corto es Android/FCM (gratis).
> Para navegador necesitas HTTPS (o `localhost`) porque los service workers lo
> exigen; en una IP de LAN por HTTP no funcionará.

---

## 6. ¿Todo esto es gratis en local?

**Sí.** Localmente no pagas licencias ni servicios:

| Recurso | Coste local |
|---|---|
| Docker Engine + imágenes (Postgres, GoTrue, PostgREST, Storage, Realtime, Envoy, Studio) | $0 (open source) |
| Flutter + Android SDK | $0 |
| Base de datos, Storage, Functions | $0 (corren en tu equipo) |
| Push in-app | $0 |
| WhatsApp manual (`wa.me`) | $0 |

Solo gastas tu hardware, disco y tiempo. Los “costos” reales aparecen al
publicar:

### Costos aproximados de producción (USD, verifica precios actuales)

| Concepto | Rango | Notas |
|---|---|---|
| VM para el stack (2 vCPU / 4 GB / 40 GB) | **$5–20 / mes** | Hetzner/DigitalOcean/Vultr; el stack completo entra en 4 GB |
| Dominio | **$10–15 / año** | Necesario para HTTPS con Let's Encrypt |
| Copias de seguridad fuera del servidor | **$1–5 / mes** | Objeto/espacio extra o `rclone` a otro proveedor |
| Google Play (publicar Android) | **$25 único** | Opcional si instalas el APK/AAB por MDM |
| Firebase (FCM) | **$0** | Plan Spark sobra para notificaciones |
| VAPID (push web) | **$0** | Solo generas claves |
| WhatsApp Cloud API (automático) | **Variable** | Meta cobra por mensaje/plantilla según país y categoría; puede ser desde céntimos. Requiere cuenta business y plantillas aprobadas |
| Supabase Cloud (alternativa al VM) | **$0 plan free / ~$25+ / mes pro** | Este repo está pensado para self-hosted; en Cloud hay que adaptar migraciones/funciones |
| Hosting web estático (si no usas la VM) | **$0** en Netlify/Cloudflare Pages | Pero la API debe ser HTTPS |

Si solo quieres **una sede y uso interno**, el escenario mínimo realista es:
VM de $5–10/mes + dominio + backups = **~$10–15/mes** y $0 en integraciones si
no usas WhatsApp automático.

---

## 7. Problemas típicos

| Síntoma | Causa / solución |
|---|---|
| `Supabase is required` al arrancar la app | Faltan `--dart-define=SUPABASE_URL` / `SUPABASE_ANON_KEY`. |
| El emulador Android no conecta | Usa `10.0.2.2`, no `localhost`. |
| Teléfono físico no conecta | Misma red Wi-Fi, IP de tu PC, puerto 8000 abierto en el firewall. |
| `PGRST202` función no encontrada | Migración aplicada después de que PostgREST cacheó el esquema: espera unos segundos o `docker compose restart rest`. |
| `migrations up to date` pero falta una tabla | Ese archivo ya está registrado; crea una **migración nueva** en vez de editar una aplicada. |
| 401 tras cambiar `.env` | Recompila la app con el `ANON_KEY` actual. |
| Studio pide contraseña y no la sabes | Está en `.env` como `DASHBOARD_PASSWORD`. |
| Push web no aparece | Requiere HTTPS o `localhost`, y compilar con `WEB_PUSH_VAPID_PUBLIC_KEY`. |
| Todo roto tras experimentar | `docker compose down -v` borra datos locales; luego repite 3.1–3.3. |

---

## 8. Chuleta de comandos

```bash
# Stack
docker compose up -d                     # arrancar
docker compose ps                        # estado
docker compose logs -f rest auth         # logs
docker compose restart functions         # tras editar una Edge Function
docker compose up -d supabase-migrate    # aplicar migraciones nuevas
docker compose down                      # parar (conserva datos)
docker compose down -v                   # parar y BORRAR datos locales

# Datos
docker exec -it supabase-db psql -U supabase_admin -d parking
sh supabase/backup.sh
RESTORE_CONFIRM=yes sh supabase/restore.sh backups/<stamp>
sh supabase/restore-drill.sh             # probar que el backup restaura

# Usuarios
sh supabase/create-operator.sh <usuario> <pin> [admin|operator]
sh supabase/rotate-pin.sh <usuario> <nuevo-pin>

# App
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:8000 --dart-define=SUPABASE_ANON_KEY=<ANON>
flutter run -d emulator-5554 --dart-define=SUPABASE_URL=http://10.0.2.2:8000 --dart-define=SUPABASE_ANON_KEY=<ANON>

# Calidad y operación
flutter test
flutter analyze
sh supabase/healthcheck.sh
sh supabase/diagnostics.sh
sh supabase/tests/e2e.sh
sh supabase/check-secrets.sh
```

---

## 9. Cuándo pasar a la nube

Cuando necesites acceso fuera de tu red, varios operadores o respaldo serio:

1. Sigue [`setup-cloud.md`](setup-cloud.md): VM + Docker + Caddy/Nginx con TLS.
2. Configura backups y el drill mensual ([`runbook-restore.md`](runbook-restore.md)).
3. Revisa secretos y PINs ([`runbook-secrets.md`](runbook-secrets.md)).
4. Solo si quieres avisos automáticos, agrega FCM (gratis) y/o Meta WhatsApp
   (de pago por mensaje).

Para detalles técnicos: [`architecture.md`](architecture.md),
[`infrastructure.md`](infrastructure.md), [`database.md`](database.md).
