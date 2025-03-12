
-- funciones


DELIMITER $$

CREATE FUNCTION TotalIngresosCliente(ClienteID INT, Año INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total_ingresos DECIMAL(10,2);
    
    SELECT COALESCE(SUM(total), 0) 
    INTO total_ingresos
    FROM pago
    WHERE id_cliente = ClienteID AND YEAR(fecha_pago) = Año;

    RETURN total_ingresos;
END $$

DELIMITER ;





DELIMITER $$

CREATE FUNCTION IngresosPorCategoria(CategoriaID INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total_ingresos DECIMAL(10,2);
    
    SELECT COALESCE(SUM(p.total), 0)
    INTO total_ingresos
    FROM pago p
    JOIN alquiler a ON p.id_alquiler = a.id_alquiler
    JOIN inventario i ON a.id_inventario = i.id_inventario
    JOIN pelicula_actor pa ON i.id_pelicula = pa.id_pelicula
    JOIN pelicula ON i.id_pelicula = pelicula.id_pelicula
    JOIN categoria c ON c.id_categoria = CategoriaID
    WHERE c.id_categoria = CategoriaID;

    RETURN total_ingresos;
END $$

DELIMITER ;





DELIMITER $$

CREATE FUNCTION EsClienteVIP(ClienteID INT) 
RETURNS TINYINT
DETERMINISTIC
BEGIN
    DECLARE total_ingresos DECIMAL(10,2);
    DECLARE num_alquileres INT;
    DECLARE es_vip TINYINT;

    SELECT COUNT(*), COALESCE(SUM(p.total), 0)
    INTO num_alquileres, total_ingresos
    FROM pago p
    JOIN alquiler a ON p.id_alquiler = a.id_alquiler
    WHERE a.id_cliente = ClienteID;

    IF num_alquileres >= 40 AND total_ingresos >= 500 THEN
        SET es_vip = 1; -- Es VIP
    ELSE
        SET es_vip = 0; -- No es VIP
    END IF;

    RETURN es_vip;
END $$

DELIMITER ;




-- ttriggers


-- 1. Agregar columna total_alquileres a la tabla empleado (si aún no existe)
ALTER TABLE empleado ADD total_alquileres INT DEFAULT 0;

--------------------------------------------------------------------------------
-- 2. Trigger: ActualizarTotalAlquileresEmpleado
--    Al insertar un registro en "alquiler", se incrementa el total de alquileres 
--    gestionados por el empleado correspondiente.
--------------------------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER tr_actualizar_total_alquileres_empleado
AFTER INSERT ON alquiler
FOR EACH ROW
BEGIN
    UPDATE empleado
    SET total_alquileres = total_alquileres + 1
    WHERE id_empleado = NEW.id_empleado;
END $$
DELIMITER ;

--------------------------------------------------------------------------------
-- 3. Crear tabla de auditoría para clientes
--------------------------------------------------------------------------------
CREATE TABLE auditoria_cliente (
  id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
  id_cliente INT,
  fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
  accion VARCHAR(50),
  datos_anteriores TEXT,
  datos_nuevos TEXT
);

--------------------------------------------------------------------------------
-- 4. Trigger: AuditarActualizacionCliente
--    Cada vez que se actualiza un registro en "cliente", se registra la acción
--    en la tabla "auditoria_cliente" con datos anteriores y nuevos.
--------------------------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER tr_auditar_actualizacion_cliente
AFTER UPDATE ON cliente
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_cliente(id_cliente, accion, datos_anteriores, datos_nuevos)
    VALUES (
        NEW.id_cliente,
        'UPDATE',
        CONCAT('nombre:', OLD.nombre, ', apellidos:', OLD.apellidos, ', email:', OLD.email),
        CONCAT('nombre:', NEW.nombre, ', apellidos:', NEW.apellidos, ', email:', NEW.email)
    );
END $$
DELIMITER ;

--------------------------------------------------------------------------------
-- 5. Crear tabla para historial de costos de alquiler de películas
--------------------------------------------------------------------------------
CREATE TABLE historial_costo_pelicula (
  id_historial INT AUTO_INCREMENT PRIMARY KEY,
  id_pelicula INT,
  fecha_cambio DATETIME DEFAULT CURRENT_TIMESTAMP,
  costo_anterior DECIMAL(4,2),
  costo_nuevo DECIMAL(4,2)
);

--------------------------------------------------------------------------------
-- 6. Trigger: RegistrarHistorialDeCosto
--    Cada vez que se actualiza el costo de alquiler (rental_rate) en "pelicula",
--    se guarda el historial del cambio.
--------------------------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER tr_registrar_historial_costo
AFTER UPDATE ON pelicula
FOR EACH ROW
BEGIN
    IF OLD.rental_rate <> NEW.rental_rate THEN
        INSERT INTO historial_costo_pelicula (id_pelicula, costo_anterior, costo_nuevo)
        VALUES (NEW.id_pelicula, OLD.rental_rate, NEW.rental_rate);
    END IF;
END $$
DELIMITER ;

--------------------------------------------------------------------------------
-- 7. Crear tabla de notificaciones para eliminaciones de alquiler
--------------------------------------------------------------------------------
CREATE TABLE notificaciones (
  id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
  id_alquiler INT,
  mensaje VARCHAR(255),
  fecha DATETIME DEFAULT CURRENT_TIMESTAMP
);

--------------------------------------------------------------------------------
-- 8. Trigger: NotificarEliminacionAlquiler
--    Cada vez que se elimina un registro de "alquiler", se registra una notificación.
--------------------------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER tr_notificar_eliminacion_alquiler
AFTER DELETE ON alquiler
FOR EACH ROW
BEGIN
    INSERT INTO notificaciones (id_alquiler, mensaje)
    VALUES (OLD.id_alquiler, CONCAT('Se eliminó el alquiler con ID: ', OLD.id_alquiler));
END $$
DELIMITER ;

--------------------------------------------------------------------------------
-- 9. Trigger: RestringirAlquilerConSaldoPendiente
--    Antes de insertar un nuevo alquiler, se verifica si el cliente tiene alquileres 
--    sin pago (saldo pendiente). Si es así, se impide la inserción.
--------------------------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER tr_restringir_alquiler_con_saldo_pendiente
BEFORE INSERT ON alquiler
FOR EACH ROW
BEGIN
    DECLARE pendientes INT;
    
    SELECT COUNT(*) INTO pendientes
    FROM alquiler a 
    LEFT JOIN pago p ON a.id_alquiler = p.id_alquiler
    WHERE a.id_cliente = NEW.id_cliente AND p.id_pago IS NULL;
    
    IF pendientes > 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'El cliente tiene saldo pendiente y no puede realizar un nuevo alquiler.';
    END IF;
END $$
DELIMITER ;





USE sakila;
-- Asegúrate de que el event scheduler esté activado:
SET GLOBAL event_scheduler = ON;

---------------------------------------------------------------------------
-- 0. Tablas y columnas auxiliares necesarias
---------------------------------------------------------------------------

-- 0.1. Crear tabla para almacenar el informe mensual de alquileres
CREATE TABLE IF NOT EXISTS informe_alquileres_mensual (
    id_informe INT AUTO_INCREMENT PRIMARY KEY,
    mes INT,
    anio INT,
    total_alquileres INT,
    total_ingresos DECIMAL(10,2),
    fecha_generacion DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 0.2. Agregar columna "saldo_pendiente" en la tabla cliente (si no existe)
ALTER TABLE cliente 
    ADD COLUMN IF NOT EXISTS saldo_pendiente DECIMAL(10,2) DEFAULT 0;

-- 0.3. Crear tabla para almacenar alertas sobre películas no alquiladas
CREATE TABLE IF NOT EXISTS alertas_peliculas (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    id_pelicula INT,
    mensaje VARCHAR(255),
    fecha_alerta DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_pelicula) REFERENCES pelicula(id_pelicula)
);

-- 0.4. Suponemos que ya existe la tabla auditoría (por ejemplo, auditoria_cliente) de auditoría
--     Si no existe, deberás crearla. Aquí se asume que la tabla "auditoria_cliente" ya fue creada en otro proceso.

-- 0.5. Para actualizar las categorías populares se requiere conocer la relación entre película y categoría.
-- Se asume la existencia de la tabla "pelicula_categoria" y se agrega una columna "cantidad_alquileres" en "categoria".
CREATE TABLE IF NOT EXISTS pelicula_categoria (
    id_pelicula INT,
    id_categoria INT,
    PRIMARY KEY (id_pelicula, id_categoria),
    FOREIGN KEY (id_pelicula) REFERENCES pelicula(id_pelicula),
    FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria)
);

ALTER TABLE categoria 
    ADD COLUMN IF NOT EXISTS cantidad_alquileres INT DEFAULT 0;

---------------------------------------------------------------------------
-- 1. InformeAlquileresMensual
-- Genera un informe mensual de alquileres y lo almacena automáticamente.
---------------------------------------------------------------------------
DELIMITER $$
CREATE EVENT ev_informe_alquileres_mensual
ON SCHEDULE EVERY 1 MONTH
STARTS '2025-04-01 00:00:00'
DO
BEGIN
    INSERT INTO informe_alquileres_mensual (mes, anio, total_alquileres, total_ingresos, fecha_generacion)
    SELECT 
        MONTH(CURRENT_DATE - INTERVAL 1 MONTH) AS mes,
        YEAR(CURRENT_DATE - INTERVAL 1 MONTH) AS anio,
        COUNT(*) AS total_alquileres,
        COALESCE(SUM(p.total), 0) AS total_ingresos,
        NOW()
    FROM alquiler a
    LEFT JOIN pago p ON a.id_alquiler = p.id_alquiler
    WHERE MONTH(a.fecha_alquiler) = MONTH(CURRENT_DATE - INTERVAL 1 MONTH)
      AND YEAR(a.fecha_alquiler) = YEAR(CURRENT_DATE - INTERVAL 1 MONTH);
END $$
DELIMITER ;

---------------------------------------------------------------------------
-- 2. ActualizarSaldoPendienteCliente
-- Actualiza los saldos pendientes de los clientes al final de cada mes.
-- Se considera pendiente cada alquiler sin un pago asociado.
---------------------------------------------------------------------------
DELIMITER $$
CREATE EVENT ev_actualizar_saldo_pendiente_cliente
ON SCHEDULE EVERY 1 MONTH
STARTS '2025-04-01 01:00:00'
DO
BEGIN
    UPDATE cliente c
    SET c.saldo_pendiente = (
        SELECT COALESCE(SUM(pel.rental_rate),0)
        FROM alquiler a
        JOIN inventario i ON a.id_inventario = i.id_inventario
        JOIN pelicula pel ON i.id_pelicula = pel.id_pelicula
        LEFT JOIN pago p ON a.id_alquiler = p.id_alquiler
        WHERE a.id_cliente = c.id_cliente AND p.id_pago IS NULL
    );
END $$
DELIMITER ;

---------------------------------------------------------------------------
-- 3. AlertaPeliculasNoAlquiladas
-- Envía una alerta (registra en la tabla alertas_peliculas) cuando una película no ha sido alquilada en el último año.
---------------------------------------------------------------------------
DELIMITER $$
CREATE EVENT ev_alerta_peliculas_no_alquiladas
ON SCHEDULE EVERY 1 DAY
STARTS '2025-04-01 02:00:00'
DO
BEGIN
    INSERT INTO alertas_peliculas (id_pelicula, mensaje, fecha_alerta)
    SELECT 
        p.id_pelicula, 
        CONCAT('La película "', p.titulo, '" no ha sido alquilada en el último año.') AS mensaje,
        NOW()
    FROM pelicula p
    WHERE NOT EXISTS (
        SELECT 1 
        FROM alquiler a
        JOIN inventario i ON a.id_inventario = i.id_inventario
        WHERE i.id_pelicula = p.id_pelicula 
          AND a.fecha_alquiler >= DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR)
    );
