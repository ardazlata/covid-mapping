-- CovidDeaths tablosundan verileri çek
-- Boþ kýtalarý filtrele
-- 3. ve 4. sütuna göre sýrala
SELECT * FROM PortfolioProject..CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 3, 4


-- Kullanacaðýmýz verileri seç
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject..CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- Toplam Vaka Sayýsý ile Toplam Ölüm Sayýsýný Karþýlaþtýr
-- Covid kaptýðýnýzda ölme olasýlýðýný göster
SELECT location, date, total_cases, total_deaths,
(CAST(total_deaths AS float) / CAST(total_cases AS float)*100) AS death_rate
FROM PortfolioProject..CovidDeaths$ WHERE location LIKE 'Turkey' AND continent IS NOT NULL
ORDER BY 1, 2

-- Toplam Vaka Sayýsý ile Nüfus Sayýsýný Karþýlaþtýr
-- Nüfusun hangi yüzdesinin Covid-19 kaptýðýný göster
SELECT location, date, total_cases, population,
(CAST(total_cases AS float) / CAST(population AS float)*100) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths$ WHERE location LIKE 'Turkey'
ORDER BY 1, 2

-- Nüfusa göre En Yüksek Enfeksiyon Oranýna Sahip Ülkeleri Göster
SELECT location, population, MAX(total_cases) AS HighestInfectionCount,
CAST(ROUND(MAX(total_cases / CAST(population AS float) * 100), 2) AS decimal(18, 2)) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths$
-- Türkiye yerine 'Turkey' olmalýdýr, aksi takdirde tarih aralýðý dahil edilmezse en yüksek vaka sayýlarý tüm verilerde yer alýr
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC

-- Nüfusa göre En Yüksek Ölüm Sayýsýna Sahip Ülkeleri Göster
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
-- Türkiye yerine 'Turkey' olmalýdýr, aksi takdirde tarih aralýðý dahil edilmezse en yüksek vaka sayýlarý tüm verilerde yer alýr
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC

-- KITAYA GÖRE VERÝLERÝ GÖSTER
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
-- Türkiye yerine 'Turkey' olmalýdýr, aksi takdirde tarih aralýðý dahil edilmezse en yüksek vaka sayýlarý tüm verilerde yer alýr
WHERE continent IS NULL AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY TotalDeathCount DESC

-- Gelir Seviyesine Göre Ölüm Oranlarý
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
WHERE continent IS NULL AND location LIKE '%income%'
GROUP BY location
ORDER BY TotalDeathCount DESC

-- GLOBAL SAYILAR
-- Yeni vakalarýn toplamýný, ölümlerin toplamýný ve ölüm yüzdesini göster
SELECT
    SUM(new_cases) as total_cases,
    SUM(cast(new_deaths as int)) as total_deaths,
    SUM(cast(new_deaths as int)) / SUM(New_Cases) * 100 as DeathPercentage
FROM PortfolioProject..CovidDeaths$
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- Toplam Nüfus ile Aþýlar
-- En az bir Covid Aþýsý almýþ nüfusun yüzdesini göster
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

-- Önceki sorguda Partition By hesaplamasý yapmak için CTE kullanma
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

-- Geçici Tablo Kullanarak Önceki Sorguda Partition By ile Hesaplama Yapma

-- Geçici tabloyu oluþtur
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

-- Verileri ekleyerek geçici tabloyu doldur
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

-- Sonuçlarý görüntüle ve yüzde hesapla
SELECT 
    *, 
    (ISNULL(RollingPeopleVaccinated, 0) / Population) * 100 AS YüzdeAþýlanmýþ
FROM #PercentPopulationVaccinated


-- En Yüksek Enfeksiyon Sayýsýna Sahip Ülkeleri Göster
SELECT
    Location AS Ülke,
    Population AS Nüfus,
    CONVERT(VARCHAR, Date, 101) AS KýsaTarih,
    MAX(total_cases) AS EnYüksekEnfeksiyonSayýsý,
    MAX((total_cases / Population) * 100) AS NüfusOranýylaEnfekteYüzde
FROM PortfolioProject..CovidDeaths$
GROUP BY Location, Population, CONVERT(VARCHAR, Date, 101)
ORDER BY NüfusOranýylaEnfekteYüzde DESC;
