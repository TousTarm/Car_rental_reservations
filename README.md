# Půjčovna aut

Jednoduchá rezervační aplikace v Ruby on Rails 8 a MySQL. Zákazník si vybere termín a kategorii vozu a aplikace ohlídá, aby v žádném dni nebylo rezervováno víc aut, než kolik jich kategorie má.

## Zvolené téma

Půjčovna aut. Rezervuje se **kategorie vozu** (např. „Škoda Fabia“, 10 ks), ne konkrétní auto. `capacity` je počet aut v kategorii. Zákazníkovi je jedno, kterou Fabii dostane, a díky tomu má kapacita smysl. U konkrétního auta by byla vždy 1.

Průběh:
1. Na úvodní stránce zákazník zadá termín Od–Do a uvidí karty kategorií s cenou za den, celkovou cenou a počtem volných aut. Plné kategorie mají štítek „Sold out“ a nejdou vybrat.
2. Tlačítko „Book“ otevře formulář rezervace s předvyplněnou kategorií a termínem. Zákazník doplní jméno a e-mail.
3. Rezervaci jde upravit, včetně změny kategorie. Úprava prochází stejnou kontrolou.
4. Kategorie mají detail se seznamem rezervací a formulář pro přidání nové.

## Spuštění

Potřeba: Ruby 3.4 a MySQL 8.

**NixOS / Nix:** `nix-shell` připraví Ruby, MySQL a knihovny pro gem `mysql2`. Pokud MySQL neběží, spustí ho lokálně na `127.0.0.1:3306` s daty v `tmp/mysql` (uživatel `root` bez hesla). Vypnutí: `mysqladmin -h 127.0.0.1 -u root shutdown`.

**Jinde:** stačí vlastní Ruby 3.4 a běžící MySQL.

Připojení k databázi se nastavuje proměnnými prostředí:

| Proměnná      | Výchozí hodnota |
|---------------|-----------------|
| `DB_HOST`     | `127.0.0.1`     |
| `DB_USER`     | `root`          |
| `DB_PASSWORD` | prázdné         |

```sh
bundle install
bin/rails db:setup     # vytvoří databázi, načte schéma a seeds
bin/rails server       # http://localhost:3000
bin/rails test         # testy modelů a controllerů
```

`db:setup` po sobě vypíše konkrétní data scénářů, která se hodí na vyzkoušení (viz níže).

## DECISIONS

<!-- OWNER: přepsat vlastními slovy -->

**Modely.** `CarCategory` (`name`, `description`, `daily_price`, `capacity`) má mnoho `Reservation` (`customer_name`, `customer_email`, `start_date`, `end_date`). Zákazníka jsem jako samostatný model nevytvářel: bez přihlášení by to byla jen tabulka se jménem a e-mailem navíc.

**Celé dny.** `start_date` a `end_date` jsou typu `date` a auto je obsazené **včetně obou dnů** (vyzvednutí i vrácení). Rezervace 10.–12. tedy trvá 3 dny a stojí 3 × denní cena. Kdo vrací auto 12., blokuje ho i 12., takže nová rezervace může začít nejdřív 13. Je to jednodušší a srozumitelnější než hodiny, za cenu horšího využití aut.

**Cena** je v celých korunách (`integer`, ne `decimal`) a nikam se neukládá, počítá se metodou `CarCategory#price_for` / `Reservation#total_price`.

**Kde je logika.** Všechno je v modelech, controllery jen načtou parametry, zavolají `save`/`update` a vykreslí výsledek. Dostupnost počítá jediná metoda `CarCategory#free_units(start_date, end_date, exclude: nil)`. Volá ji validace rezervace i úvodní stránka, takže si nemůžou odporovat: co úvodní stránka nabídne jako volné, to jde i uložit. Ze stejného důvodu hledání na úvodní stránce kontroluje termín validacemi rezervace (ne v minulosti, konec po začátku, max. 30 dní).

**Validace rezervace.** Povinná pole, formát e-mailu, `end_date >= start_date`, `start_date` ne v minulosti (jen u nové rezervace nebo při změně začátku, aby šla upravit i rozjetá rezervace), nejvýš 30 dní a kapacita. Kontrola kapacity běží až nakonec a jen tehdy, když ostatní validace prošly, aby uživatel neviděl matoucí hlášku o dostupnosti u nesmyslného termínu.

**Editace.** Rezervace se nepočítá sama proti sobě (`exclude: id`). Při přesunu do jiné kategorie se kapacita kontroluje v té nové.

**Souběh.** Dva lidé mohou chtít poslední auto ve stejnou chvíli. Oba by napočítali jedno volné auto a oba by uložili. Validace proto nejdřív zamkne řádek kategorie (`car_category.lock!`, tedy `SELECT … FOR UPDATE`) a teprve potom počítá. Rails spouští validace uvnitř transakce metody `save`, takže zámek drží až do uložení a druhý zákazník počká, než první dokončí. V SQL logu je pořadí `BEGIN → SELECT … FOR UPDATE → počítání → INSERT → COMMIT` a hlídá ho i test. Navíc je v `database.yml` nastavená izolace `READ COMMITTED`: ve výchozím režimu MySQL (REPEATABLE READ) by počítání po zámku mohlo číst starší snímek dat a rezervaci, kterou druhý zákazník právě uložil, by nevidělo.

