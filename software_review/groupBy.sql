USE tienda;

-- 1. Calcula el número total de productos que hay en la tabla productos.

SELECT count(*)
FROM  producto;


-- Calcula el número total de fabricantes que hay en la tabla fabricante.

SELECT count(*)
from fabricante;

-- Calcula el número de valores distintos de identificador de fabricante aparecen en la
-- tabla productos.

select count(id)
from fabricante ;


-- Calcula la media del precio de todos los productos.

select ROUND(AVG(precio), 2) as promedio
from producto;



SELECT f.nombre,
FROM fabricante f
JOIN 

-- Muestra el precio máximo, precio mínimo, precio medio y el número total de productos que
-- tiene el fabricante Crucial.

select count(p.id_fabricante) as fabricante_crucial, max(p.precio) as maximo_precio, min(p.precio) as minimo_precio
from producto p
where p.id_fabricante = 6;



select nombre, count(*)
from producto
group by nombre;




-- Muestra el número total de productos que tiene cada uno de los fabricantes. El listado
-- también debe incluir los fabricantes que no tienen ningún producto. El resultado mostrará
-- dos columnas, una con el nombre del fabricante y otra con el número de productos que tiene.
-- Ordene el resultado descendentemente por el número de productos.


SELECT f.nombre, count(p.id_fabricante) as numero_productos
from fabricante f
left join producto p on p.id_fabricante = f.id
GROUP by f.nombre;



-- Muestra el precio máximo, precio mínimo y precio medio de los productos de cada uno de los
-- fabricantes. El resultado mostrará el nombre del fabricante junto con los datos que se
-- solicitan.





SELECT f.nombre, max(p.precio) as precio_maximo, min(p.precio) as precio_minimo, avg(p.precio) as promedio
from fabricante f
left join producto p on p.id_fabricante = f.id
GROUP by f.nombre;



-- Muestra el precio máximo, precio mínimo, precio medio y el número total de productos de los
-- fabricantes que tienen un precio medio superior a 200€. No es necesario mostrar el nombre
-- del fabricante, con el identificador del fabricante es suficiente.



SELECT f.id, max(p.precio) as precio_maximo, min(p.precio) as precio_minimo, avg(p.precio) as promedio
from fabricante f
left join producto p on p.id_fabricante = f.id
GROUP by f.id
having avg(p.precio) >= 200;





-- Muestra el nombre de cada fabricante, junto con el precio máximo, precio mínimo, precio
-- medio y el número total de productos de los fabricantes que tienen un precio medio superior
-- a 200€. Es necesario mostrar el nombre del fabricante.


SELECT f.nombre, max(p.precio) as precio_maximo, min(p.precio) as precio_minimo, avg(p.precio) as promedio
from fabricante f
left join producto p on p.id_fabricante = f.id
GROUP by f.nombre;







