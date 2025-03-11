

Procedimientos almacenados apuntes


DELIMITER $$

-- 1. Insertar un nuevo presupuesto
CREATE PROCEDURE sp_insert_presupuesto(
    IN p_nombre VARCHAR(100),
    IN p_monto DECIMAL(10,2),
    IN p_fecha DATE
)
BEGIN
    INSERT INTO presupuestos (nombre, monto, fecha)
    VALUES (p_nombre, p_monto, p_fecha);
END$$

-- 2. Actualizar un presupuesto existente
CREATE PROCEDURE sp_update_presupuesto(
    IN p_id INT,
    IN p_nombre VARCHAR(100),
    IN p_monto DECIMAL(10,2)
)
BEGIN
    UPDATE presupuestos
    SET nombre = p_nombre,
        monto = p_monto
    WHERE id = p_id;
END$$

-- 3. Eliminar un presupuesto
CREATE PROCEDURE sp_delete_presupuesto(
    IN p_id INT
)
BEGIN
    DELETE FROM presupuestos
    WHERE id = p_id;
END$$

-- 4. Obtener detalles de un presupuesto
CREATE PROCEDURE sp_get_presupuesto(
    IN p_id INT
)
BEGIN
    SELECT * FROM presupuestos
    WHERE id = p_id;
END$$

-- 5. Listar todos los presupuestos
CREATE PROCEDURE sp_list_presupuestos()
BEGIN
    SELECT * FROM presupuestos;
END$$

DELIMITER ;




---

FUNCIONES


DELIMITER $$

-- 1. Función para obtener el total de gastos de un presupuesto
CREATE FUNCTION fn_total_gastos(p_presupuesto_id INT) RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(10,2);
    SELECT SUM(monto) INTO total
    FROM gastos
    WHERE presupuesto_id = p_presupuesto_id;
    RETURN IFNULL(total, 0);
END$$

-- 2. Función para calcular el balance (presupuesto - gastos)
CREATE FUNCTION fn_calcular_balance(p_presupuesto_id INT) RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE presupuesto DECIMAL(10,2);
    DECLARE gastos_tot DECIMAL(10,2);
    SELECT monto INTO presupuesto
    FROM presupuestos
    WHERE id = p_presupuesto_id;
    SET gastos_tot = fn_total_gastos(p_presupuesto_id);
    RETURN presupuesto - gastos_tot;
END$$

-- 3. Función para formatear un valor monetario
CREATE FUNCTION fn_format_currency(p_value DECIMAL(10,2)) RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    RETURN CONCAT('$', FORMAT(p_value, 2));
END$$

-- 4. Función para extraer el año de una fecha
CREATE FUNCTION fn_get_year(p_date DATE) RETURNS INT
DETERMINISTIC
BEGIN
    RETURN YEAR(p_date);
END$$

-- 5. Función para calcular el porcentaje gastado respecto al presupuesto
CREATE FUNCTION fn_percentage_spent(p_presupuesto_id INT) RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE presupuesto DECIMAL(10,2);
    DECLARE gastos_tot DECIMAL(10,2);
    SELECT monto INTO presupuesto
    FROM presupuestos
    WHERE id = p_presupuesto_id;
    SET gastos_tot = fn_total_gastos(p_presupuesto_id);
    IF presupuesto = 0 THEN
        RETURN 0;
    ELSE
        RETURN (gastos_tot / presupuesto) * 100;
    END IF;
END$$

DELIMITER ;




-- Triggers



DELIMITER $$

-- 1. Trigger antes de insertar un presupuesto para validar que el monto no sea negativo
CREATE TRIGGER trg_before_insert_presupuesto
BEFORE INSERT ON presupuestos
FOR EACH ROW
BEGIN
    IF NEW.monto < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El monto no puede ser negativo';
    END IF;
END$$

-- 2. Trigger después de actualizar un presupuesto para registrar la acción
CREATE TRIGGER trg_after_update_presupuesto
AFTER UPDATE ON presupuestos
FOR EACH ROW
BEGIN
    INSERT INTO log_presupuestos (presupuesto_id, accion, fecha)
    VALUES (NEW.id, 'ACTUALIZADO', NOW());
END$$

-- 3. Trigger antes de eliminar un presupuesto para evitar borrar aquellos con gastos asociados
CREATE TRIGGER trg_before_delete_presupuesto
BEFORE DELETE ON presupuestos
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM gastos WHERE presupuesto_id = OLD.id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar un presupuesto con gastos asociados';
    END IF;
END$$

-- 4. Trigger después de insertar un gasto para actualizar el monto restante del presupuesto
CREATE TRIGGER trg_after_insert_gasto
AFTER INSERT ON gastos
FOR EACH ROW
BEGIN
    UPDATE presupuestos
    SET monto = monto - NEW.monto
    WHERE id = NEW.presupuesto_id;
END$$

-- 5. Trigger antes de actualizar un ingreso para validar que el monto no sea negativo
CREATE TRIGGER trg_before_update_ingreso
BEFORE UPDATE ON ingresos
FOR EACH ROW
BEGIN
    IF NEW.monto < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El monto del ingreso no puede ser negativo';
    END IF;
END$$

DELIMITER ;






-- eventos


DELIMITER $$

-- 1. Evento diario para insertar un resumen en la tabla resumen_diario
CREATE EVENT event_daily_summary
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    INSERT INTO resumen_diario (fecha, total_presupuestos, total_gastos)
    SELECT CURDATE(), COUNT(*), (SELECT SUM(monto) FROM gastos)
    FROM presupuestos;
END$$

-- 2. Evento diario para actualizar el estado de presupuestos antiguos
CREATE EVENT event_update_budget_status
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    UPDATE presupuestos
    SET estado = 'CERRADO'
    WHERE fecha < DATE_SUB(CURDATE(), INTERVAL 1 YEAR);
END$$

-- 3. Evento semanal para limpiar registros antiguos de la tabla log_presupuestos
CREATE EVENT event_cleanup_old_records
ON SCHEDULE EVERY 1 WEEK
DO
BEGIN
    DELETE FROM log_presupuestos
    WHERE fecha < DATE_SUB(CURDATE(), INTERVAL 1 MONTH);
END$$

-- 4. Evento mensual para generar un reporte y almacenar datos en reportes_mensuales
CREATE EVENT event_monthly_report
ON SCHEDULE EVERY 1 MONTH
DO
BEGIN
    INSERT INTO reportes_mensuales (mes, total_presupuestos, total_gastos)
    SELECT DATE_FORMAT(CURDATE(), '%Y-%m'), COUNT(*), (SELECT SUM(monto) FROM gastos)
    FROM presupuestos;
END$$

-- 5. Evento diario para sincronizar datos externos (se asume que existe un procedimiento de sincronización)
CREATE EVENT event_sync_external_data
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    CALL sp_sync_externa(); -- Procedimiento que deberás definir para la sincronización
END$$

DELIMITER ;


