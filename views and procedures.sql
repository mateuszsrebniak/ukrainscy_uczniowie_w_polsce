CREATE VIEW placowki_pelne_dane AS (
SELECT	ucz.id_pozycji, pow.id_powiatu, pow.powiat, woj.wojewodztwo, plac.rodzaj_placowki, publ.typ_publicznosci,
		podm.nazwa_typu_podmiotu, odd.nazwa_typu_oddzialu, klas.klasa, ucz.liczba_oddzialow, ucz.liczba_uczniow, ucz.stan_na_dzien
FROM uczniowie_ukr AS ucz
	JOIN powiaty AS pow ON ucz.powiat = pow.id_powiatu
	JOIN wojewodztwa AS woj ON pow.wojewodztwo = woj.id_wojewodztwa
	JOIN rodzaje_placowek AS plac ON ucz.rodzaj_placowki = plac.id_rodz_placowki
	JOIN publicznosc AS publ ON ucz.publicznosc = publ.id_publicznosci
	JOIN typy_podmiotu AS podm ON ucz.typ_podmiotu = podm.id_typ_podmiotu
	JOIN typy_oddzialu AS odd ON ucz.typ_oddzialu = odd.id_typu_oddzialu
	JOIN klasy as klas ON ucz.klasa = klas.id_klasy
);
-- utworzenie widoku ��cz�cego potrzebne dane ze wszystkich tabel;
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
CREATE VIEW uczniowie_dane_szczegolowe AS
WITH 
suma_uczniow_wg_woj AS (
SELECT DISTINCT id_powiatu, powiat, stan_na_dzien, wojewodztwo,
	SUM(liczba_uczniow) OVER (PARTITION BY id_powiatu, stan_na_dzien) as pow_suma_uczniow,
	SUM(liczba_oddzialow) OVER (PARTITION BY id_powiatu, stan_na_dzien) as pow_suma_oddzialow,
	SUM(liczba_uczniow) OVER (PARTITION BY wojewodztwo, stan_na_dzien) as woj_suma_uczniow,
	SUM(liczba_oddzialow) OVER (PARTITION BY wojewodztwo, stan_na_dzien) as woj_suma_oddzialow
FROM placowki_pelne_dane
),
wojewodztwa_ludnosc AS (
SELECT w.id_wojewodztwa, w.wojewodztwo, SUM(liczba_ludnosci) AS woj_liczba_ludnosci
FROM wojewodztwa w
JOIN powiaty AS p ON p.wojewodztwo = w.id_wojewodztwa
GROUP BY w.wojewodztwo, id_wojewodztwa
)

