# alp-domain-watch

En Agentics-samlebåndslinje der holder øje med domæner, som er ved at blive frigivet.
Hver time kører stationen `Tjek domæner` et **kodetrin** (`trigger.run`), ikke en agent:
`.agentics/scripts/watch.sh eavfw.com eavfw.org` laver ét RDAP-opslag pr. domæne.

| RDAP-svar | Handling |
|---|---|
| 404 | `agent-share send "… er ledigt — køb nu"`, hver time indtil planen slås fra |
| `pending delete` | intet |
| registreret inden for 65 min | `agent-share send "… blev taget"` |
| andet 200 | intet |

## Krav

- En Agentics-runner på projektet, der annoncerer `code-step:v1`, med `agent-share` på PATH — ellers hentes den med `npx @agentics-live/agent-share` (kræver node).
- Stationen koblet til ejerens Agent Share-indbakke (Operator-fanen → *Agent Share inbox → Connect*).
  Jobbet bruger sit eget kortlivede workload-token; der ligger ingen indbakketoken nogen steder.

Kør lokalt: `.agentics/scripts/watch.sh example.com` (uden `agent-share` skriver den bare status).

Scriptet ligger under `.agentics/scripts/`, fordi et kodetrin kører i
*projektets* checkout, ikke dette repos: importen tager `.agentics/scripts/*`
med, og runneren (pks-cli ≥ 7.22) skriver dem ind i jobbet som eksekverbare.
