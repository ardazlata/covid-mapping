SELECT * FROM PortfolioProject..CovidDeaths$
WHERE continent is not null
ORDER BY 3,4

--SELECT * FROM PortfolioProject..CovidVaccinations$
--ORDER BY 3,4

--Select data that we are going to be using

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM PortfolioProject..CovidDeaths$
WHERE continent is not null
ORDER BY 1,2

-- Looking at Total Cases VS Total Deaths

-- Shows likelihood of dying if you contract covid in your country

SELECT location, date, total_cases, total_deaths,
(CAST(total_deaths AS float) / CAST(total_cases AS float)*100) AS death_rate
FROM PortfolioProject..CovidDeaths$ WHERE location LIKE 'Turkey' AND continent is not null
ORDER BY 1, 2

-- Looking at Total Cases VS Population
--Shows what percentage of population got Covid-19

SELECT location, date, total_cases, population,
(CAST(total_cases AS float) / CAST(population AS float)*100) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths$ WHERE location LIKE 'Turkey'
ORDER BY 1, 2

-- Countries with Highest Infection Rate compared to Population

SELECT location, population, MAX(total_cases) AS HighestInfectionCount,
CAST(ROUND(MAX(total_cases / CAST(population AS float) * 100), 2) AS decimal(18, 2)) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths$
-- WHERE location = 'Turkey' Remember to include a spaced date range, otherwise the highest case numbers will be included in all data.
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC;

-- Showing Countries with Highest Death Count per Population

SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
-- WHERE location = 'Turkey' Remember to include a spaced date range, otherwise the highest case numbers will be included in all data.
WHERE continent is not null
GROUP BY location
ORDER BY TotalDeathCount DESC;

-- LET'S BREAK THINGS DOWN BY CONTINENT

SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
-- WHERE location = 'Turkey' Remember to include a spaced date range, otherwise the highest case numbers will be included in all data.
WHERE continent is null AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY TotalDeathCount DESC;

-- Death rates by income level

SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths$
WHERE continent IS NULL AND location LIKE '%income%'
GROUP BY location
ORDER BY TotalDeathCount DESC;

-- GLOBAL NUMBERS

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From PortfolioProject..CovidDeaths$
--Where location like '%states%'
where continent is not null 
--Group By date
order by 1,2



-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine

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
ORDER BY 2, 3;



-- Using CTE to perform Calculation on Partition By in previous query

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





-- Using Temp Table to perform Calculation on Partition By in previous query

-- Geçici tabloyu düþürme iþlemi
IF OBJECT_ID('tempdb..#PercentPopulationVaccinated', 'U') IS NOT NULL
BEGIN
    DROP TABLE #PercentPopulationVaccinated
END

-- Geçici tabloyu oluþturma
CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    NewVaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
)

-- Verileri ekleyerek geçici tabloyu doldurma
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

-- Sonuçlarý görüntüleme ve yüzde hesaplama
SELECT 
    *, 
    (ISNULL(RollingPeopleVaccinated, 0) / Population) * 100 AS PercentVaccinated
FROM #PercentPopulationVaccinated


-- Creating View to store data for later visualizations

Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From PortfolioProject..CovidDeaths$ dea
Join PortfolioProject..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 

SELECT
    Location,
    Population,
    CONVERT(VARCHAR, Date, 101) AS ShortDate,
    MAX(total_cases) AS HighestInfectionCount,
    MAX((total_cases / Population) * 100) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths$
-- WHERE Location LIKE '%states'
GROUP BY Location, Population, CONVERT(VARCHAR, Date, 101)
ORDER BY PercentPopulationInfected DESC;
