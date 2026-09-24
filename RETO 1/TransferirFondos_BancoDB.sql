-- ============================================================
-- RETO: Transferencia Bancaria Segura con Procedimientos Almacenados
-- Base de datos: BancoDB
-- Versión combinada: códigos numéricos del enunciado (200/400/401/500)
-- + validaciones extra (cuenta inexistente, cuenta origen = destino)
-- + mensaje descriptivo + titular de origen (Desafío Extra)
-- ============================================================

-- ------------------------------------------------------------
-- PASO 1: Crear la base de datos
-- ------------------------------------------------------------
DROP DATABASE IF EXISTS BancoDB;
CREATE DATABASE BancoDB;
USE BancoDB;

-- ------------------------------------------------------------
-- PASO 2: Crear las tablas
-- ------------------------------------------------------------
CREATE TABLE cuentas (
    id_cuenta INT PRIMARY KEY,
    titular   VARCHAR(100),
    saldo     DECIMAL(10,2)
);

-- historial_transferencias funciona como tabla de auditoría:
-- guarda cada intento, su código de respuesta, mensaje y el
-- usuario responsable (Desafío Extra).
CREATE TABLE historial_transferencias (
    id_transferencia    INT AUTO_INCREMENT PRIMARY KEY,
    cuenta_origen        INT,
    cuenta_destino        INT,
    monto                DECIMAL(10,2),
    codigo_respuesta     INT,
    mensaje              VARCHAR(255),
    usuario_responsable  VARCHAR(100),
    fecha                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- PASO 3: Insertar datos de prueba
-- ------------------------------------------------------------
INSERT INTO cuentas (id_cuenta, titular, saldo) VALUES
    (1, 'Ana López', 5000.00),
    (2, 'Carlos Pérez', 3000.00);

-- ------------------------------------------------------------
-- PASO 4: Procedimiento TransferirFondos
-- IMPORTANTE: sin líneas en blanco dentro del BEGIN...END para
-- evitar que DBeaver corte la sentencia si tiene activada la
-- opción "Blank line as statement delimiter".
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS TransferirFondos;

DELIMITER $$

CREATE PROCEDURE TransferirFondos(
    IN  p_origen              INT,
    IN  p_destino              INT,
    IN  p_monto                DECIMAL(10,2),
    IN  p_usuario_responsable  VARCHAR(100),
    OUT p_codigo_respuesta     INT,
    OUT p_titular_origen       VARCHAR(100),
    OUT p_mensaje              VARCHAR(255)
)
BEGIN
    DECLARE v_saldo_origen DECIMAL(10,2);
    -- Red de seguridad: cualquier error inesperado de la BD
    -- revierte todo y responde con código 500.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_codigo_respuesta = 500;
        SET p_mensaje = 'Error: ocurrió un problema inesperado en la base de datos. Operación revertida.';
        INSERT INTO historial_transferencias
            (cuenta_origen, cuenta_destino, monto, codigo_respuesta, mensaje, usuario_responsable)
        VALUES
            (p_origen, p_destino, p_monto, 500, p_mensaje, p_usuario_responsable);
    END;
    SET p_titular_origen = NULL;
    IF p_monto <= 0 THEN
        SET p_codigo_respuesta = 401;
        SET p_mensaje = 'Error: el monto debe ser mayor que cero.';
        INSERT INTO historial_transferencias
            (cuenta_origen, cuenta_destino, monto, codigo_respuesta, mensaje, usuario_responsable)
        VALUES
            (p_origen, p_destino, p_monto, 401, p_mensaje, p_usuario_responsable);
    ELSEIF p_origen = p_destino THEN
        SET p_codigo_respuesta = 400;
        SET p_mensaje = 'Error: la cuenta de origen y destino no pueden ser la misma.';
        INSERT INTO historial_transferencias
            (cuenta_origen, cuenta_destino, monto, codigo_respuesta, mensaje, usuario_responsable)
        VALUES
            (p_origen, p_destino, p_monto, 400, p_mensaje, p_usuario_responsable);
    ELSE
        START TRANSACTION;
        SELECT titular, saldo INTO p_titular_origen, v_saldo_origen
            FROM cuentas WHERE id_cuenta = p_origen FOR UPDATE;
        IF v_saldo_origen IS NULL THEN
            ROLLBACK;
            SET p_codigo_respuesta = 400;
            SET p_mensaje = 'Error: la cuenta de origen no existe.';
            INSERT INTO historial_transferencias
                (cuenta_origen, cuenta_destino, monto, codigo_respuesta, mensaje, usuario_responsable)
            VALUES
                (p_origen, p_destino, p_monto, 400, p_mensaje, p_usuario_responsable);
        ELSEIF NOT EXISTS (SELECT 1 FROM cuentas WHERE id_cuenta = p_destino) THEN
            ROLLBACK;
            SET p_codigo_respuesta = 400;
            SET p_mensaje = 'Error: la cuenta de destino no existe.';
            INSERT INTO historial_transferencias
                (cuenta_origen, cuenta_destino, monto, codigo_respuesta, mensaje, usuario_responsable)
            VALUES
                (p_origen, p_destino, p_monto, 400, p_mensaje, p_usuario_responsable);
        ELSEIF v_saldo_origen < p_monto THEN
            ROLLBACK;
            SET p_codigo_respuesta = 400;
            SET p_mensaje = 'Error: saldo insuficiente para realizar la transferencia.';
            INSERT INTO historial_transferencias
                (cuenta_origen, cuenta_destino, monto, codigo_respuesta, mensaje, usuario_responsable)
            VALUES
                (p_origen, p_destino, p_monto, 400, p_mensaje, p_usuario_responsable);
        ELSE
            UPDATE cuentas SET saldo = saldo - p_monto WHERE id_cuenta = p_origen;
            UPDATE cuentas SET saldo = saldo + p_monto WHERE id_cuenta = p_destino;
            SET p_codigo_respuesta = 200;
            SET p_mensaje = 'Transferencia realizada con éxito.';
            INSERT INTO historial_transferencias
                (cuenta_origen, cuenta_destino, monto, codigo_respuesta, mensaje, usuario_responsable)
            VALUES
                (p_origen, p_destino, p_monto, 200, p_mensaje, p_usuario_responsable);
            COMMIT;
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- PASO 5: PRUEBAS
-- Cada bloque muestra el nombre de la prueba junto al resultado
-- ============================================================

-- ------------------------------------------------------------
-- PRUEBA 1: Transferencia exitosa (Ana López -> Carlos Pérez, 1000)
-- ------------------------------------------------------------
CALL TransferirFondos(1, 2, 1000.00, 'admin_prueba1', @codigo1, @titular1, @mensaje1);
SELECT 'Prueba 1 - Transferencia exitosa' AS Prueba,
       @codigo1 AS codigo_respuesta, @titular1 AS titular_origen, @mensaje1 AS mensaje;

-- ------------------------------------------------------------
-- PRUEBA 2: Saldo insuficiente (Carlos Pérez -> Ana López, 999999)
-- ------------------------------------------------------------
CALL TransferirFondos(2, 1, 999999.00, 'admin_prueba2', @codigo2, @titular2, @mensaje2);
SELECT 'Prueba 2 - Saldo insuficiente' AS Prueba,
       @codigo2 AS codigo_respuesta, @titular2 AS titular_origen, @mensaje2 AS mensaje;

-- ------------------------------------------------------------
-- PRUEBA 3 (Desafío Extra): Monto inválido (0)
-- ------------------------------------------------------------
CALL TransferirFondos(1, 2, 0.00, 'admin_prueba3', @codigo3, @titular3, @mensaje3);
SELECT 'Prueba 3 - Monto inválido (Desafío Extra)' AS Prueba,
       @codigo3 AS codigo_respuesta, @titular3 AS titular_origen, @mensaje3 AS mensaje;

-- ------------------------------------------------------------
-- PRUEBA 4: Cuenta destino inexistente
-- ------------------------------------------------------------
CALL TransferirFondos(1, 99, 100.00, 'admin_prueba4', @codigo4, @titular4, @mensaje4);
SELECT 'Prueba 4 - Cuenta destino inexistente' AS Prueba,
       @codigo4 AS codigo_respuesta, @titular4 AS titular_origen, @mensaje4 AS mensaje;

-- ------------------------------------------------------------
-- PRUEBA 5: Cuenta origen igual a cuenta destino
-- ------------------------------------------------------------
CALL TransferirFondos(1, 1, 100.00, 'admin_prueba5', @codigo5, @titular5, @mensaje5);
SELECT 'Prueba 5 - Origen y destino iguales' AS Prueba,
       @codigo5 AS codigo_respuesta, @titular5 AS titular_origen, @mensaje5 AS mensaje;

-- ------------------------------------------------------------
-- PRUEBA 6: Saldos finales y auditoría completa
-- ------------------------------------------------------------
SELECT 'Prueba 6 - Saldos finales' AS Prueba, * FROM cuentas;
SELECT 'Prueba 6 - Auditoría de operaciones' AS Prueba, * FROM historial_transferencias;