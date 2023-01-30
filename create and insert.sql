CREATE DATABASE UkrainscyUczniowie;
USE UkrainscyUczniowie;

DELETE FROM uczniowie_z_ukrainy
WHERE idTerytWojewodztwo = 'idTerytWojewodztwo'; -- usuwa rekord z nag³ówkami kolumn

CREATE TABLE wojewodztwa (
	id_wojewodztwa INT PRIMARY KEY NOT NULL
,	wojewodztwa VARCHAR(50) NOT NULL
);

CREATE TABLE powiaty (
	id_powiatu INT PRIMARY KEY NOT NULL
,	powiat VARCHAR(100) NOT NULL
,	wojewodztwo INT NOT NULL
)

CREATE TABLE klasy (
	id_klasy INT PRIMARY KEY NOT NULL
,	klasa VARCHAR(200) NOT NULL
);

CREATE TABLE publicznosc (
	id_publicznosci INT PRIMARY KEY NOT NULL
,	typ_publicznosci VARCHAR(200) NOT NULL
);

CREATE TABLE typy_podmiotu (
	id_typ_podmiotu INT PRIMARY KEY NOT NULL
,	nazwa_typu_podmiotu VARCHAR(200) NOT NULL
);

CREATE TABLE rodzaje_placowek (
	id_rodz_placowki INT PRIMARY KEY NOT NULL
,	rodzaj_placowki VARCHAR(200) NOT NULL
);

CREATE TABLE typy_oddzialu (
	id_typu_oddzialu INT PRIMARY KEY NOT NULL
,	nazwa_typu_oddzialu VARCHAR(50) NOT NULL
);

CREATE TABLE uczniowie_ukr (
	id_pozycji INT PRIMARY KEY NOT NULL
,	powiat INT
,	rodzaj_placowki INT
,	publicznosc INT
,	typ_podmiotu INT
,	typ_oddzialu INT
,	klasa INT
,	liczba_oddzialow INT
,	liczna_uczniow INT
);

--utworzenie niezbêdnych tabel

INSERT INTO dbo.wojewodztwa
SELECT DISTINCT CAST(idTerytWojewodztwo AS INT), Województwo
FROM uczniowie_z_ukrainy;

INSERT INTO dbo.powiaty
SELECT DISTINCT CAST(idTerytPowiat as INT), Powiat, CONVERT(INT, idTerytWojewodztwo)
FROM uczniowie_z_ukrainy;

INSERT INTO dbo.klasy
SELECT DISTINCT CONVERT(INT, idKlasa), Klasa
FROM uczniowie_z_ukrainy
WHERE CONVERT(INT, idKlasa) <> 0;

INSERT INTO dbo.klasy (id_klasy, klasa)
VALUES (0, 'ND');

INSERT INTO publicznosc
SELECT DISTINCT CONVERT(INT, idPublicznosc), Publicznoœæ
FROM uczniowie_z_ukrainy;

INSERT INTO typy_podmiotu
SELECT DISTINCT CAST(idTypPodmiotu AS INT), [Typ Podmiotu]
FROM uczniowie_z_ukrainy;

INSERT INTO rodzaje_placowek
SELECT DISTINCT CAST(idRodzajPlacowki as INT), [Rodzaj Placowki]
FROM uczniowie_z_ukrainy;

INSERT INTO typy_oddzialu
SELECT DISTINCT CONVERT(INT, idTypOddzialu), [Typ Oddzia³u]
FROM uczniowie_z_ukrainy;

INSERT INTO uczniowie_ukr (id_pozycji, powiat, rodzaj_placowki, publicznosc, typ_podmiotu, 
typ_oddzialu, klasa, liczba_oddzialow, liczna_uczniow)
SELECT
		ROW_NUMBER() OVER(ORDER BY idTerytPowiat)
	,	CAST(idTerytPowiat as INT)
	,	CAST(idRodzajPlacowki as INT)
	,	CAST(idPublicznosc as INT)
	,	CAST(idTypPodmiotu as INT)
	,	CAST(idTypOddzialu as INT)
	,	CAST(idKlasa as INT)
	,	CAST([Liczba oddzia³ów] as INT)
	,	CAST([Liczba uczniów pobyt legalny] as INT)
FROM uczniowie_z_ukrainy
-- WSTAWIENIE DANYCH Z ISTNIEJ¥CEJ TABELI uczniowie_z_ukrainy

ALTER TABLE powiaty
ADD FOREIGN KEY (wojewodztwo) REFERENCES wojewodztwa(id_wojewodztwa);

ALTER TABLE uczniowie_ukr
ADD FOREIGN KEY (powiat) REFERENCES powiaty(id_powiatu);

ALTER TABLE uczniowie_ukr
ADD FOREIGN KEY (rodzaj_placowki) REFERENCES rodzaje_placowek(id_rodz_placowki);

ALTER TABLE uczniowie_ukr
ADD FOREIGN KEY (publicznosc) REFERENCES publicznosc(id_publicznosci);

ALTER TABLE uczniowie_ukr
ADD FOREIGN KEY (typ_podmiotu) REFERENCES typy_podmiotu(id_typ_podmiotu);

ALTER TABLE uczniowie_ukr
ADD FOREIGN KEY (typ_oddzialu) REFERENCES typy_oddzialu(id_typu_oddzialu);

ALTER TABLE uczniowie_ukr
ADD FOREIGN KEY (klasa) REFERENCES klasy(id_klasy);
-- utworzenie kluczów obcych miêdzy tabelami

EXEC sp_rename 'uczniowie_ukr.liczna_uczniow', 'liczba_uczniow';

EXEC sp_rename 'wojewodztwa.wojewodztwa', 'wojewodztwo';

