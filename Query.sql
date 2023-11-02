-- CovidDeaths tablosundan verileri �ek
-- Bo� k�talar� filtrele
-- 3. ve 4. s�tuna g�re s�rala
SELECT * FROM PortfolioProject..CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 3, 4


-- Kullanaca��m�z verileri se�
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject..CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- Toplam Vaka Say�s� ile Toplam �l�m Say�s�n� Kar��la�t�r
-- Covid kapt���n�zda �lme olas�l���n� g�ster
SELECT location, date, total_cases, total_deaths,
(CAST(total_deaths AS float) / CAST(total_cases AS float)*100) AS death_rate
FROM PortfolioProject..CovidDeaths$ WHERE location LIKE 'Turkey' AND continent IS NOT NULL
ORDER BY 1, 2

-- Toplam Vaka Say�s� ile N�fus Say�s�n� Kar��la�t�r
-- N�fusun hangi y�zdesinin Covid-19 kapt���n� g�ster
SELECT location, date, total_cases, population,
(CAST(total_cases AS float) / CAST(population AS float)*100) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths$ WHERE location LIKE 'Turkey'
ORDER BY 1, 2

-- N�fusa g�re En Y�ksek Enfeksiyon Oran�na Sahip �lkeleri G�ster
SELECT location, population, MAX(total_cases) AS HighestInfectionCount,
CAST(ROUND(MAX(total_cases / CAST(population AS float) * 100), 2) AS decimal(18, 2)) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths$
-- T�rkiye yerine 'Turkey' olmal�d�r, aksi takdirde tarih aral��� dahil edilmezse en y�ksek vaka say�lar� t�m verilerde yer al�r
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC

-- N�fusa g�re En Y�ksek �l�m Say�s�na Sahip �lkeleri G�ster
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
-- T�rkiye yerine 'Turkey' olmal�d�r, aksi takdirde tarih aral��� dahil edilmezse en y�ksek vaka say�lar� t�m verilerde yer al�r
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC

-- KITAYA G�RE VER�LER� G�STER
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
-- T�rkiye yerine 'Turkey' olmal�d�r, aksi takdirde tarih aral��� dahil edilmezse en y�ksek vaka say�lar� t�m verilerde yer al�r
WHERE continent IS NULL AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY TotalDeathCount DESC

-- Gelir Seviyesine G�re �l�m Oranlar�
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
WHERE continent IS NULL AND location LIKE '%income%'
GROUP BY location
ORDER BY TotalDeathCount DESC

-- GLOBAL SAYILAR
-- Yeni vakalar�n toplam�n�, �l�mlerin toplam�n� ve �l�m y�zdesini g�ster
SELECT
    SUM(new_cases) as total_cases,
    SUM(cast(new_deaths as int)) as total_deaths,
    SUM(cast(new_deaths as int)) / SUM(New_Cases) * 100 as DeathPercentage
FROM PortfolioProject..CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- Toplam N�fus ile A��lar
-- En az bir Covid A��s� alm�� n�fusun y�zdesini g�ster
SELECT 
    dea.continent, 
    dea.location, 
    dea.date, 
    dea.population, 
    vac.new_vaccinations,
    SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths$ dea
JOIN PortfolioProject..CovidVaccinations$ vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2, 3

-- �nceki sorguda Partition By hesaplamas� yapmak i�in CTE kullanma
WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
       SUM(ISNULL(CONVERT(BIGINT, vac.new_vaccinations), 0)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths$ dea
JOIN PortfolioProject..CovidVaccinations$ vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
)
SELECT *, (RollingPeopleVaccinated * 1.0 / Population) * 100
FROM PopvsVac

-- Ge�ici Tablo Kullanarak �nceki Sorguda Partition By ile Hesaplama Yapma

-- Ge�ici tabloyu olu�tur
IF OBJECT_ID('tempdb..#PercentPopulationVaccinated', 'U') IS NOT NULL
BEGIN
    DROP TABLE #PercentPopulationVaccinated
END

CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    NewVaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
)

-- Verileri ekleyerek ge�ici tabloyu doldur
INSERT INTO #PercentPopulationVaccinated
SELECT 
    DEA.Continent, 
    DEA.Location, 
    DEA.Date, 
    DEA.Population, 
    VAC.new_vaccinations,
    SUM(CONVERT(NUMERIC(18, 2), VAC.new_vaccinations)) 
        OVER (PARTITION BY DEA.Location ORDER BY DEA.Location, DEA.Date) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths$ DEA
JOIN PortfolioProject..CovidVaccinations$ VAC
    ON DEA.Location = VAC.Location
    AND DEA.Date = VAC.Date

-- Sonu�lar� g�r�nt�le ve y�zde hesapla
SELECT 
    *, 
    (ISNULL(RollingPeopleVaccinated, 0) / Population) * 100 AS Y�zdeA��lanm��
FROM #PercentPopulationVaccinated


-- En Y�ksek Enfeksiyon Say�s�na Sahip �lkeleri G�ster
SELECT
    Location AS �lke,
    Population AS N�fus,
    CONVERT(VARCHAR, Date, 101) AS K�saTarih,
    MAX(total_cases) AS EnY�ksekEnfeksiyonSay�s�,
    MAX((total_cases / Population) * 100) AS N�fusOran�ylaEnfekteY�zde
FROM PortfolioProject..CovidDeaths$
GROUP BY Location, Population, CONVERT(VARCHAR, Date, 101)
ORDER BY N�fusOran�ylaEnfekteY�zde DESC;
