-- Grupo conformado por Ivan Dario Villamizar Archila y Oscar Alejandro Diaz Ojeda

-- EJERCICIO #1

use universidad;


-- 1. Devuelve un listado con el primer apellido, segundo apellido y el nombre de
-- todos los alumnos. El listado deberá estar ordenado alfabéticamente de menor
-- a mayor por el primer apellido, segundo apellido y nombre.

show tables;





SELECT p.apellido1, p.apellido2, p.nombre
FROM persona p
LEFT JOIN alumno_se_matricula_asignatura al ON p.id = al.id_alumno
WHERE p.tipo = 'alumno' 
GROUP BY p.id, p.apellido1, p.apellido2, p.nombre
ORDER BY p.apellido1 ASC, p.apellido2 ASC, p.nombre ASC;


-- 2 Devuelve el listado de profesores que no han dado de alta su número de
-- teléfono en la base de datos y además su nif termina en K.

select concat(p.nombre," ",p.apellido1 ," ", p.apellido2) as "Nombre Profesor"
    from persona p  left join profesor pr on p.id=pr.id_departamento
    where p.telefono is null and p.nif LIKE "%K";





-- 3. Devuelve el listado de las asignaturas que se imparten en el primer
-- cuatrimestre, en el tercer curso del grado que tiene el identificador 7.

select * from asignatura;


SELECT a.nombre
FROM asignatura a
join grado g on g.id = a.id_grado
where a.cuatrimestre = '1' AND g.id = '7';



-- 4 Devuelve un listado con los datos de todas las alumnas que se han matriculado
-- alguna vez en el Grado en Ingeniería Informática (Plan 2015).

select concat(p.nombre," ",p.apellido1 ," ", p.apellido2) as "Nombre Profesor" 
    from persona p join alumno_se_matricula_asignatura asma on p.id = asma.id_alumno 
        join curso_escolar ce on asma.id_curso_escolar = ce.id 
        join asignatura a on a.id = asma.id_asignatura 
    WHERE p.sexo = "M" AND LOWER(a.nombre) = LOWER("Ingeniería Informática") AND ce.anyo_inicio = 2015 ;





-- 5. Devuelve un listado de los profesores junto con el nombre del departamento al
-- que están vinculados. El listado debe devolver cuatro columnas, primer
-- apellido, segundo apellido, nombre y nombre del departamento. El resultado
-- estará ordenado alfabéticamente de menor a mayor por los apellidos y el
-- nombre.



SELECT pp.apellido1, pp.apellido2, pp.nombre, d.nombre
FROM profesor p
join departamento d on p.id_departamento = d.id
join persona pp on pp.id = p.id_profesor;



-- 6.  Devuelve un listado con el nombre de las asignaturas, año de inicio y año de fin
-- del curso escolar del alumno con nif 26902806M.


SELECT  a.nombre as "Nombre Asignatura", ce.anyo_inicio as "Año de inicio" , ce.anyo_fin as "Año fin" 
    from persona p join alumno_se_matricula_asignatura asma on p.id = asma.id_alumno 
        join curso_escolar ce on asma.id_curso_escolar = ce.id 
        join asignatura a on a.id = asma.id_asignatura 
    where p.nif = "26902806M";



-- revision
-- 7 . Devuelve un listado con los nombres de todos los profesores y los
-- departamentos que tienen vinculados. El listado también debe mostrar aquellos
-- profesores que no tienen ningún departamento asociado. El listado debe
-- devolver cuatro columnas, nombre del departamento, primer apellido, segundo
-- apellido y nombre del profesor. El resultado estará ordenado alfabéticamente
-- de menor a mayor por el nombre del departamento, apellidos y el nombre.

SELECT d.nombre, pp.apellido1, pp.apellido2, pp.nombre
FROM departamento d
left join profesor p on d.id = p.id_departamento
left join persona pp on pp.id = p.id_profesor
order by d.nombre, pp.apellido1, pp.apellido2, pp.nombre ASC;


-- 8. Devuelve un listado con los profesores que no están asociados a un
-- departamento.

select concat(p.nombre," ",p.apellido1 ," ", p.apellido2) as "Nombre Profesor"
    from persona p
    where p.id not in( SELECT id_profesor from profesor);





-- 9. Devuelve un listado con los departamentos que no tienen profesores asociados.


SELECT d.nombre
FROM departamento d
LEFT JOIN profesor p on d.id = p.id_departamento
where p.id_departamento is null;


-- 10. Devuelve un listado con los profesores que no imparten ninguna asignatura.

    SELECT p.id_profesor, per.nombre, per.apellido1, per.apellido2
    FROM profesor p
    JOIN persona per ON p.id_profesor = per.id
    LEFT JOIN asignatura a ON p.id_profesor = a.id_profesor
    WHERE a.id_profesor IS NULL;

-- 11. Devuelve un listado con las asignaturas que no tienen un profesor asignado.

SELECT a.nombre
FROM asignatura a
left join profesor p on a.id_profesor = p.id_profesor
where p.id_profesor is null;

