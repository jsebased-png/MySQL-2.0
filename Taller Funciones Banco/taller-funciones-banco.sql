-- =============================================================================
-- SOLUCIONARIO TALLER 2: FUNCIONES DEFINIDAS POR EL USUARIO (MYSQL)
-- Dominio: Sistema Bancario ("BancoTaller")
-- =============================================================================

USE BancoDB;

-- -----------------------------------------------------------------------------
-- EJERCICIO 1: Cálculo del Impuesto 4x1000 (GMF)
-- Característica: DETERMINISTIC (No consulta tablas, cálculo matemático directo)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS CalcularImpuestoGMF;

DELIMITER //

CREATE FUNCTION CalcularImpuestoGMF(
    p_monto DECIMAL(12,2),
    p_es_exenta BOOLEAN
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE v_impuesto DECIMAL(12,2);
    
    IF p_es_exenta THEN
        SET v_impuesto = 0.00;
    ELSE
        -- 4x1000 equivale al 0.4% (monto * 0.004)
        SET v_impuesto = p_monto * 0.004;
    END IF;
    
    RETURN v_impuesto;
END //

DELIMITER ;

-- Pruebas Ejercicio 1:
-- SELECT CalcularImpuestoGMF(1000000.00, FALSE) AS Impuesto_4x1000; -- Retorna: 4000.00
-- SELECT CalcularImpuestoGMF(1000000.00, TRUE)  AS Impuesto_Exento; -- Retorna: 0.00


-- -----------------------------------------------------------------------------
-- EJERCICIO 2: Total de Retiros en Rango de Fechas
-- Caracteristica: READS SQL DATA (Consulta la tabla Transacciones)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ObtenerTotalRetirosPeriodo;

DELIMITER //

CREATE FUNCTION ObtenerTotalRetirosPeriodo(
    p_cuenta_id INT,
    p_fecha_inicio DATE,
    p_fecha_fin DATE
)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_total_retiros DECIMAL(12,2);
    
    SELECT IFNULL(SUM(monto), 0.00)
    INTO v_total_retiros
    FROM Transacciones
    WHERE cuenta_id = p_cuenta_id
      AND tipo_transaccion = 'Retiro'
      AND DATE(fecha) BETWEEN p_fecha_inicio AND p_fecha_fin;
      
    RETURN v_total_retiros;
END //

DELIMITER ;

-- Pruebas Ejercicio 2:
-- SELECT ObtenerTotalRetirosPeriodo(1, '2026-01-01', '2026-01-31') AS Total_Retiros_Enero;


-- -----------------------------------------------------------------------------
-- EJERCICIO 3: Proyección de Rendimientos de CDT con Bucle (WHILE)
-- Característica: DETERMINISTIC (Interés compuesto con estructura iterativa)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ProyectarRendimientoCDT;

DELIMITER //

CREATE FUNCTION ProyectarRendimientoCDT(
    p_capital DECIMAL(12,2),
    p_tasa_anual DECIMAL(5,2),
    p_anios INT
)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE v_capital_acumulado DECIMAL(12,2);
    DECLARE v_contador INT DEFAULT 1;
    
    SET v_capital_acumulado = p_capital;
    
    WHILE v_contador <= p_anios DO
        SET v_capital_acumulado = v_capital_acumulado * (1 + (p_tasa_anual / 100.0));
        SET v_contador = v_contador + 1;
    END WHILE;
    
    RETURN v_capital_acumulado;
END //

DELIMITER ;

-- Pruebas Ejercicio 3:
-- SELECT ProyectarRendimientoCDT(10000000.00, 10.50, 3) AS Capital_Proyectado_3Anios;


-- -----------------------------------------------------------------------------
-- EJERCICIO 4: Evaluación de Score Crediticio (Reto Integrador)
-- Característica: READS SQL DATA (Consulta múltiples métricas y aplica reglas)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS EvaluarElegibilidadCredito;

DELIMITER //

CREATE FUNCTION EvaluarElegibilidadCredito(
    p_cuenta_id INT
)
RETURNS VARCHAR(30)
READS SQL DATA
BEGIN
    DECLARE v_saldo DECIMAL(12,2);
    DECLARE v_total_retiros DECIMAL(12,2);
    DECLARE v_resultado VARCHAR(30);
    
    -- Consultar saldo actual de la cuenta
    SELECT saldo INTO v_saldo
    FROM Cuentas
    WHERE cuenta_id = p_cuenta_id;
    
    -- Si la cuenta no existe en el sistema
    IF v_saldo IS NULL THEN
        RETURN 'Cuenta Inexistente';
    END IF;
    
    -- Consultar total histórico de retiros
    SELECT IFNULL(SUM(monto), 0.00)
    INTO v_total_retiros
    FROM Transacciones
    WHERE cuenta_id = p_cuenta_id 
      AND tipo_transaccion = 'Retiro';
      
    -- Evaluación de reglas de negocio
    IF v_saldo >= 2000000.00 AND v_total_retiros <= (v_saldo * 2) THEN
        SET v_resultado = 'Aprobado';
    ELSEIF v_saldo >= 500000.00 AND v_saldo < 2000000.00 THEN
        SET v_resultado = 'Requiere Aval';
    ELSE
        SET v_resultado = 'Rechazado';
    END IF;
    
    RETURN v_resultado;
END //

DELIMITER ;

-- Pruebas Ejercicio 4 en DML:
-- SELECT cuenta_id, titular, saldo, EvaluarElegibilidadCredito(cuenta_id) AS Estado_Credito FROM Cuentas;