SELECT DISTINCT s.id_powiatu, s.powiat, w.wojewodztwo, LAST_VALUE(pow_suma_uczniow) OVER (PARTITION BY s.id_powiatu
		ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS pow_stan_aktualny,
	MAX(pow_suma_uczniow) OVER (PARTITION BY s.id_powiatu) as pow_max_stan,
	MIN(pow_suma_uczniow) OVER (PARTITION BY s.id_powiatu) as pow_min_stan,
	liczba_ludnosci/LAST_VALUE(pow_suma_uczniow) OVER (PARTITION BY s.id_powiatu ORDER BY stan_na_dzien 
	RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as pow_akt_liczba_mieszkancow_na_ucznia,
	LAST_VALUE(pow_suma_oddzialow) OVER (PARTITION BY s.id_powiatu
	ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS pow_akt_liczba_klas,
	ROUND(CONVERT(FLOAT,LAST_VALUE(pow_suma_uczniow) OVER (PARTITION BY s.id_powiatu
	ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING))/
	LAST_VALUE(pow_suma_oddzialow) OVER (PARTITION BY s.id_powiatu
	ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 2) AS pow_akt_liczba_uczniow_na_klase,
	LAST_VALUE(woj_suma_uczniow) OVER (PARTITION BY s.wojewodztwo
	ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS woj_stan_aktualny,
	MAX(woj_suma_uczniow) OVER (PARTITION BY s.wojewodztwo) as woj_max_stan,
	MIN(woj_suma_uczniow) OVER (PARTITION BY s.wojewodztwo) as woj_min_stan,
	w.woj_liczba_ludnosci/LAST_VALUE(woj_suma_uczniow) OVER (PARTITION BY s.wojewodztwo ORDER BY stan_na_dzien 
	RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as woj_akt_liczba_mieszkancow_na_ucznia,
	LAST_VALUE(woj_suma_oddzialow) OVER (PARTITION BY s.wojewodztwo
	ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS woj_akt_liczba_klas,
	ROUND(CONVERT(FLOAT,LAST_VALUE(woj_suma_uczniow) OVER (PARTITION BY s.wojewodztwo
	ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING))/
	LAST_VALUE(woj_suma_oddzialow) OVER (PARTITION BY s.wojewodztwo
	ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 2) AS woj_akt_liczba_uczniow_na_klase
FROM suma_uczniow_wg_woj AS s
JOIN powiaty AS p ON s.id_powiatu = p.id_powiatu
JOIN wojewodztwa_ludnosc AS w ON p.wojewodztwo = w.id_wojewodztwa;
/* Utworzenie widoku zawieraj�cego nast�puj�ce informacje
- aktualna liczba uczniow wg powiatu i wojew�dztwa,
- max liczba uczniow wg powiatu i wojew�dztwa,
- min liczba uczniow wg powiatu i wojew�dztwa,
- liczba mieszka�c�w na jednego ucznia wg powiatu i wojew�dztwa,
- maksymalna r�nica liczby uczni�w mi�dzy datami wg powiatu i wojew�dztwa,
- liczba klas wg powiatu i wojew�dztwa,
- liczba uczniow na jedn� klas� wg powiatu i wojew�dztwa*/
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dane_powiatu
	@powiat VARCHAR(150), -- nazwa powiatu
	@wojewodztwo VARCHAR(50) -- nazwa wojew�dztwa
AS
	SELECT powiat, wojewodztwo, pow_stan_aktualny, pow_max_stan, pow_min_stan, pow_akt_liczba_mieszkancow_na_ucznia,
		pow_akt_liczba_klas, pow_akt_liczba_uczniow_na_klase
	FROM uczniowie_dane_szczegolowe
	WHERE powiat = LOWER(@powiat) and wojewodztwo = UPPER(@wojewodztwo);
--utworzenie procedury zwracaj�cej dane na temat ukrai�skich uczni�w w wybranym powiecie
EXEC dane_powiatu @powiat = 'k�dzierzy�sko-kozielski', @wojewodztwo = 'opolskie'; --przyk�ad wywo�ania procedury
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dane_wojewodztwa
	@wojewodztwo VARCHAR(50) -- nazwa wojew�dztwa
AS
	SELECT DISTINCT wojewodztwo, woj_stan_aktualny, woj_max_stan, woj_min_stan, woj_akt_liczba_mieszkancow_na_ucznia,
		woj_akt_liczba_klas, woj_akt_liczba_uczniow_na_klase
	FROM uczniowie_dane_szczegolowe
	WHERE wojewodztwo = UPPER(@wojewodztwo);
--utworzenie procedury zwracaj�cej dane na temat ukrai�skich uczni�w w wybranym powiecie
EXEC dane_wojewodztwa @wojewodztwo = 'opolskie'; --przyk�ad wywo�ania procedury
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE top_wojewodztwa
	@top INT, -- ile g�rnych/dolnych wynik�w ma zwr�ci� procedura
	@sortowanie VARCHAR(1) -- wyb�r kierunku sortowania ASC/DESC, jako warto�ci przyjmuje tylko 'A'/'a', 'D'/d')
AS
BEGIN
DECLARE
	@tresc_bledu VARCHAR(300) = 'Poda�e� b��dny kierunek sortowania. Wybierz "A", by posortowa� "rosn�co" lub "D", by posortowa� malej�co.'
	IF @sortowanie NOT IN ('a', 'A', 'd', 'D')	
	BEGIN
		PRINT @tresc_bledu
		RETURN
	END
	IF @sortowanie IN ('a', 'A', 'd', 'D')
	BEGIN
		SET @sortowanie = UPPER(@sortowanie);
		WITH woj_cte AS (
		SELECT DISTINCT wojewodztwo, 
			CASE @sortowanie WHEN 'A' THEN woj_stan_aktualny END AS dolne_wojewodztwa,
			CASE @sortowanie WHEN 'D' THEN woj_stan_aktualny END AS gorne_wojewodztwa,
			woj_stan_aktualny, woj_max_stan, woj_min_stan, woj_akt_liczba_mieszkancow_na_ucznia, woj_akt_liczba_klas, 
			woj_akt_liczba_uczniow_na_klase
		FROM uczniowie_dane_szczegolowe
		)
		SELECT TOP (@top) wojewodztwo, woj_stan_aktualny, woj_max_stan, woj_min_stan, woj_akt_liczba_mieszkancow_na_ucznia, 
		woj_akt_liczba_klas, woj_akt_liczba_uczniow_na_klase
		FROM woj_cte
		ORDER BY dolne_wojewodztwa ASC, gorne_wojewodztwa DESC
	END
END;
/*utorzenie procedury, kt�ra przyjmuje dwa parametry @sortowanie, czyli kierunek sortowania oraz @top, czyli liczb� 
dolnych lub g�rnych (w zale�no�ci od wybranego kierunku sortowania) rekord�w, kt�re chcemy uzyska�. Procedura zwraca 
szczeg�owe informacje na temat wojew�dztw: aktualna liczba uczni�w, maksymalna liczba uczni�w historycznie,
minimalna liczba uczni�w historycznie, aktualna liczba mieszka�c�w przypadaj�c� na jednego ucznia, aktualna liczba klas,
w kt�rych ucz� si� ukrai�scy uczniowie, aktualna liczba uczni�w przypadaj�cych na jedn� klas�*/

EXEC top_wojewodztwa @top = 10, @sortowanie = 'a'; -- przyk�ad wywo�ania procedury.
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE top_powiaty
	@top INT, -- ile g�rnych/dolnych wynik�w ma zwr�ci� procedura
	@sortowanie VARCHAR(1) -- wyb�r kierunku sortowania ASC/DESC, jako warto�ci przyjmuje tylko 'A'/'a', 'D'/d')
AS
BEGIN
DECLARE
	@tresc_bledu VARCHAR(300) = 'Poda�e� b��dny kierunek sortowania. Wybierz "A", by posortowa� "rosn�co" lub "D", by posortowa� malej�co.'
	IF @sortowanie NOT IN ('a', 'A', 'd', 'D')	
	BEGIN
		PRINT @tresc_bledu
		RETURN
	END
	IF @sortowanie IN ('a', 'A', 'd', 'D')
	BEGIN
		SET @sortowanie = UPPER(@sortowanie);
		WITH woj_cte AS (
		SELECT DISTINCT powiat, 
			CASE @sortowanie WHEN 'A' THEN pow_stan_aktualny END AS dolne_powiaty,
			CASE @sortowanie WHEN 'D' THEN pow_stan_aktualny END AS gorne_powiaty,
			pow_stan_aktualny, pow_max_stan, pow_min_stan, pow_akt_liczba_mieszkancow_na_ucznia, pow_akt_liczba_klas, 
			pow_akt_liczba_uczniow_na_klase
		FROM uczniowie_dane_szczegolowe
		)
		SELECT TOP (@top) powiat, pow_stan_aktualny, pow_max_stan, pow_min_stan, pow_akt_liczba_mieszkancow_na_ucznia, 
		pow_akt_liczba_klas, pow_akt_liczba_uczniow_na_klase
		FROM woj_cte
		ORDER BY dolne_powiaty ASC, gorne_powiaty DESC
	END
END;
/*utorzenie procedury, kt�ra przyjmuje dwa parametry @sortowanie, czyli kierunek sortowania oraz @top, czyli liczb� 
dolnych lub g�rnych (w zale�no�ci od wybranego kierunku sortowania) rekord�w, kt�re chcemy uzyska�. Procedura zwraca 
szczeg�owe informacje na temat powiat�w: aktualna liczba uczni�w, maksymalna liczba uczni�w historycznie,
minimalna liczba uczni�w historycznie, aktualna liczba mieszka�c�w przypadaj�c� na jednego ucznia, aktualna liczba klas,
w kt�rych ucz� si� ukrai�scy uczniowie, aktualna liczba uczni�w przypadaj�cych na jedn� klas�*/

EXEC top_powiaty @top = 10, @sortowanie = 'a'; -- przyk�ad wywo�ania procedury.
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE wstaw_dane
@tabela VARCHAR(100) -- nazwa tabeli, z kt�rej chcemy wyci�gn�� dane
AS
BEGIN
DECLARE
@zapytanie NVARCHAR(1000)
SET @zapytanie = 
'INSERT INTO uczniowie_ukr (id_pozycji, stan_na_dzien, powiat, rodzaj_placowki, publicznosc, typ_podmiotu, typ_oddzialu,
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
FROM' + @tabela +
'WHERE CONVERT(DATETIME, stan_na_dzien, 103) > (SELECT MAX(stan_na_dzien) FROM uczniowie_ukr)'
EXEC sp_executesql @zapytanie
END;
/*utworzenie procedury automatyzuj�cej wprowadzanie nowych danych do tabeli 'uczniowie_ukr'.
Jako parametr procedura przyjmuje nazw� tabeli, z kt�rej chcemy pozyska� nowe dane*/

EXEC wstaw_dane @tabela = '[dbo].[uczniowie_wg_dat_csv]'; -- przyk�ad wywo�ania procedury.