-- 12 Devuelve un listado con todos los departamentos que tienen alguna asignatura
-- que no se haya impartido en ningún curso escolar. El resultado debe mostrar el
-- nombre del departamento y el nombre de la asignatura que no se haya
-- impartido nunca.


        SELECT d.nombre AS departamento, a.nombre AS asignatura
        FROM departamento d
        JOIN profesor p ON d.id = p.id_departamento
        JOIN asignatura a ON p.id_profesor = a.id_profesor
        LEFT JOIN alumno_se_matricula_asignatura am ON a.id = am.id_asignatura
        WHERE am.id_asignatura IS NULL;

-- 13. Devuelve el número total de alumnas que hay.


SELECT DISTINCT p.nombre, p.sexo
FROM persona p
JOIN alumno_se_matricula_asignatura ad on p.id = ad.id_alumno
where p.sexo = 'M';



-- 14. Calcula cuántos alumnos nacieron en 1999.
    SELECT  COUNT(*) from persona WHERE YEAR(fecha_nacimiento) = 1999 and tipo = "alumno" ;


-- 15. Calcula cuántos profesores hay en cada departamento. El resultado sólo debe
-- mostrar dos columnas, una con el nombre del departamento y otra con el
-- número de profesores que hay en ese departamento. El resultado sólo debe
-- incluir los departamentos que tienen profesores asociados y deberá estar
-- ordenado de mayor a menor por el número de profesores.



SELECT d.nombre AS departamento, COUNT(p.id_profesor) AS numero_profesores
FROM profesor p
JOIN departamento d ON p.id_departamento = d.id
GROUP BY d.nombre
HAVING COUNT(p.id_profesor) > 0
ORDER BY numero_profesores DESC;



-- 16. Devuelve un listado con el nombre de todos los grados existentes en la base de
-- datos y el número de asignaturas que tiene cada uno. Tenga en cuenta que
-- pueden existir grados que no tienen asignaturas asociadas. Estos grados
-- también tienen que aparecer en el listado. El resultado deberá estar ordenado
-- de mayor a menor por el número de asignaturas.


    SELECT  g.nombre, count(a.id_grado)
    FROM grado g left join asignatura a on a.id_grado = g.id 
    group by g.nombre
    order by count(a.id_grado) DESC ;



-- 17. Devuelve un listado con el número de asignaturas que imparte cada profesor. El
-- listado debe tener en cuenta aquellos profesores que no imparten ninguna
-- asignatura. El resultado mostrará cinco columnas: id, nombre, primer apellido,
-- segundo apellido y número de asignaturas. El resultado estará ordenado de
-- mayor a menor por el número de asignaturas.






SELECT 
    p.id_profesor AS id, 
    pp.nombre, 
    pp.apellido1, 
    pp.apellido2, 
    COUNT(a.id) AS numero_asignaturas
FROM profesor p
JOIN persona pp ON pp.id = p.id_profesor
LEFT JOIN asignatura a ON p.id_profesor = a.id_profesor
GROUP BY p.id_profesor, pp.nombre, pp.apellido1, pp.apellido2
ORDER BY numero_asignaturas DESC;



-- 18. Devuelve un listado con los profesores que no están asociados a un
-- departamento.

        SELECT concat(p.nombre," ",p.apellido1 ," ", p.apellido2) as "Nombre Profesor" , p.id 
        from persona p  left join profesor p2 ON p.id = p2.id_profesor
                left join departamento d2 on d2.id = p2.id_departamento
        where p2.id_departamento is null;




-- 19. Devuelve un listado con los departamentos que no tienen profesores asociados.


SELECT d.nombre, p.id_profesor
FROM departamento d
left join profesor p on p.id_profesor = d.id
where p.id_profesor is null;



-- 20. Devuelve todos los datos del alumno más joven.

    SELECT *
    from persona p 
    where tipo = "alumno"
    order by p.fecha_nacimiento desc limit 1;


-- 21. Devuelve un listado con los profesores que tienen un departamento asociado y
-- que no imparten ninguna asignatura.


SELECT p.id_profesor, per.nombre, per.apellido1, per.apellido2, d.nombre AS departamento
FROM profesor p
JOIN persona per ON p.id_profesor = per.id 
JOIN departamento d ON p.id_departamento = d.id  
LEFT JOIN asignatura a ON p.id_profesor = a.id_profesor 
WHERE a.id IS NULL; 



-- 22.Devuelve un listado con las asignaturas que no tienen un profesor asignado.

    SELECT a.nombre 
    from profesor p right join asignatura a on p.id_profesor = a.id_profesor 
    where p.id_profesor is  null;


-- 23. Devuelve un listado con todos los departamentos que no han impartido
-- asignaturas en ningún curso escolar.


SELECT d.id, d.nombre 
FROM departamento d
LEFT JOIN profesor p ON d.id = p.id_departamento
LEFT JOIN asignatura a ON p.id_profesor = a.id_profesor
WHERE a.id IS NULL;


