**Pojistky v databázi.** Sloupce mají `null: false`, rezervace mají cizí klíč na kategorii a název kategorie má unikátní index. Validace unikátnosti ignoruje velikost písmen stejně jako collation MySQL.

**Stack.** Rails 8.1 bez JavaScriptu (formuláře fungují čistě přes HTML), bez Dockeru, Kamalu, Solid\* a bez gemů navíc. CSS je vlastní, ve třech souborech (`base.css` s proměnnými, `layout.css`, `components.css`).

## Proč kontrola kapacity funguje

<!-- OWNER: přepsat vlastními slovy -->

Kapacita se překročí jen tehdy, když v nějakém konkrétním dni běží víc rezervací, než je aut. `free_units` proto pro každý den nové rezervace spočítá, kolik existujících rezervací ten den pokrývá, a vezme nejvytíženější den. Když je i v něm aspoň jedno auto volné, je volné po celou dobu. Nestačí spočítat rezervace, které se s novou překrývají: při kapacitě 2 se rezervace 1.–3., 4.–6. a 7.–10. všechny překrývají s 1.–10., ale nikdy neběží dvě najednou, takže se nová vejde.

## Jak to vyzkoušet

Seeds počítají data relativně k dnešku („+14“ = za 14 dní), takže jsou vždy v budoucnosti. Konkrétní data vypíše `bin/rails db:setup` (nebo `bin/rails db:seed`).

| Kategorie | Aut | Situace |
|---|---|---|
| Škoda Fabia | 10 | 9 rezervací se překrývá ve dnech +14 až +16 |
| Škoda Octavia Combi | 3 | plno ve dnech +10 až +12 |
| Škoda Superb | 2 | částečné překryvy, plno ve dnech +21 až +24 |
| Škoda Enyaq | 1 | jedna rezervace ve dnech +5 až +8 |
| Škoda Kamiq | 4 | úplně volná |

1. **Téměř plno:** na úvodní stránce zadej +14 až +16. Fabia ukáže „1 of 10 free“. Zarezervuj ji. Po návratu na stejný termín je Fabia „Sold out“ a jedenáctá rezervace přes formulář skončí chybou „No Skoda Fabia is free for the whole period“.
2. **Plno a těsně vedle:** +10 až +12 ukáže Octavii jako „Sold out“, +13 až +15 i +8 až +9 jako „3 of 3 free“. Návratový den je ještě obsazený, takže +12 až +13 je taky plno.
3. **Překryvy, které nejsou souběžné:** Superb má rezervace +20–22, +23–25, +26–29 a +21–24. Termín +25 až +29 se překrývá se dvěma z nich, a přesto je jedno auto volné. Termín +20 až +29 je plný kvůli dnům +21 až +24.
4. **Editace:** otevři libovolnou rezervaci a prodluž ji o den. Rezervace se nepočítá sama proti sobě. Přesun do plné kategorie se odmítne: vezmi rezervaci Fabie, která začíná +11, a změň kategorii na Octavii, která je ve dnech +11 a +12 plná.
5. **Validace:** termín v minulosti, konec před začátkem nebo víc než 30 dní hledání i formulář odmítnou.

## Co bychom udělali jinak s více časem

- **Konkrétní auta:** model `Car` v kategorii a přidělení konkrétního auta až při převzetí (SPZ, stav).
- **Úklidová doba** mezi vrácením a dalším pronájmem a **hodinové rezervace** místo celých dní, aby šlo auto vrácené ráno půjčit odpoledne.
- **Kilometry a poškození** při převzetí a vrácení.
- **Přihlášení** zákazníků a správců. Teď může kdokoli upravit kteroukoli rezervaci nebo přidat kategorii.
- **Platby** a storno rezervace (teď chybí i mazání).
- **Překlady UI** (i18n) a české formáty data a ceny ve formulářích.
- **Výkon:** úvodní stránka volá `free_units` pro každou kategorii zvlášť (jeden dotaz na kategorii). Při mnoha kategoriích by to šlo spojit do jednoho dotazu a přidat index `(car_category_id, start_date, end_date)`.
- **Test skutečného souběhu** ve dvou vláknech nebo spojeních. Teď je zámek ověřený jen tím, že se pošle `FOR UPDATE` před `INSERT`.
- **CI** na GitHubu, které spustí testy proti MySQL.

## Jak to vzniklo

Celé repo vzniklo s Claude Code pod vedením vlastníka. Commity jsou po jednotlivých souborech, takže historie ukazuje postup krok za krokem. U logiky vždy nejdřív vznikl test a teprve potom implementace.
