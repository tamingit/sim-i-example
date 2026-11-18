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
| `localhost:2323` | Any TN5250 client. Try `CALL DEMOCUST/CUSTMNT`, `CALL DEMOLIB/HELLO`, or the CRM in `source/CRMDEMO` (see its README). |

## What's here

- `compose.yml`: PostgreSQL, Sim i, the proxy that puts the three web apps on one address, code-server and GreenGlow.
- `.env`: the settings: the developer and password, the image tags, who owns `source/` and the published ports.
- `source/`: the examples, a folder for each library (`DEMOLIB`, `DEMOCUST`, `CRMDEMO`). Sim i reads it at each
  start; code-server edits it.
- `Caddyfile`: the proxy's routes. code-server is reached only after Sim i says the request is `DEV`'s.
- `code-server/`: the code-server image, with the Sim i extension taken from the Sim i image.

## Before the first start

- Set `SIM_I_UID` and `SIM_I_GID` in `.env` to `id -u` and `id -g`: code-server writes files in `source/` as that
  user.
- Change the passwords in `.env` (`SIM_I_DEVELOPER_PASSWORD`, `GREENGLOW_BREAKGLASS_PASSWORD`) if anyone else can
  reach this machine. Everything is published on `127.0.0.1` unless `SIM_I_HOST` says otherwise.
- The ports above (and 449, 992, 4711, 5432, 8473 to 8476, 9473 to 9476) must be free.

## Notes

- `docker compose restart sim-i` reads `source/` again; members saved from code-server are compiled straight away.
- `docker compose down -v` deletes the database and everything else the volumes keep, to start clean.
- git works in code-server when `source/` is a repository of its own (`git init` in it, or clone into it). Set
  `SIM_I_GIT_NAME`, `SIM_I_GIT_EMAIL` and, for SSH remotes, `SIM_I_GIT_SSH_KEY` in `.env`.
- GreenGlow needs an image (`GREENGLOW_TAG`) that serves under `/terminal/` and signs on with IBM i users.
