# alp-domain-watch

En Agentics-samlebåndslinje der holder øje med domæner, som er ved at blive frigivet.
Hver time kører stationen `Tjek domæner` et **kodetrin** (`trigger.run`), ikke en agent:
`kanariefugl watch eavfw.com eavfw.org --notify` laver ét RDAP-opslag pr. domæne.

| RDAP-svar | Handling |
|---|---|
| 404 fra registret | `agent-share send "… er ledigt — køb nu"`, hver time indtil planen slås fra |
| `pending delete` | intet — navnet er på vej ud, men ikke ledigt endnu |
| registreret inden for 65 min | `agent-share send "… blev taget"` |
| andet 200 | intet |
| 404 med *"No RDAP service"* | **fejl**, ikke en dom — se nedenfor |

## Hvorfor kommandoen henter et værktøj først

Stationens kommando er:

```sh
export PATH="$HOME/.local/bin:$PATH"
command -v kanariefugl >/dev/null 2>&1 ||
  curl -fsSL https://agentics.dk/install/pks-agent-domain.sh | NO_MODIFY_PATH=1 bash
kanariefugl watch eavfw.com eavfw.org --notify
```

Den lå tidligere i `.agentics/scripts/watch.sh`, ud fra en antagelse om at importen
tog linjens scripts med ind i jobbet. **Det gør den ikke.** Målt 25-11-2026:

- `codeStepPayload` på platformen (`task-dispatch.ts`) sender **kun** `command` og
  `timeoutMs` — ordet `files` findes ikke i dispatchen
- runnerens `CodeStepPayloadModel` har tilsvarende **kun** `Command` og `TimeoutMs`

Runneren *har* en `LineFilesToMaterialize`, der gør `.agentics/scripts/*`
eksekverbare (pks-cli ≥ 7.22), men intet fylder den fra et kodetrin. Et kodetrin
kører i **projektets** checkout, og er den tom — som `pksorensen/pksorensen` er —
findes scriptet ikke, og shellen svarer `exit 127`. Det skete fire gange i træk
23.-24/11 uden at noget andet fejlede.

Et værktøj hentet med husets installer afhænger ikke af projektrepoets indhold.
`export PATH` er nødvendig i *samme* trin som installationen: runneren kører
kommandoen som én `bash -lc`, og Debians `~/.profile` lægger kun `~/.local/bin`
på PATH hvis mappen fandtes da shellen startede.

## Krav

- En Agentics-runner på projektet, der annoncerer `code-step:v1`.
- `agent-share` på PATH — ellers henter CLI'en den med `npx @agentics-live/agent-share` (kræver node).
- Stationen koblet til ejerens Agent Share-indbakke (Operator-fanen → *Agent Share inbox → Connect*).
  Jobbet bruger sit eget kortlivede workload-token; der ligger ingen indbakketoken nogen steder.

Kør lokalt: `kanariefugl watch example.com` (uden `--notify` skriver den bare status).

## Domæner uden RDAP kan ikke overvåges

**`.dk` har ingen RDAP-tjeneste.** rdap.org svarer 404 med titlen *"No RDAP service
is available for this resource"*, og den gamle bash-udgave læste enhver 404 som
"ledigt" — den ville altså have bedt om at købe hvert dansk domæne man gav den,
hver time. `kanariefugl watch` skelner de to slags 404 og fejler ærligt på den
anden. Kun et registrys eget bare 404 betyder ledigt.
