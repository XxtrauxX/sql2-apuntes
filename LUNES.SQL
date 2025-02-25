
-- CLASE LUNES, GROUP BY, PROCEDIMIENTO DE ALMACENAMIENTO, ESTRUCTURAS DE CONTROL

use coche;

create table if not exists coches(
	id int not null auto_increment,
	marca varchar(100) not null,
	modelo varchar(100) not null,
	kilometros int not null,
	primary key(id));



INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (1, 'Renault', 'Clio', 10);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (2, 'Renault', 'Megane', 23000);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (3, 'Seat', 'Ibiza', 9000);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (4, 'Seat', 'Leon', 20);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (5, 'Opel', 'Corsa', 999);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (6, 'Renault', 'Clio', 34000);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (7, 'Seat', 'Ibiza', 2000);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (8, 'Seat', 'Cordoba', 99999);
INSERT INTO coches (id, Marca, Modelo, kilometros) VALUES (9, 'Renault', 'Clio', 88888);
	
select marca, modelo
from coches 
group by marca, modelo;



-- cuantos coches hay de una una marca y que ordene por la cantidad de coches de dicha marca

SELECT marca, count(*) as cantidad
from coches c
group by marca 
order by cantidad desc, marca desc;


-- de cada marca se quiere saber cuantos kilometros han recorrido dichos coches  

SELECT marca, sum(kilometros) as kilometraje_minimo
FROM coches c
group by marca;





-- se desea saber cual es el kilometraje menor registrado por marcas


SELECT marca, min(kilometros) as kilometraje
FROM coches c
group by marca;



-- cual es el modelo que mas registra kilometraje por marca


SELECT marca, modelo, max(kilometros)
FROM coches c
group by marca, modelo;



delimiter $$

create procedure CalculadorTotal(in precio decimal(10,2),
								in cantidad int,
								out total decimal(10,2))

begin
	set total= precio * cantidad;

end$$

delimiter;

set @num=0;
call CalculadorTotal(10,8,@num);
select @num,
end



-- sintaxis






/*
 DELIMITER//
 
 CREATE PROCEDURE nombre_del_procedimiento(parametros)
 BEGIN
 
 	-- codigo sql
END //


DELIMITER ;


 
 
 */

use world;


procedimiento almacenado que consulte la poblacion de un pais



delimiter $$
$$
create procedure world.obtener_poblacion(in pais_nombre varchar(100))
begin
	select population as poblacion
	from country
	where name = pais_nombre;
end $$
delimiter ;


call obtener_poblacion('Colombia');



-- procedimiento almacenado que verifica si un pais tiene mas o menos de 50 millones de habitantes
delimiter //
create procedure verificar_poblacion(in nombre_pais varchar(50)
begin
	
	declare poblacion int;
	
	select c.population into poblacion
	from country c 
	where lower(c.name) = lower(nombre_pais);
	
	if poblacion > 5000000 THEN 
		select concat(nombre_pais, "tiene menos de 50 millones de habitantes") as mensaje;
	else
		select concat(nombre_pais "tiene mas de 50 millones de habitantes") as mensaje;
	end if;
	
	
	
	
end//


delimiter;


call verificar_poblacion("Colombia");





delimiter //



DROP PROCEDURE ID EXISTS world.verificar_poblacion;
create procedure verificar_poblacion(in nombre_pais varchar(50))
begin
    declare poblacion int;

    select c.population into poblacion
    from country c 
    where lower(c.name) = lower(nombre_pais);

    if poblacion < 50000000 then 
        select concat(nombre_pais, " tiene menos de 50 millones de habitantes") as mensaje;
    else
        select concat(nombre_pais, " tiene más de 50 millones de habitantes") as mensaje;
    end if;
end //
delimiter ;

call verificar_poblacion("Colombia");




-- procedimiento que devulve el pais con mayor poblacion de un continente


delimiter $$
create procedure obtener_pais_mayor_pob(in continente varchar(50), out pais_mayor varchar(50))

begin
	SELECT name into pais_mayor
	from country c
	where lower(continente) = lower(continente)
	order by population DESC 
	limit 1;


	if pais_mayor is null then
		set pais_mayor = "no se encontro pais en ese continente";
	end if;
end$$
delimiter;



call obtener_pais_mayor_pob("Asia",@pais_mayor_pob);
select @pais_mayor_pob as "pais";



-- manejo de errores en procedimiento alamcenados

-- se usa la instruccion DECLARE HANDLER
-- DECLARE HANDLER: permite capturar y manejar excepciones


-- capturar un error si en la base d datos no existe un pais
delimiter &&
create procedure obtener_info_pais(in nom_pais varchar(50))
begin
	declare continue handler for not found
		select concat("el pais", nom_pais "no fue encontrado en la bd");
	
	    select name, population, continent
	    from country c
	    where  name = nom_pais;
	   
end&&
delimiter ;



call obtener_info_pais("Atlantida");


	
	