/* W tym miejscu zaimportowa³em dodatkow¹ tabelê z danymi na temat powierzchni i liczby ludnoœci wed³ug powiatu.
Tabela o nazwie 'powiaty_ludnoœæ' pos³u¿y mi wy³¹cznie do aktualizacji 
i rozszerzenia tabeli 'powiaty', po czym zostanie usuniêta*/

ALTER TABLE powiaty
ADD powierzchnia_ha INT, powierzchnia_km2 INT, liczba_ludnosci INT, ludnosc_per_km2 INT;
-- utworzenie dodatkowych kolumn

UPDATE powiaty_ludnoœæ
SET wojewodztwo = RIGHT(wojewodztwo, LEN(wojewodztwo) - CHARINDEX(' ', wojewodztwo));
-- modyfikacja danych w tabeli, tak by mo¿na j¹ by³o po³¹czyæ po nazwie województwa z tabel¹ 'województwa'

WITH cte_powiaty AS (
SELECT	p.powiat as powiat_1, p.wojewodztwo as woj_1, pl.powierzchnia_ha as pow_ha_1, 
		pl.powierzchnia_km2 as pow_km_1, pl.liczba_ludnosci as licz_lud_1, pl.[ludnosc_per_1 km2] as lud_km_1
FROM powiaty p
JOIN wojewodztwa w ON p.wojewodztwo = w.id_wojewodztwa
JOIN powiaty_ludnoœæ pl ON p.powiat = pl.powiat AND pl.wojewodztwo = w.wojewodztwo
)

UPDATE powiaty
SET powierzchnia_ha = pow_ha_1,
	powierzchnia_km2 = pow_km_1,
	liczba_ludnosci = licz_lud_1,
	ludnosc_per_km2 = lud_km_1
FROM powiaty 
JOIN cte_powiaty ON powiaty.powiat = cte_powiaty.powiat_1 AND powiaty.wojewodztwo = cte_powiaty.woj_1;
-- aktualizacja tabeli 'powiaty' z wykorzystaniem wyra¿enia CTE

DROP TABLE powiaty_ludnoœæ;
-- tabela spe³ni³a swoje zadanie, wiêc mo¿na j¹ usun¹æ

/* W tym miejscu zaimportowa³em dodatkow¹ tabelê z danymi na temat liczby uczniów we wczeœniejszych okresach, dziêki temu 
dane bêd¹ ciekawsze.
Tabela o nazwie 'uczniowie_wg_dat_csv' pos³u¿y mi wy³¹cznie do aktualizacji 
i rozszerzenia tabeli 'uczniowie_ukr', po czym zostanie usuniêta*/

ALTER TABLE uczniowie_ukr
ADD stan_na_dzien DATE;

UPDATE uczniowie_ukr
SET stan_na_dzien = '2023-01-09';
-- moje pierwsze dane pochodzi³y z dnia 09.01.2023, lecz tej informacji nie by³o w tabeli.

DELETE FROM uczniowie_wg_dat_csv
WHERE id_pow = '';
-- usuniêcie pustych wierszy z tymczasowej tabeli

INSERT INTO uczniowie_ukr (id_pozycji, stan_na_dzien, powiat, rodzaj_placowki, publicznosc, typ_podmiotu, typ_oddzialu,
			klasa, liczba_oddzialow, liczba_uczniow)
SELECT 
		(SELECT MAX(id_pozycji) FROM uczniowie_ukr) + ROW_NUMBER() OVER (ORDER BY powiat)
	,	CONVERT(DATETIME, stan_na_dzien, 103)
	,	CONVERT(INT, id_pow)
	,	CONVERT(INT, id_rodz_plac)
	,	CONVERT(INT, id_publ)
	,	CONVERT(INT, id_typ_podmiotu)
	,	CONVERT(INT, id_typ_oddzialu)
	,	CONVERT(INT, id_klasy)
	,	CONVERT(INT, liczba_oddzialow)
	,	CONVERT(INT, liczba_uczniow)
FROM uczniowie_wg_dat_csv
WHERE CONVERT(DATETIME, stan_na_dzien, 103);

-- wstawienie do tabeli uczniowie_ukr kolejnych danych

DROP TABLE uczniowie_wg_dat_csv;
-- tabela spe³ni³a swoje zadanie, wiêc mo¿na j¹ usun¹æ

DROP TABLE uczniowie_z_ukrainy;
-- tabela spe³ni³a swoje zadanie, wiêc mo¿na j¹ usun¹æ

INSERT INTO uczniowie_ukr (id_pozycji, stan_na_dzien, powiat, rodzaj_placowki, publicznosc, typ_podmiotu, typ_oddzialu,
			klasa, liczba_oddzialow, liczba_uczniow)
SELECT 
		(SELECT MAX(id_pozycji) FROM uczniowie_ukr) + ROW_NUMBER() OVER (ORDER BY powiat)
	,	CONVERT(DATETIME, stan_na_dzien, 103)
	,	CONVERT(INT, id_pow)
	,	CONVERT(INT, id_rodz_plac)
	,	CONVERT(INT, id_publ)
	,	CONVERT(INT, id_typ_podmiotu)
	,	CONVERT(INT, id_typ_oddzialu)
	,	CONVERT(INT, id_klasy)
	,	CONVERT(INT, liczba_oddzialow)
	,	CONVERT(INT, liczba_uczniow)
FROM uczniowie_wg_dat_csv
WHERE CONVERT(DATETIME, stan_na_dzien, 103) > (SELECT MAX(stan_na_dzien) FROM uczniowie_ukr);

-- wstawienie do tabeli uczniowie_ukr kolejnych danych