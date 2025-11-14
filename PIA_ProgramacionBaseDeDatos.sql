-- PROCEDURE reporte_datos_ausentes
CREATE OR REPLACE PROCEDURE reporte_datos_ausentes IS
    v_total_registros NUMBER;
    v_nulos NUMBER;
    v_porcentaje NUMBER;
    v_contador NUMBER := 1;
    
    TYPE t_columnas IS TABLE OF VARCHAR2(50);
    v_columnas t_columnas := t_columnas('POPULATION', 'GDP');
    
BEGIN
    SELECT COUNT(*) INTO v_total_registros FROM owid_energy_data;
    
    DBMS_OUTPUT.PUT_LINE('=== REPORTE DE DATOS AUSENTES ===');
    DBMS_OUTPUT.PUT_LINE('Total de registros: ' || v_total_registros);
    DBMS_OUTPUT.PUT_LINE('--------------------------------');
    
    -- FOR LOOP
    DBMS_OUTPUT.PUT_LINE('--- FOR LOOP - Analisis de Columnas ---');
    FOR i IN 1..v_columnas.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM owid_energy_data WHERE ' || v_columnas(i) || ' IS NULL' INTO v_nulos;
            v_porcentaje := ROUND((v_nulos / v_total_registros) * 100, 1);
            
            -- CASE
            CASE 
                WHEN v_porcentaje = 0 THEN
                    DBMS_OUTPUT.PUT_LINE(v_columnas(i) || ': ' || v_porcentaje || '% - COMPLETO');
                WHEN v_porcentaje < 20 THEN
                    DBMS_OUTPUT.PUT_LINE(v_columnas(i) || ': ' || v_porcentaje || '% - ACEPTABLE');
                ELSE
                    DBMS_OUTPUT.PUT_LINE(v_columnas(i) || ': ' || v_porcentaje || '% - INCOMPLETO');
            END CASE;
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(v_columnas(i) || ': ERROR');
        END;
    END LOOP;
    
    -- WHILE LOOP
    DBMS_OUTPUT.PUT_LINE('--- WHILE LOOP - Resumen ---');
    v_contador := 1;
    WHILE v_contador <= v_columnas.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('Columna ' || v_contador || ': ' || v_columnas(v_contador));
        v_contador := v_contador + 1;
    END LOOP;
    
    -- BASIC LOOP con EXIT
    DBMS_OUTPUT.PUT_LINE('--- BASIC LOOP - Muestra ---');
    v_contador := 1;
    LOOP
        EXIT WHEN v_contador > v_columnas.COUNT;
        DBMS_OUTPUT.PUT_LINE('Muestra ' || v_contador || ': ' || v_columnas(v_contador));
        v_contador := v_contador + 1;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('=== FIN DEL REPORTE ===');
    
END;

-- FUNCTION verificar_integridad_pais
CREATE OR REPLACE FUNCTION verificar_integridad_pais(
    p_pais IN VARCHAR2
) RETURN VARCHAR2 IS
    v_population_cero NUMBER;
    v_gdp_cero NUMBER;
    v_anios_duplicados NUMBER;
    v_total_registros NUMBER;
    v_score NUMBER := 0;
    v_estado VARCHAR2(50);
    v_contador NUMBER := 1;
    
BEGIN
    SELECT COUNT(*) INTO v_total_registros FROM owid_energy_data WHERE country = p_pais;
    
    IF v_total_registros = 0 THEN
        RETURN 'Pais no encontrado';
    END IF;
    
    -- WHILE LOOP
    v_contador := 1;
    WHILE v_contador <= 3 LOOP
    
        CASE v_contador
            WHEN 1 THEN
                SELECT COUNT(*) INTO v_population_cero FROM owid_energy_data 
                WHERE country = p_pais AND population = 0;
                IF v_population_cero = 0 THEN 
                    v_score := v_score + 33;
                END IF;
                
            WHEN 2 THEN
                SELECT COUNT(*) INTO v_gdp_cero FROM owid_energy_data 
                WHERE country = p_pais AND gdp = 0;
                IF v_gdp_cero = 0 THEN 
                    v_score := v_score + 33;
                END IF;
                
            WHEN 3 THEN
                SELECT COUNT(*) INTO v_anios_duplicados FROM (
                    SELECT year, COUNT(*) FROM owid_energy_data
                    WHERE country = p_pais GROUP BY year HAVING COUNT(*) > 1
                );
                IF v_anios_duplicados = 0 THEN 
                    v_score := v_score + 34;
                END IF;
                
        END CASE;
        
        v_contador := v_contador + 1;
    END LOOP;
    
    -- BASIC LOOP con EXIT
    v_contador := 1;
    LOOP
        IF v_score >= 90 THEN
            v_estado := 'Datos completos y consistentes';
            EXIT;
        ELSIF v_score >= 60 THEN
            v_estado := 'Datos con ausencias parciales';
            EXIT;
        ELSE
            v_estado := 'Datos inconsistentes o incompletos';
            EXIT;
        END IF;
    END LOOP;
    
    RETURN v_estado || ' (Score: ' || v_score || '%)';
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error en verificacion';
END;