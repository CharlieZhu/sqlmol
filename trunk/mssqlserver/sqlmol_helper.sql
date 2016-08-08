/**********************************************************************
sqlmol_helper.sql - Helper function for fn_sqlmol_smi2tbl
 
Copyright (C) 2009 by Charlie Zhu (charlie@charliezhu.com)
 
This file is part of the SQLMOL project.
For more information, see <http://code.google.com/p/sqlmol>
 
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation version 3 of the License.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
***********************************************************************/
drop function fn_next_symbol
GO
/*
select * from dbo.fn_next_symbol('12')
 */
create function fn_next_symbol (
    @smi varchar(max)
) returns @r table 
    ( Code char(2), [Type] char(1), Aromaticity bit, Offset smallint default(0) )
as
BEGIN
    declare 
    @t   char(1),  -- type
    @a1  char(2),  -- atom
    @a2  char(2),  -- atom
    @b   char(1),  -- bond
    @a1i smallint,
    @a2i smallint,
    @bi  smallint,
    @f   smallint,
    @ar bit        -- symbol aromaticity

	select @a1i=1, @a2i=1, @b=1, @f=0

    set @a1 = left(@smi, 1) 
    set @a2 = left(@smi, 2)
    
    -- CYCLIC, LOOP
    if @a1 in ('1', '2', '3', '4', '5', '6', '7', '8', '9')
    BEGIN
        insert into @r select @a1, 'l', 0, 1
        RETURN
    END
    
    -- BRACKETS
    if @a1='['
    BEGIN
        set @f  = charindex(']', @smi)
		set @a1 = substring(@smi, 2, 1) 
		set @a2 = substring(@smi, 2, 2)
    END
    
    -- Atom / Bond / Branch
	set @t= NULL
	select     @t= [type], @ar=Aromaticity from sqlmol_symbol where code= @a2
	if @t is null
	BEGIN
		select @t= [type], @ar=Aromaticity from sqlmol_symbol where code= @a1
		set @a2= @a1
	END

    if @t is null
        -- RAISERROR(N'Can not found next symbol', 10, 1)
        RETURN

    if @f= 0
        set @f= LEN(@a2)
    
    insert into @r select @a2, @t, @ar, @f
    RETURN
END