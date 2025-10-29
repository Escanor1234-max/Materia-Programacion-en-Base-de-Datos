---Creacion de tablas
CREATE TABLE owid_energy_data (
    country VARCHAR2(100),
    iso_code VARCHAR2(10),
    year NUMBER,
    population NUMBER,
    gdp NUMBER,
    energy_per_capita NUMBER,
    energy_cons_per_capita NUMBER,
    primary_energy_consumption NUMBER
);
BEGIN
    EXECUTE IMMEDIATE '
        CREATE TABLE reporte_calidad_datos (
            country VARCHAR2(100),
            columna VARCHAR2(50),
            porcentaje_invalidos NUMBER(5,2),
            total_registros NUMBER,
            calidad_datos VARCHAR2(20)
        )
    ';
EXCEPTION 
    WHEN OTHERS THEN 
        IF SQLCODE = -955 THEN 
            NULL; -- Ignorar si la tabla ya existe
        ELSE 
            RAISE;
        END IF;
END;
/
---Prueba de un pais
SELECT
    country,
    COUNT(*) AS total_registros,
    SUM(
        CASE 
            WHEN primary_energy_consumption IS NULL 
                 OR primary_energy_consumption = 0 
                 OR primary_energy_consumption < 0 
                 OR primary_energy_consumption = -99 
            THEN 1 
            ELSE 0 
        END
    ) AS registros_invalidos,
    ROUND(
        (SUM(
            CASE 
                WHEN primary_energy_consumption IS NULL 
                     OR primary_energy_consumption = 0 
                     OR primary_energy_consumption < 0 
                     OR primary_energy_consumption = -99 
                THEN 1 ELSE 0 END
        ) / COUNT(*)) * 100, 2
    ) AS porcentaje_invalidos
FROM owid_energy_data
WHERE country = 'Mexico'
GROUP BY country;
--  Recorrer países y columnas para generar el reporte
DECLARE
    CURSOR c_paises IS
        SELECT DISTINCT country FROM owid_energy_data WHERE country IS NOT NULL;

    TYPE t_columnas IS TABLE OF VARCHAR2(50);
    v_columnas t_columnas := t_columnas(
        'population',
        'gdp',
        'energy_per_capita',
        'energy_cons_per_capita',
        'primary_energy_consumption'
    );

    v_sql VARCHAR2(4000);
    v_country VARCHAR2(100);
    v_columna VARCHAR2(50);
    v_total NUMBER;
    v_invalidos NUMBER;
    v_porcentaje NUMBER;
    v_calidad VARCHAR2(20);
BEGIN
    FOR r_pais IN c_paises LOOP
        v_country := r_pais.country;

        FOR i IN 1 .. v_columnas.COUNT LOOP
            v_columna := v_columnas(i);

            v_sql := '
                SELECT COUNT(*) AS total_registros,
                       SUM(CASE 
                             WHEN ' || v_columna || ' IS NULL 
                                  OR ' || v_columna || ' = 0
                                  OR ' || v_columna || ' = -99
                                  OR ' || v_columna || ' < 0
                             THEN 1 ELSE 0 END) AS invalidos
                FROM owid_energy_data
                WHERE country = :1';

            EXECUTE IMMEDIATE v_sql
                INTO v_total, v_invalidos
                USING v_country;

            IF v_total > 0 THEN
                v_porcentaje := ROUND((v_invalidos / v_total) * 100, 2);
            ELSE
                v_porcentaje := NULL;
            END IF;

            v_calidad := CASE 
                            WHEN v_porcentaje = 0 THEN 'Excelente'
                            WHEN v_porcentaje <= 10 THEN 'Buena'
                            WHEN v_porcentaje <= 30 THEN 'Regular'
                            ELSE 'Deficiente'
                         END;

            INSERT INTO reporte_calidad_datos (
                country, columna, porcentaje_invalidos, total_registros, calidad_datos
            ) VALUES (
                v_country, v_columna, v_porcentaje, v_total, v_calidad
            );
        END LOOP;
    END LOOP;

    COMMIT;
END;
/
---Exportar el reporte a un archivo csv
SELECT * FROM reporte_calidad_datos;