END $$
DELIMITER ;

---------------------------------------------------------------------------
-- 4. LimpiarAuditoriaCada6Meses
-- Borra los registros antiguos de auditoría (en este ejemplo, de auditoria_cliente) cada seis meses.
---------------------------------------------------------------------------
DELIMITER $$
CREATE EVENT ev_limpiar_auditoria
ON SCHEDULE EVERY 6 MONTH
STARTS '2025-04-01 03:00:00'
DO
BEGIN
    DELETE FROM auditoria_cliente
    WHERE fecha < DATE_SUB(CURRENT_DATE, INTERVAL 6 MONTH);
END $$
DELIMITER ;

---------------------------------------------------------------------------
-- 5. ActualizarCategoriasPopulares
-- Actualiza la lista de categorías más alquiladas al final de cada mes.
-- Se actualiza la columna "cantidad_alquileres" de la tabla categoria, basándose en la cantidad
-- de alquileres de las películas relacionadas.
---------------------------------------------------------------------------
DELIMITER $$
CREATE EVENT ev_actualizar_categorias_populares
ON SCHEDULE EVERY 1 MONTH
STARTS '2025-04-01 04:00:00'
DO
BEGIN
    -- Reiniciar los contadores a 0
    UPDATE categoria SET cantidad_alquileres = 0;
    
    -- Actualizar la cantidad de alquileres para cada categoría
    UPDATE categoria c
    JOIN (
        SELECT pc.id_categoria, COUNT(*) AS total_alquileres



USE sakila;

---------------------------------------------------------------------
-- 1. Encuentra el cliente que ha realizado la mayor cantidad de alquileres
--    en los últimos 6 meses.
---------------------------------------------------------------------
SELECT 
    id_cliente, 
    COUNT(*) AS total_alquileres
FROM alquiler
WHERE fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY id_cliente
ORDER BY total_alquileres DESC
LIMIT 1;

---------------------------------------------------------------------
-- 2. Lista las cinco películas más alquiladas durante el último año.
---------------------------------------------------------------------
SELECT 
    p.id_pelicula, 
    p.titulo, 
    COUNT(*) AS total_alquileres
FROM alquiler a
JOIN inventario i ON a.id_inventario = i.id_inventario
JOIN pelicula p ON i.id_pelicula = p.id_pelicula
WHERE a.fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY p.id_pelicula, p.titulo
ORDER BY total_alquileres DESC
LIMIT 5;

---------------------------------------------------------------------
-- 3. Obtenga el total de ingresos y la cantidad de alquileres realizados por 
--    cada categoría de película.
--    Se asume la existencia de la tabla "pelicula_categoria" que relaciona 
--    "pelicula" y "categoria".
---------------------------------------------------------------------
SELECT 
    c.id_categoria, 
    c.nombre, 
    COUNT(a.id_alquiler) AS total_alquileres,
    COALESCE(SUM(p.total), 0) AS total_ingresos
FROM categoria c
JOIN pelicula_categoria pc ON c.id_categoria = pc.id_categoria
JOIN inventario i ON pc.id_pelicula = i.id_pelicula
JOIN alquiler a ON i.id_inventario = a.id_inventario
LEFT JOIN pago p ON a.id_alquiler = p.id_alquiler
GROUP BY c.id_categoria, c.nombre;

---------------------------------------------------------------------
-- 4. Calcule el número total de clientes que han realizado alquileres 
--    por cada idioma disponible en un mes específico.
--    Reemplace :mes y :anio por los valores deseados.
---------------------------------------------------------------------
SELECT 
    idm.nombre AS idioma, 
    COUNT(DISTINCT a.id_cliente) AS total_clientes
FROM alquiler a
JOIN inventario inv ON a.id_inventario = inv.id_inventario
JOIN pelicula p ON inv.id_pelicula = p.id_pelicula
JOIN idioma idm ON p.id_idioma = idm.id_idioma
WHERE MONTH(a.fecha_alquiler) = :mes
  AND YEAR(a.fecha_alquiler) = :anio
GROUP BY idm.id_idioma, idm.nombre;

---------------------------------------------------------------------
-- 5. Encuentra a los clientes que han alquilado todas las películas de una
--    misma categoría.
---------------------------------------------------------------------
SELECT DISTINCT a.id_cliente
FROM alquiler a
JOIN inventario i ON a.id_inventario = i.id_inventario
JOIN pelicula_categoria pc ON i.id_pelicula = pc.id_pelicula
GROUP BY a.id_cliente, pc.id_categoria
HAVING COUNT(DISTINCT i.id_pelicula) = (
    SELECT COUNT(DISTINCT id_pelicula)
    FROM pelicula_categoria
    WHERE id_categoria = pc.id_categoria
);

---------------------------------------------------------------------
-- 6. Lista las tres ciudades con más clientes activos en el último trimestre.
--    Se considera activo a un cliente con activo = 1 y creado en los últimos 3 meses.
---------------------------------------------------------------------
SELECT 
    ci.nombre AS ciudad, 
    COUNT(*) AS total_clientes
FROM cliente cl
JOIN direccion d ON cl.id_direccion = d.id_direccion
JOIN ciudad ci ON d.id_ciudad = ci.id_ciudad
WHERE cl.activo = 1 
  AND cl.fecha_creacion >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
GROUP BY ci.id_ciudad, ci.nombre
ORDER BY total_clientes DESC
LIMIT 3;

---------------------------------------------------------------------
-- 7. Muestra las cinco categorías con menos alquileres registrados en el último año.
---------------------------------------------------------------------
SELECT 
    c.id_categoria, 
    c.nombre, 
    COUNT(a.id_alquiler) AS total_alquileres
FROM categoria c
JOIN pelicula_categoria pc ON c.id_categoria = pc.id_categoria
JOIN inventario i ON pc.id_pelicula = i.id_pelicula
JOIN alquiler a ON i.id_inventario = a.id_inventario
WHERE a.fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY c.id_categoria, c.nombre
ORDER BY total_alquileres ASC
LIMIT 5;

---------------------------------------------------------------------
-- 8. Calcula el promedio de días que un cliente tarda en devolver las películas
--    alquiladas.
---------------------------------------------------------------------
SELECT 
    id_cliente, 
    AVG(DATEDIFF(fecha_devolucion, fecha_alquiler)) AS promedio_dias
FROM alquiler
WHERE fecha_devolucion IS NOT NULL
GROUP BY id_cliente;

---------------------------------------------------------------------
-- 9. Encuentra los cinco empleados que gestionan más alquileres en la categoría de Acción.
--    Se asume que "Acción" es un valor en la columna "nombre" de la tabla "categoria".
---------------------------------------------------------------------
SELECT 
    e.id_empleado, 
    e.nombre, 
    e.apellidos, 
    COUNT(a.id_alquiler) AS total_alquileres
FROM alquiler a 
JOIN empleado e ON a.id_empleado = e.id_empleado
JOIN inventario i ON a.id_inventario = i.id_inventario
JOIN pelicula_categoria pc ON i.id_pelicula = pc.id_pelicula
JOIN categoria c ON pc.id_categoria = c.id_categoria
WHERE c.nombre = 'Acción'
GROUP BY e.id_empleado, e.nombre, e.apellidos
ORDER BY total_alquileres DESC
LIMIT 5;

---------------------------------------------------------------------
-- 10. Genera un informe de los clientes con alquileres más recurrentes.
---------------------------------------------------------------------
SELECT 
    cl.id_cliente, 
    cl.nombre, 
    cl.apellidos, 
    COUNT(a.id_alquiler) AS total_alquileres
FROM cliente cl
JOIN alquiler a ON cl.id_cliente = a.id_cliente
GROUP BY cl.id_cliente, cl.nombre, cl.apellidos
ORDER BY total_alquileres DESC;

---------------------------------------------------------------------
-- 11. Calcula el costo promedio de alquiler por idioma de las películas.
--    Se toma el valor de "rental_rate" de la tabla "pelicula" como costo de alquiler.
---------------------------------------------------------------------
SELECT 
    idm.nombre AS idioma, 
    AVG(p.rental_rate) AS costo_promedio
FROM pelicula p
JOIN idioma idm ON p.id_idioma = idm.id_idioma
GROUP BY idm.id_idioma, idm.nombre;

---------------------------------------------------------------------
-- 12. Lista las cinco películas con mayor duración alquiladas en el último año.
---------------------------------------------------------------------
SELECT 
    p.id_pelicula, 
    p.titulo, 
    p.duracion, 
    COUNT(a.id_alquiler) AS total_alquileres
FROM pelicula p
JOIN inventario i ON p.id_pelicula = i.id_pelicula
JOIN alquiler a ON i.id_inventario = a.id_inventario
WHERE a.fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY p.id_pelicula, p.titulo, p.duracion
ORDER BY p.duracion DESC
LIMIT 5;

---------------------------------------------------------------------
-- 13. Muestra los clientes que más alquilaron películas de Comedia.
--    Se asume que "Comedia" es un valor en la columna "nombre" de la tabla "categoria".
---------------------------------------------------------------------
SELECT 
    cl.id_cliente, 
    cl.nombre, 
    cl.apellidos, 
    COUNT(a.id_alquiler) AS total_alquileres
FROM cliente cl
JOIN alquiler a ON cl.id_cliente = a.id_cliente
JOIN inventario i ON a.id_inventario = i.id_inventario
JOIN pelicula_categoria pc ON i.id_pelicula = pc.id_pelicula
JOIN categoria c ON pc.id_categoria = c.id_categoria
WHERE c.nombre = 'Comedia'
GROUP BY cl.id_cliente, cl.nombre, cl.apellidos
ORDER BY total_alquileres DESC;

---------------------------------------------------------------------
-- 14. Encuentra la cantidad total de días alquilados por cada cliente en el último mes.
---------------------------------------------------------------------
SELECT 
    a.id_cliente, 
    SUM(DATEDIFF(a.fecha_devolucion, a.fecha_alquiler)) AS total_dias_alquilados
FROM alquiler a
WHERE a.fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
  AND a.fecha_devolucion IS NOT NULL
GROUP BY a.id_cliente;

---------------------------------------------------------------------
-- 15. Muestra el número de alquileres diarios en cada almacén durante el último trimestre.
---------------------------------------------------------------------
SELECT 
    alm.id_almacen, 
    DATE(a.fecha_alquiler) AS fecha, 
    COUNT(*) AS total_alquileres
FROM alquiler a
JOIN inventario i ON a.id_inventario = i.id_inventario
JOIN almacen alm ON i.id_almacen = alm.id_almacen
WHERE a.fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
GROUP BY alm.id_almacen, DATE(a.fecha_alquiler)
ORDER BY alm.id_almacen, fecha;

---------------------------------------------------------------------
-- 16. Calcule los ingresos totales generados por cada almacén en el último semestre.
---------------------------------------------------------------------
SELECT 
    alm.id_almacen, 
    SUM(p.total) AS ingresos_totales
FROM pago p
JOIN alquiler a ON p.id_alquiler = a.id_alquiler
JOIN inventario i ON a.id_inventario = i.id_inventario
JOIN almacen alm ON i.id_almacen = alm.id_almacen
WHERE p.fecha_pago >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY alm.id_almacen;

---------------------------------------------------------------------
-- 17. Encuentra el cliente que ha realizado el alquiler más caro en el último año.
---------------------------------------------------------------------
SELECT 
    a.id_cliente, 
    cl.nombre, 
    cl.apellidos, 
    p.total
FROM pago p
JOIN alquiler a ON p.id_alquiler = a.id_alquiler
JOIN cliente cl ON a.id_cliente = cl.id_cliente
WHERE p.fecha_pago >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
ORDER BY p.total DESC
LIMIT 1;

---------------------------------------------------------------------
-- 18. Lista las cinco categorías con más ingresos generados durante los últimos tres meses.
---------------------------------------------------------------------
SELECT 
    c.id_categoria, 
    c.nombre, 
    SUM(p.total) AS ingresos_totales
FROM pago p
JOIN alquiler a ON p.id_alquiler = a.id_alquiler
JOIN inventario i ON a.id_inventario = i.id_inventario
JOIN pelicula_categoria pc ON i.id_pelicula = pc.id_pelicula
JOIN categoria c ON pc.id_categoria = c.id_categoria
WHERE p.fecha_pago >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
GROUP BY c.id_categoria, c.nombre
ORDER BY ingresos_totales DESC
LIMIT 5;

---------------------------------------------------------------------
-- 19. Obtenga la cantidad de películas alquiladas por cada idioma en el último mes.
---------------------------------------------------------------------
SELECT 
    idm.nombre AS idioma, 
    COUNT(DISTINCT a.id_alquiler) AS total_alquileres
FROM alquiler a
JOIN inventario inv ON a.id_inventario = inv.id_inventario
JOIN pelicula p ON inv.id_pelicula = p.id_pelicula
JOIN idioma idm ON p.id_idioma = idm.id_idioma
WHERE a.fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY idm.id_idioma, idm.nombre;

---------------------------------------------------------------------
-- 20. Lista los clientes que no han realizado ningún alquiler en el último año.
---------------------------------------------------------------------
SELECT *
FROM cliente
WHERE id_cliente NOT IN (
    SELECT DISTINCT id_cliente
    FROM alquiler
    WHERE fecha_alquiler >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
);



