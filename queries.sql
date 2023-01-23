USE UkrainscyUczniowie;

/*1. Wyniki ogólne - ³¹czna liczba uczniów, liczba mieszkañców przypadaj¹cych na jednego ucznia, 
	liczba uczniów przypadaj¹cych na jeden powiat wed³ug ostatniej najnowszej aktualizacji*/
SELECT 
		SUM(ppd.liczba_uczniow) as suma_uczniow 
	,	SUM(p.liczba_ludnosci)/SUM(ppd.liczba_uczniow) as mieszkancy_na_ucznia
	,	ROUND(CONVERT(FLOAT, SUM(ppd.liczba_uczniow))/(SELECT COUNT(*) FROM powiaty), 0) as uczniowe_na_powiat
FROM placowki_pelne_dane as ppd
JOIN powiaty as p ON ppd.id_powiatu = p.id_powiatu
WHERE stan_na_dzien = (SELECT MAX(stan_na_dzien) FROM placowki_pelne_dane);

/*2. Zwraca ró¿nice w liczbie ukraiñskich uczniów w wojewodztwach pomiêdzy kolejnymi aktualizacjami danych*/
WITH cte_total_liczba AS (
SELECT DISTINCT wojewodztwo, stan_na_dzien, SUM(liczba_uczniow) OVER 
	(PARTITION BY stan_na_dzien, wojewodztwo) AS total_suma_uczniow
FROM placowki_pelne_dane
)
SELECT wojewodztwo, stan_na_dzien, total_suma_uczniow,
	total_suma_uczniow - (LAG(total_suma_uczniow) OVER (PARTITION BY wojewodztwo 
	ORDER BY wojewodztwo, stan_na_dzien)) AS roznica_pomiedzy_datami,
	ROUND(CONVERT(FLOAT, total_suma_uczniow - (LAG(total_suma_uczniow) OVER (PARTITION BY wojewodztwo 
	ORDER BY wojewodztwo, stan_na_dzien)))/(LAG(total_suma_uczniow) OVER (PARTITION BY wojewodztwo 
	ORDER BY wojewodztwo, stan_na_dzien))* 100, 2) AS roznica_proc_pomiedzy_datami,
	(LAG(stan_na_dzien) OVER (ORDER BY wojewodztwo, stan_na_dzien)) AS poprzednia_data
FROM cte_total_liczba
ORDER BY wojewodztwo, stan_na_dzien;

/*3. £¹czna liczba ukraiñskich uczniów i liczba oddzia³ów wed³ug dat. 
Najwiêcej ukraiñskich uczniów uczy³o siê w polskich szko³ach w maju 2022.
W szczytowym momencie by³o to ponad 198 tys. uczniów*/
SELECT stan_na_dzien, SUM(liczba_uczniow) as liczba_ucz, SUM(liczba_oddzialow) as liczba_odd
FROM placowki_pelne_dane
GROUP BY stan_na_dzien
ORDER BY liczba_ucz DESC

--4. Wojewodztwa z najwiêksz¹ liczb¹ uczniow + kolumna z najwy¿szym poziomem historycznie
WITH suma_uczniow_wg_woj AS (
SELECT wojewodztwo, stan_na_dzien, SUM(liczba_uczniow) as woj_suma_uczniow
FROM placowki_pelne_dane
GROUP BY wojewodztwo, stan_na_dzien
)

SELECT DISTINCT wojewodztwo, LAST_VALUE(woj_suma_uczniow) OVER (PARTITION BY wojewodztwo
		ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS stan_aktualny,
	MAX(woj_suma_uczniow) OVER (PARTITION BY wojewodztwo) as max_stan_wojewodztwa
FROM suma_uczniow_wg_woj
ORDER BY stan_aktualny DESC;

--5. Powiaty z najwiêksz¹ liczb¹ uczniow + kolumna z najwy¿szym poziomem historycznie
WITH suma_uczniow_wg_woj AS (
SELECT id_powiatu, powiat, stan_na_dzien, SUM(liczba_uczniow) as pow_suma_uczniow
FROM placowki_pelne_dane
GROUP BY id_powiatu, powiat, stan_na_dzien
)

SELECT DISTINCT id_powiatu, powiat, LAST_VALUE(pow_suma_uczniow) OVER (PARTITION BY id_powiatu
		ORDER BY stan_na_dzien RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS stan_aktualny,
	MAX(pow_suma_uczniow) OVER (PARTITION BY id_powiatu) as max_stan_powiatu
FROM suma_uczniow_wg_woj
ORDER BY stan_aktualny DESC;

--6. Liczba klas (odzia³ów) ³¹cznie, ilu uczniow na jedn¹ klasê
SELECT SUM(liczba_oddzialow) AS liczba_klas, 
		ROUND(CONVERT(FLOAT, SUM(liczba_uczniow))/SUM(liczba_oddzialow), 2) AS uczniowie_na_klase
FROM placowki_pelne_dane
WHERE stan_na_dzien = (SELECT MAX(stan_na_dzien) FROM placowki_pelne_dane);

--7. Podsumowanie wg poziomu nauczania
SELECT nazwa_typu_podmiotu, SUM(liczba_uczniow) as liczba_ucz_klasa,
		ROUND(SUM(liczba_uczniow)/(SELECT CONVERT(FLOAT, (SUM(liczba_uczniow))) FROM placowki_pelne_dane 
		WHERE stan_na_dzien = (SELECT MAX(stan_na_dzien) FROM placowki_pelne_dane)) * 100, 2) AS udzial_procentowy,
		ROUND(CONVERT(FLOAT, SUM(liczba_uczniow))/SUM(liczba_oddzialow), 2) AS uczniowie_na_klase
FROM placowki_pelne_dane
WHERE stan_na_dzien = (SELECT MAX(stan_na_dzien) FROM placowki_pelne_dane)
GROUP BY nazwa_typu_podmiotu
ORDER BY liczba_ucz_klasa DESC;

--8. Podsumowanie wg publicznosci
SELECT typ_publicznosci, SUM(liczba_uczniow) as liczba_ucz_typ_publ,
		ROUND(SUM(liczba_uczniow)/(SELECT CONVERT(FLOAT, (SUM(liczba_uczniow))) FROM placowki_pelne_dane 
		WHERE stan_na_dzien = (SELECT MAX(stan_na_dzien) FROM placowki_pelne_dane)) * 100, 2) AS udzial_procentowy,
		ROUND(CONVERT(FLOAT, SUM(liczba_uczniow))/SUM(liczba_oddzialow), 2) AS uczniowie_na_klase
FROM placowki_pelne_dane
WHERE stan_na_dzien = (SELECT MAX(stan_na_dzien) FROM placowki_pelne_dane)
GROUP BY typ_publicznosci
ORDER BY liczba_ucz_typ_publ DESC;

