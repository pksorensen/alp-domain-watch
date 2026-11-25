# alp-domain-watch

En Agentics-samlebåndslinje der holder øje med domæner vi **ejer**. Hver mandag
kl. 08:07 kører stationen `Tjek domæner` et **kodetrin** (`trigger.run`), ikke en agent:

```sh
kanariefugl guard eavfw.com eavfw.org eavfw.io --ns-suffix ns.cloudflare.com --notify
```

| Fund | Handling |
|---|---|
| domænet er ikke registreret længere | besked |
| registreringen udløber inden for 14 dage | besked |
| RDAP-status hold, redemption eller pending delete | besked |
| en navneserver uden for `ns.cloudflare.com` | besked |
| certifikatet på :443 er udløbet, udløber snart eller matcher ikke | besked |
| alt i orden | **intet** |

Alle fund samles i **én** besked pr. kørsel. Et RDAP-opslag der ikke kunne laves,
giver et Fejlet kort, ikke en besked.

**Hvorfor ugentligt.** eavfw.com og eavfw.org gik tabt i november 2026, fordi de
udløb uden at nogen så på datoen. En udløbsfrist er uger lang, så én kørsel om ugen
er nok. Nedetid og certifikater mellem kørslerne fanges løbende af pks-agent-ops'
probes på arvo (monitorerne `eavfw-io`, `eavfw-com`, `eavfw-org`), der pusher når
en side går ned.

**Før 0.2.0** ventede linjen hver time på at eavfw.com og eavfw.org blev ledige
(`kanariefugl watch`). Begge blev købt 24.-25/11-2026, og den rolle er slut.

## Hvorfor kommandoen henter et værktøj først

Stationens kommando er:

```sh
export PATH="$HOME/.local/bin:$PATH"
command -v kanariefugl >/dev/null 2>&1 ||
  curl -fsSL https://agentics.dk/install/pks-agent-domain.sh | NO_MODIFY_PATH=1 bash
kanariefugl guard eavfw.com eavfw.org eavfw.io --ns-suffix ns.cloudflare.com --notify
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

`command -v`-vagten sparer ikke en download pr. time, som man kunne tro.
**Hvert job får sin egen container** — målt 25-11-2026: fem containere på rad for
dette projekt (05:07, 06:08, 07:08, 08:07, 08:31 UTC), og kun den sidste havde
binæren. Vagten gælder altså inden for ét job, ikke på tværs. Det er den gode
retning at tage fejl i: **en ny udgivelse af CLI'en rammer jobbet af sig selv ved
næste tick**, uden at linjen skal genimporteres.

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
