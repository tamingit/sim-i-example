# Sim i examples

Sim i (an IBM i simulator) with example source, a developer account, VS Code in the browser and a 5250 terminal in
the browser. This folder is all you need, besides Docker with the compose plugin: the images come from GitHub's
and Docker Hub's registries.

```bash
docker compose up --build
```

Then open <http://localhost:8080> and sign on as `DEV` / `ChangeMe!` (set in `.env`: change it there).

| Where | What |
|---|---|
| <http://localhost:8080/> | Sim i's launchpad: Code, Terminal, the source editor, Profiles and Receive from an IBM i, each opening in a tab of its own. For the `SIMADMIN` group's members, which `DEV` is in; anyone else who signs on is sent to the terminal. |
| <http://localhost:8080/code/> | code-server (VS Code) on `source/`, for `DEV` only. Saving a member compiles it on Sim i; the first save asks for `DEV`'s password. F5 on an RPG member debugs it. |
| <http://localhost:8080/terminal/> | GreenGlow Connect: 5250 sessions on Sim i, signing on with Sim i's users. |
| `localhost:2323` | Any TN5250 client. Try `CALL DEMOCUST/CUSTMNT`, `CALL DEMOLIB/HELLO`, or the CRM in `source/CRMDEMO` (see its README): sign on as `CRMUSR1`, `CRMUSR2` or `CRMUSR3` (password `Crm12345`) and you're in its menu. |

## What's here

- `compose.yml`: PostgreSQL, Sim i, the proxy that puts the three web apps on one address, code-server and GreenGlow.
- `.env`: the settings: the developer and password, the image tags, who owns `source/` and the published ports.
- `source/`: the examples, a folder for each library (`DEMOLIB`, `DEMOCUST`, `CRMDEMO`). Sim i reads it at each
  start; code-server edits it. `source/CRMDEMO/initial.json` sets the CRM up the first time Sim i reads it: its
  three users, each starting in the CRM's menu, and its build, which makes the tables, the sample data and the
  programs.
- `Caddyfile`: the proxy's routes. code-server is reached only after Sim i says the request is `DEV`'s.
- `code-server/`: the code-server image, with the Sim i extension taken from the Sim i image.

## Before the first start

- Set `SIM_I_UID` and `SIM_I_GID` in `.env` to `id -u` and `id -g`: code-server writes files in `source/` as that
  user.
- Change the passwords in `.env` (`SIM_I_DEVELOPER_PASSWORD`, `GREENGLOW_BREAKGLASS_PASSWORD`) if anyone else can
  reach this machine. Everything is published on `127.0.0.1` unless `SIM_I_HOST` says otherwise.
- The ports above (and 449, 992, 4711, 5432, 8473 to 8476, 9473 to 9476) must be free.

## HTTPS with a self-signed certificate (optional)

Plain HTTP is the default, and everything Sim i adds to code-server works over it. Over plain HTTP from another
computer, though, code-server's own web views stay blank (Markdown preview, and other extensions' pages): browsers
allow the service worker they need only on HTTPS or `localhost`. For those, or simply for HTTPS, the proxy can serve
it on a certificate of its own, signed by Caddy's local certificate authority, with no domain or Let's Encrypt.

1. In `.env`, with the address the browser uses (a host name, or an IP address) and the published port:

   ```bash
   SIM_I_HOST=0.0.0.0                        # reachable from other computers
   SIM_I_SITE=https://sim-i.lan:8080         # several: https://sim-i.lan:8080, https://192.168.1.50:8080
   SIM_I_CERTS=local_certs
   SIM_I_PUBLIC_URL=https://sim-i.lan:8080   # GreenGlow checks requests against it: the address people use
   # SIM_I_DEFAULT_SNI=192.168.1.50          # only when it's reached by an IP address
   ```

2. `docker compose up -d`. Caddy makes its authority the first time and keeps it in the `caddy-data` volume
   (`docker compose down -v` throws it away, and the next start makes a new one to trust again).
3. On each computer that uses the site, trust the authority. Download it from `https://sim-i.lan:8080/sim-i-ca.crt`
   (past the browser's warning, this once), or copy it from the proxy:
   `docker compose cp proxy:/data/caddy/pki/authorities/local/root.crt sim-i-ca.crt`. Then:
   - Windows: double-click it, Install Certificate, Local Machine, "Trusted Root Certification Authorities".
   - macOS: open it in Keychain Access (System keychain), and set Trust to Always Trust.
   - Linux: copy it to `/usr/local/share/ca-certificates/sim-i-ca.crt` and run `sudo update-ca-certificates`.
   - Firefox has trust of its own: Settings, Certificates, View Certificates, Authorities, Import.

   Restart the browser. Clicking past the warning isn't enough: browsers don't run service workers on a certificate
   they don't trust, so code-server's web views would stay blank.

The authority's root lasts ten years; the site's certificate is renewed by Caddy itself. Trust only an authority
you made: its key, in `caddy-data`, can sign a certificate for any site.

## Notes

- `docker compose restart sim-i` reads `source/` again; members saved from code-server are compiled straight away.
- `docker compose down -v` deletes the database and everything else the volumes keep, to start clean. The next start
  runs each library's `initial.json` again; until then it isn't run, even if it changes.
- git works in code-server when `source/` is a repository of its own (`git init` in it, or clone into it). Set
  `SIM_I_GIT_NAME`, `SIM_I_GIT_EMAIL` and, for SSH remotes, `SIM_I_GIT_SSH_KEY` in `.env`.
- GreenGlow needs an image (`GREENGLOW_TAG`) that serves under `/terminal/` and signs on with IBM i users.
